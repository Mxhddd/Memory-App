import Foundation
import SwiftData
import MemoryCore

/// Progress numbers for the Progress tab: personal bests, benchmark trends with a
/// "reliably improved" flag, and level histories. Everything is relative to the person's own start.
struct TrendPoint: Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

struct BenchmarkTrend {
    var title: String
    var unit: String
    var points: [TrendPoint]
    var reliablyImproved: Bool
    /// Personal noise and practice effect, once the three baseline sessions exist.
    var personal: Improvement.Personal? = nil

    var baseline: Double? { personal?.baseline ?? points.first?.value }
    var latest: Double? { points.last?.value }
    var unitPlural: String { title == "Word recall" ? "words" : "digits" }
    var unitSingular: String { title == "Word recall" ? "word" : "digit" }
    var baselineLeft: Int { max(0, BenchmarkPlanner.baselineSessions - points.count) }
    /// The band of scores that are just normal day-to-day variation around the baseline.
    var band: ClosedRange<Double>? {
        guard let p = personal else { return nil }
        let half = p.threshold - p.expectedGain
        return max(0, p.baseline + p.expectedGain - half)...(p.baseline + p.threshold)
    }
}

struct ChampionResult: Identifiable {
    var date: Date
    var immediate: Int
    var nextDay: Int?
    var id: Date { date }
}

struct RetentionPoint: Identifiable {
    var offset: Int
    var mean: Double
    var count: Int
    var id: Int { offset }
}

struct InsightsReport {
    var wordRecall = BenchmarkTrend(title: "Word recall", unit: "of 30", points: [], reliablyImproved: false)
    var digitSpan = BenchmarkTrend(title: "Digit span", unit: "digits", points: [], reliablyImproved: false)
    var nBackLevels: [TrendPoint] = []
    var sprintWords: [TrendPoint] = []
    var bestWordSprint = 0
    var bestDigitSprint = 0
    var bestNBack = 0
    var bestRetention: Double?
    var champion: [ChampionResult] = []
    var whatSticks: [RetentionPoint] = []
    var activeDays28 = 0
    var weeklyStreak = 0
    /// Guesses made before recall vs what happened.
    var calibration: [CalibrationPoint] = []
    var calibrationSummary: Calibration.Summary?
    /// Seconds of study per word in course sprints, and today's budget from the speed ladder.
    var wordPace: [TrendPoint] = []
    var wordPaceBudget = EncodingPace.start(.wordSprint)
    /// The Vault: what you really recalled vs the forecast, and the suggested target.
    var vaultRetention: FSRSPersonal.TrueRetention?
    var personalFSRS = false
    var retentionAdvice: FSRSPersonal.RetentionAdvice?
}

struct CalibrationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let predicted: Double
    let actual: Double
}

@MainActor
enum Insights {
    static func report() -> InsightsReport {
        let sessions = (try? Store.context.fetch(FetchDescriptor<TaskSession>(sortBy: [SortDescriptor(\.date)]))) ?? []
        var r = InsightsReport()

        func points(_ task: RealmTask) -> [TrendPoint] {
            sessions.filter { $0.task == task }.map { TrendPoint(date: $0.date, value: Double($0.level)) }
        }
        let words = points(.wordRecall)
        let span = points(.digitSpan)
        r.wordRecall.points = words
        r.digitSpan.points = span
        // Judged against the personal baseline (first three sessions) once it exists.
        func judge(_ trend: inout BenchmarkTrend, norms: Improvement.Norms) {
            let pts = trend.points
            trend.personal = Improvement.personal(baselines: pts.prefix(BenchmarkPlanner.baselineSessions).map(\.value), prior: norms)
            if let p = trend.personal {
                trend.reliablyImproved = pts.count > BenchmarkPlanner.baselineSessions && Improvement.isReliable(latest: pts.last!.value, personal: p)
            } else if let b = pts.first?.value, let l = pts.last?.value, pts.count >= 2 {
                trend.reliablyImproved = Improvement.isReliable(baseline: b, latest: l, norms: norms)
            }
        }
        judge(&r.wordRecall, norms: Improvement.wordRecall)
        judge(&r.digitSpan, norms: Improvement.digitSpan)

        let delayed = sessions.filter { $0.task == .championDelayed }
        r.champion = sessions.filter { $0.task == .championTest }.map { test in
            let next = delayed.first { $0.seed == test.seed && $0.date > test.date
                && Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: test.date), to: Calendar.current.startOfDay(for: $0.date)).day == 1 }
            return ChampionResult(date: test.date, immediate: test.correct, nextDay: next?.correct)
        }
        // What sticks: share of a sprint list recalled straight away, after a night, and 3/7/21 days on.
        let retention: [(offset: Int, score: Double)] =
            sessions.filter { $0.task == .wordSprint }.map { (0, $0.score) }
            + sessions.filter { $0.task == .sprintRetention }.map { (1, $0.score) }
            + sessions.filter { $0.task == .listReview }.map { ($0.reviewOffset, $0.score) }
        r.whatSticks = ListReview.curve(retention).map { RetentionPoint(offset: $0.offset, mean: $0.mean, count: $0.count) }

        r.nBackLevels = points(.dualNBack)
        r.bestNBack = Int(r.nBackLevels.map(\.value).max() ?? 0)
        // Best sprint = most items recalled in the right place.
        let sprints = sessions.filter { $0.task == .wordSprint }
        r.sprintWords = sprints.map { TrendPoint(date: $0.date, value: Double($0.correct)) }
        r.bestWordSprint = sprints.map(\.correct).max() ?? 0
        r.bestDigitSprint = sessions.filter { $0.task == .numberSprint }.map(\.correct).max() ?? 0
        r.bestRetention = sessions.filter { $0.task == .sprintRetention }.map(\.score).max()

        r.activeDays28 = Quest.activeDays(last: 28)
        r.weeklyStreak = Quest.weeklyStreak()

        let guessed = sessions.filter { $0.prediction != nil && $0.total > 0 }
        r.calibration = guessed.map {
            let p = Calibration.Point(predicted: $0.prediction ?? 0, actual: $0.correct, total: $0.total)
            return CalibrationPoint(date: $0.date, predicted: p.predicted, actual: p.actual)
        }
        r.calibrationSummary = Calibration.summary(guessed.map { Calibration.Point(predicted: $0.prediction ?? 0, actual: $0.correct, total: $0.total) })

        let course = sprints.filter { !$0.isFreePlay }
        r.wordPace = course.compactMap { s in s.secondsPerItem.map { TrendPoint(date: s.date, value: $0) } }
        r.wordPaceBudget = EncodingPace.pace(kind: .wordSprint, accuracies: course.map(\.score))

        let events = VaultGrading.events(in: Store.context)
        r.vaultRetention = FSRSPersonal.trueRetention(events)
        let fitted = Store.profile()?.fsrsParameters
        r.personalFSRS = fitted?.count == 21
        if events.count >= FSRSPersonal.minimumReviews {
            r.retentionAdvice = FSRSPersonal.adviseRetention(parameters: r.personalFSRS ? fitted! : FSRSScheduler.defaultParameters)
        }
        return r
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
        var root: [String: Any] = ["exportedAt": iso.string(from: Date()), "app": "Memory Garden"]
        if let p = Store.profile() {
            root["profile"] = ["name": p.displayName, "mascot": p.mascotName, "theme": p.themeRaw, "shinies": p.shinies,
                               "courseDay": p.courseDay, "wordLevel": p.wordLevel, "digitLevel": p.digitLevel,
                               "nBackLevel": p.nBackLevel, "benchmarks": p.benchmarkCount] as [String: Any]
        }
        root["sessions"] = ((try? ctx.fetch(FetchDescriptor<TaskSession>())) ?? []).map {
            ["date": d($0.date), "task": $0.taskRaw, "correct": $0.correct, "total": $0.total, "score": $0.score,
             "level": $0.level, "courseDay": $0.courseDay, "benchmark": $0.isBenchmark, "reviewOffset": $0.reviewOffset] as [String: Any]
        }
        root["cards"] = ((try? ctx.fetch(FetchDescriptor<MemoryCard>())) ?? []).map {
            ["deck": $0.deck, "prompt": $0.prompt, "answer": $0.answer, "hint": $0.hint, "due": d($0.due),
             "stability": n($0.stability), "difficulty": n($0.difficulty), "reps": $0.reps, "lapses": $0.lapses] as [String: Any]
        }
        root["palaces"] = ((try? ctx.fetch(FetchDescriptor<Palace>())) ?? []).map { ["name": $0.name, "stops": $0.stops] as [String: Any] }
        root["reminders"] = ((try? ctx.fetch(FetchDescriptor<Intention>())) ?? []).map {
            ["text": $0.text, "when": $0.whenCue, "time": d($0.time), "daily": $0.repeatsDaily, "level": $0.levelRaw] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryGarden-export.json")
        try? data.write(to: url)
        return url
    }
}
