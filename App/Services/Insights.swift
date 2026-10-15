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

    var baseline: Double? { points.first?.value }
    var latest: Double? { points.last?.value }
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
    var activeDays28 = 0
    var weeklyStreak = 0
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
        if let b = words.first?.value, let l = words.last?.value, words.count >= 2 {
            r.wordRecall.reliablyImproved = Improvement.isReliable(baseline: b, latest: l, norms: Improvement.wordRecall)
        }
        if let b = span.first?.value, let l = span.last?.value, span.count >= 2 {
            r.digitSpan.reliablyImproved = Improvement.isReliable(baseline: b, latest: l, norms: Improvement.digitSpan)
        }

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
             "level": $0.level, "courseDay": $0.courseDay, "benchmark": $0.isBenchmark] as [String: Any]
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
