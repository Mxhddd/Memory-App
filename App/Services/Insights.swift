import Foundation
import SwiftData
import MemoryCore

/// Turns raw sessions into the Den's gentle insights. Everything is relative to the person's
/// *own* baseline — there are no norms for these two users, so no population comparisons.
struct DayScore: Identifiable {
    var day: Int
    var score: Double
    var id: Int { day }
}

struct CurveSummary: Identifiable {
    var task: RealmTask
    var burst: Int
    var daily: [DayScore]
    var fit: LearningCurveFit?
    var auc: Double?
    var practiceGain: Double?
    var id: String { "\(task.rawValue)-\(burst)" }
}

struct TrendPoint: Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

struct InsightsReport {
    var curves: [CurveSummary] = []
    var previousCurves: [CurveSummary] = []
    var compositeTrend: [TrendPoint] = []
    var ewmaLowerLimit: Double = -0.9
    var showDoctorCard = false
    var activeDays28 = 0
    var weeklyStreak = 0
    var lapsesThisWeek = 0
    var moonBellHits = 0
    var moonBellTotal = 0
    var completedBursts = 0
}

@MainActor
enum Insights {
    /// Burst-average reliability assumed for change scores (ambulatory burst averages ~0.8–0.9).
    static let burstReliability = 0.8
    /// Weakly-informative prior for the expected retest gain on the composite (person-relative z units).
    static let priorPracticeGain = 0.1

    static func report() -> InsightsReport {
        let sessions = (try? Store.context.fetch(FetchDescriptor<TaskSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let checkIns = (try? Store.context.fetch(FetchDescriptor<CheckIn>())) ?? []
        var r = InsightsReport()

        // Learning curves for multi-day tasks, latest and previous burst.
        let measured = sessions.filter { $0.burstIndex >= 0 && !$0.isDelayedRecall }
        let bursts = Set(measured.map(\.burstIndex)).sorted()
        func curves(for burst: Int) -> [CurveSummary] {
            [RealmTask.faceName, .ancientRunes].compactMap { task in
                let s = measured.filter { $0.burstIndex == burst && $0.task == task }
                guard !s.isEmpty else { return nil }
                let byDay = Dictionary(grouping: s, by: \.burstDay)
                    .map { DayScore(day: $0.key, score: $0.value.map(\.score).reduce(0, +) / Double($0.value.count)) }
                    .sorted { $0.day < $1.day }
                let ys = byDay.map(\.score)
                return CurveSummary(task: task, burst: burst, daily: byDay, fit: LearningCurve.fit(ys),
                                    auc: LearningCurve.normalizedAUC(ys), practiceGain: LearningCurve.practiceGain(ys))
            }
        }
        if let last = bursts.last { r.curves = curves(for: last) }
        if bursts.count >= 2 { r.previousCurves = curves(for: bursts[bursts.count - 2]) }

        // Daily composite z (Garden Index) vs the baseline burst, EWMA-smoothed.
        let calendar = Calendar.current
        let baseline = sessions.filter { $0.burstIndex == 0 && !$0.isDelayedRecall }
        var baselineDomainDaily: [MemoryDomain: [Double]] = [:]
        for (domain, items) in Dictionary(grouping: baseline, by: { $0.task.domain }) {
            baselineDomainDaily[domain] = dailyMeans(items, calendar: calendar).map(\.1)
        }

        let afterBaseline = sessions.filter { $0.burstIndex != 0 && !$0.isDelayedRecall }
        let byDay = Dictionary(grouping: afterBaseline) { calendar.startOfDay(for: $0.date) }
        var chart = EWMAChart()
        for day in byDay.keys.sorted() {
            var z: [MemoryDomain: Double] = [:]
            for (domain, items) in Dictionary(grouping: byDay[day]!, by: { $0.task.domain }) {
                let x = items.map(\.score).reduce(0, +) / Double(items.count)
                if let base = baselineDomainDaily[domain], let value = personalZ(x, baseline: base) { z[domain] = value }
            }
            if let index = GardenIndex.index(z) {
                chart.add(max(-4, min(4, index)))
                r.compositeTrend.append(TrendPoint(date: day, value: chart.value))
            }
        }
        r.ewmaLowerLimit = chart.lowerLimit

        // Burst-to-burst practice-adjusted change on the composite.
        let planner = Store.profile()?.planner
        var burstComposite: [Int: Double] = [:]
        for b in bursts {
            let s = measured.filter { $0.burstIndex == b }
            var means: [MemoryDomain: Double] = [:]
            for (domain, items) in Dictionary(grouping: s, by: { $0.task.domain }) {
                means[domain] = items.map(\.score).reduce(0, +) / Double(items.count)
            }
            burstComposite[b] = GardenIndex.index(means)
        }
        let baselineDaily = dailyMeans(baseline, calendar: calendar).map(\.1)
        let sd = max(standardDeviation(baselineDaily), 0.05)
        var changes: [BurstChange] = []
        var personalGains: [Double] = []
        for (i, b) in bursts.enumerated() where i > 0 {
            guard let x1 = burstComposite[bursts[i - 1]], let x2 = burstComposite[b], let start = planner?.burstStart(b) else { continue }
            let expected = ReliableChange.shrunkExpectedGain(personal: personalGains, prior: priorPracticeGain * sd)
            let z = ReliableChange.practiceAdjusted(x1: x1, x2: x2, expectedGain: expected, sd: sd, reliability: burstReliability)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            let confounded = checkIns.contains { $0.date >= start && $0.date < end && $0.isConfounder }
            changes.append(BurstChange(startDate: start, changeZ: z, confounded: confounded))
            if i == 1 { personalGains.append(x2 - x1) } // first retest informs the person's own practice effect
        }
        r.completedBursts = bursts.count
        r.showDoctorCard = EscalationPolicy.shouldSuggestDoctorVisit(ewmaBelowLimit: chart.isBelowLimit, bursts: changes)

        // Engagement
        r.activeDays28 = Quest.activeDays(last: 28)
        r.weeklyStreak = Quest.weeklyStreak()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        r.lapsesThisWeek = (try? Store.context.fetchCount(FetchDescriptor<LapseLog>(predicate: #Predicate { $0.date >= weekAgo }))) ?? 0
        let bells = sessions.filter { $0.task == .moonBell }
        r.moonBellTotal = bells.count
        r.moonBellHits = bells.filter { $0.correct > 0 }.count
        return r
    }

    static func dailyMeans(_ sessions: [TaskSession], calendar: Calendar) -> [(Date, Double)] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value.map(\.score).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.0 < $1.0 }
    }

    static func standardDeviation(_ xs: [Double]) -> Double {
        guard xs.count >= 2 else { return 0 }
        let m = xs.reduce(0, +) / Double(xs.count)
        return (xs.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(xs.count - 1)).squareRoot()
    }
}

/// JSON export of everything on this phone (photos omitted to keep the file small).
@MainActor
enum Exporter {
    static func exportFile() -> URL? {
        let iso = ISO8601DateFormatter()
        func d(_ date: Date?) -> Any { date.map { iso.string(from: $0) } ?? NSNull() }
        func n<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() } // JSONSerialization rejects Optional
        let ctx = Store.context
        let profile = Store.profile()
        var root: [String: Any] = ["exportedAt": iso.string(from: Date()), "app": "Memory Garden"]
        if let p = profile {
            root["profile"] = ["name": p.displayName, "mascot": p.mascotName, "theme": p.themeRaw, "shinies": p.shinies,
                               "burstStart": d(p.burstStart), "phq9": n(p.phq9), "gad7": n(p.gad7),
                               "complaintProspective": p.complaintProspective, "complaintRetrospective": p.complaintRetrospective] as [String: Any]
        }
        root["sessions"] = ((try? ctx.fetch(FetchDescriptor<TaskSession>())) ?? []).map {
            ["date": d($0.date), "task": $0.taskRaw, "correct": $0.correct, "total": $0.total, "score": $0.score,
             "meanRTms": $0.meanRTms, "burst": $0.burstIndex, "burstDay": $0.burstDay, "delayed": $0.isDelayedRecall] as [String: Any]
        }
        root["cards"] = ((try? ctx.fetch(FetchDescriptor<MemoryCard>())) ?? []).map {
            ["kind": $0.kindRaw, "prompt": $0.prompt, "answer": $0.answer, "hint": $0.hint, "due": d($0.due),
             "stability": n($0.stability), "difficulty": n($0.difficulty), "reps": $0.reps, "lapses": $0.lapses] as [String: Any]
        }
        root["checkIns"] = ((try? ctx.fetch(FetchDescriptor<CheckIn>())) ?? []).map {
            ["date": d($0.date), "sleep": $0.sleep, "stress": $0.stress, "mood": $0.mood, "unwell": $0.unwell] as [String: Any]
        }
        root["lapses"] = ((try? ctx.fetch(FetchDescriptor<LapseLog>())) ?? []).map { ["date": d($0.date), "note": $0.note] as [String: Any] }
        root["intentions"] = ((try? ctx.fetch(FetchDescriptor<Intention>())) ?? []).map {
            ["text": $0.text, "when": $0.whenCue, "time": d($0.time), "daily": $0.repeatsDaily, "level": $0.levelRaw] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryGarden-export.json")
        try? data.write(to: url)
        return url
    }
}
