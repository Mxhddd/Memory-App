import Foundation
import SwiftData
import MemoryCore

/// Everything lives on this phone (SwiftData). Only a tiny "practised today" row is ever synced.

@Model
final class Profile {
    var createdAt: Date = Date()
    var displayName: String = ""
    var mascotName: String = "Mochi"
    var themeRaw: String = ThemeID.midnightRaccoon.rawValue
    var onboardingComplete: Bool = false

    // Session
    var dailyMinutes: Int = 15
    var reminderHour: Int = 19
    var reminderMinute: Int = 30
    var eveningNudge: Bool = true

    // Memory Palace course (advances only on days you train — never skips ahead)
    var courseDay: Int = 1
    var lastCourseAdvance: Date?
    var lessonsRead: [String] = []
    var wordLevel: Int = 10
    var digitLevel: Int = 6

    // Working-memory gym
    var nBackLevel: Int = 2
    /// Starting length for Sequences next time (adaptive span carries over between sessions).
    var sequenceSpan: Int = 4
    var showNBackLetters: Bool = false

    // Benchmarks
    var benchmarkStart: Date = Date()
    var lastBenchmark: Date?
    var benchmarkCount: Int = 0

    // Vault
    var desiredRetention: Double = 0.9
    var typedAnswers: Bool = true

    // Rewards
    var shinies: Int = 0

    // Circle
    var whatsappNumber: String = ""
    var timezoneID: String = TimeZone.current.identifier

    init() {}

    var theme: ThemeID {
        get { ThemeID(rawValue: themeRaw) ?? .midnightRaccoon }
        set { themeRaw = newValue.rawValue }
    }

    var benchmarks: BenchmarkPlanner { BenchmarkPlanner(start: benchmarkStart) }
}

/// One finished drill or benchmark — the raw material for progress charts.
@Model
final class TaskSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var taskRaw: String = ""
    var correct: Int = 0
    var total: Int = 0
    var meanRTms: Double = 0
    var score: Double = 0        // task-specific, roughly 0…1
    var level: Int = 0           // sprint size, n-back level, span…
    var seed: String = ""
    var courseDay: Int = 0
    var isBenchmark: Bool = false

    init(task: RealmTask, correct: Int, total: Int, meanRTms: Double, score: Double, level: Int,
         seed: String, courseDay: Int, isBenchmark: Bool = false, date: Date = Date()) {
        id = UUID()
        self.date = date
        taskRaw = task.rawValue
        self.correct = correct
        self.total = total
        self.meanRTms = meanRTms
        self.score = score
        self.level = level
        self.seed = seed
        self.courseDay = courseDay
        self.isBenchmark = isBenchmark
    }

    var task: RealmTask { RealmTask(rawValue: taskRaw) ?? .faceName }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

/// A memory palace: a familiar route with ordered stops.
@Model
final class Palace {
    var id: UUID = UUID()
    var name: String = ""
    var stops: [String] = []
    var createdAt: Date = Date()
    var lastUsed: Date?

    init(name: String, stops: [String] = []) {
        id = UUID()
        self.name = name
        self.stops = stops
        createdAt = Date()
    }
}

/// A Vault card: anything worth knowing, scheduled with FSRS-6.
@Model
final class MemoryCard {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var deck: String = "General"
    var prompt: String = ""
    var answer: String = ""
    var hint: String = ""
    @Attribute(.externalStorage) var photo: Data?

    // FSRS state
    var stateRaw: Int = CardState.learning.rawValue
    var step: Int? = 0
    var stability: Double?
    var difficulty: Double?
    var due: Date = Date()
    var lastReview: Date?
    var reps: Int = 0
    var lapses: Int = 0

    init(deck: String, prompt: String, answer: String, hint: String = "", photo: Data? = nil) {
        id = UUID()
        createdAt = Date()
        self.deck = deck
        self.prompt = prompt
        self.answer = answer
        self.hint = hint
        self.photo = photo
        due = Date()
    }

    var isNew: Bool { lastReview == nil }

    var fsrs: FSRSCard {
        get {
            FSRSCard(state: CardState(rawValue: stateRaw) ?? .learning, step: step, stability: stability,
                     difficulty: difficulty, due: due, lastReview: lastReview)
        }
        set {
            stateRaw = newValue.state.rawValue
            step = newValue.step
            stability = newValue.stability
            difficulty = newValue.difficulty
            due = newValue.due
            lastReview = newValue.lastReview
        }
    }
}

@Model
final class ReviewLogEntry {
    var cardID: UUID = UUID()
    var date: Date = Date()
    var rating: Int = 3
    var retrievability: Double = 0

    init(cardID: UUID, rating: Rating, retrievability: Double, date: Date = Date()) {
        self.cardID = cardID
        self.rating = rating.rawValue
        self.retrievability = retrievability
        self.date = date
    }
}

/// A reminder the person sets for themselves ("call Aunty at 3 pm").
@Model
final class Intention {
    var id: UUID = UUID()
    var text: String = ""
    var whenCue: String = ""          // optional implementation intention: "When I …"
    var time: Date = Date()
    var repeatsDaily: Bool = false
    var levelRaw: String = ReminderLevel.nag.rawValue
    var active: Bool = true
    var lastDone: Date?
    var createdAt: Date = Date()

    init(text: String, whenCue: String = "", time: Date, repeatsDaily: Bool, level: ReminderLevel) {
        id = UUID()
        self.text = text
        self.whenCue = whenCue
        self.time = time
        self.repeatsDaily = repeatsDaily
        levelRaw = level.rawValue
        createdAt = Date()
    }

    var level: ReminderLevel {
        get { ReminderLevel(rawValue: levelRaw) ?? .nag }
        set { levelRaw = newValue.rawValue }
    }

    func isDone(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let lastDone else { return false }
        return calendar.isDate(lastDone, inSameDayAs: day)
    }
}

enum ReminderLevel: String, CaseIterable, Identifiable, Codable {
    case gentle, nag, alarm
    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .nag: return "Keep nudging"
        case .alarm: return "Alarm"
        }
    }

    var explanation: String {
        switch self {
        case .gentle: return "One notification."
        case .nag: return "Notification, then again after 5 and 15 minutes until you tap Done."
        case .alarm: return "Rings like an alarm, even on silent (iOS 26+)."
        }
    }
}

/// Someone who gets completion-only alerts through the free ntfy app.
@Model
final class Supporter {
    var id: UUID = UUID()
    var label: String = ""
    var topic: String = ""
    var shareWeeklyCount: Bool = true
    var notifyOnDone: Bool = true
    var missedHour: Int = 20
    var missedMinute: Int = 30
    var createdAt: Date = Date()

    init(label: String) {
        id = UUID()
        self.label = label
        topic = Supporter.newTopic()
        createdAt = Date()
    }

    /// 128-bit random, unguessable topic name (ntfy topics are public URLs).
    static func newTopic() -> String {
        let alphabet = Array("abcdefghijkmnopqrstuvwxyz23456789")
        var rng = SystemRandomNumberGenerator()
        let suffix = String((0..<26).map { _ in alphabet.randomElement(using: &rng)! })
        return "mg-\(suffix)"
    }

    var subscribeURL: URL { URL(string: "https://ntfy.sh/\(topic)")! }
}

/// One row per calendar day.
@Model
final class DayRecord {
    var day: Date = Date()
    var questDone: Bool = false
    var vaultDone: Bool = false
    var stepsDone: Int = 0
    var stepsTotal: Int = 0
    var completedAt: Date?
    /// Course day today's plan was built from. Pinned at the first activity so that advancing the
    /// course mid-day doesn't pull tomorrow's lesson and drills into today's session.
    var planCourseDay: Int?

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
    }
}
