import Foundation
import SwiftData
import MemoryCore

/// Everything lives on this phone (SwiftData). Only a tiny completion-status row is ever synced.

@Model
final class Profile {
    var createdAt: Date = Date()
    var displayName: String = ""
    var mascotName: String = "Mochi"
    var themeRaw: String = ThemeID.midnightRaccoon.rawValue
    var onboardingComplete: Bool = false

    // Training settings
    var desiredRetention: Double = 0.88
    var errorlessNewCards: Bool = false
    var simpleRatings: Bool = false
    var reminderHour: Int = 19
    var reminderMinute: Int = 30
    var eveningNudge: Bool = true

    // Schedules
    var burstStart: Date = Date()
    var speedStart: Date = Date()

    // Engagement
    var shinies: Int = 0
    var streakFreezes: Int = 2

    // Self-report (onboarding & weekly)
    var complaintProspective: Double = 0
    var complaintRetrospective: Double = 0
    var phq9: Int?
    var gad7: Int?
    var hearingConcern: Bool = false

    // Circle
    var whatsappNumber: String = ""   // digits incl. country code, used for supporters' "nudge" button
    var timezoneID: String = TimeZone.current.identifier

    init() {}

    var theme: ThemeID {
        get { ThemeID(rawValue: themeRaw) ?? .midnightRaccoon }
        set { themeRaw = newValue.rawValue }
    }

    var planner: BurstPlanner { BurstPlanner(start: burstStart) }
}

/// One completed task (a game) — the raw material for learning curves and trends.
@Model
final class TaskSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var taskRaw: String = ""
    var correct: Int = 0
    var total: Int = 0
    var meanRTms: Double = 0
    var burstIndex: Int = -1     // -1 = training day
    var burstDay: Int = 0
    var seed: String = ""
    var isDelayedRecall: Bool = false
    var score: Double = 0        // task-specific (accuracy, span, items/min…) normalised to roughly 0…1

    init(task: RealmTask, correct: Int, total: Int, meanRTms: Double, score: Double, seed: String,
         burst: (burst: Int, day: Int)?, delayed: Bool = false, date: Date = Date()) {
        id = UUID()
        self.date = date
        taskRaw = task.rawValue
        self.correct = correct
        self.total = total
        self.meanRTms = meanRTms
        self.score = score
        self.seed = seed
        burstIndex = burst?.burst ?? -1
        burstDay = burst?.day ?? 0
        isDelayedRecall = delayed
    }

    var task: RealmTask { RealmTask(rawValue: taskRaw) ?? .faceName }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

/// A personal flashcard (names & faces, where things are, routines). Scheduled with FSRS-6.
@Model
final class MemoryCard {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var kindRaw: String = CardKind.person.rawValue
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
    var needsErrorless: Bool = true   // new cards start errorless when the profile wants it
    var reps: Int = 0
    var lapses: Int = 0

    init(kind: CardKind, prompt: String, answer: String, hint: String = "", photo: Data? = nil) {
        id = UUID()
        createdAt = Date()
        kindRaw = kind.rawValue
        self.prompt = prompt
        self.answer = answer
        self.hint = hint
        self.photo = photo
        due = Date()
    }

    var kind: CardKind { CardKind(rawValue: kindRaw) ?? .fact }
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

enum CardKind: String, CaseIterable, Identifiable, Codable {
    case person, place, routine, fact
    var id: String { rawValue }

    var label: String {
        switch self {
        case .person: return "Person"
        case .place: return "Where it lives"
        case .routine: return "Routine"
        case .fact: return "Fact"
        }
    }

    var icon: String {
        switch self {
        case .person: return "person.crop.circle"
        case .place: return "key.fill"
        case .routine: return "clock.arrow.circlepath"
        case .fact: return "lightbulb"
        }
    }

    var promptPlaceholder: String {
        switch self {
        case .person: return "Who is this? (e.g. neighbour with the yellow scarf)"
        case .place: return "Where do I keep… (e.g. the spare keys)"
        case .routine: return "What do I do when… (e.g. I leave the house)"
        case .fact: return "Question"
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

/// A prospective-memory reminder the person sets for themselves ("call Aunty at 3 pm").
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

/// Daily 3-tap check-in: covariates for scoring (never a diagnosis).
@Model
final class CheckIn {
    var date: Date = Date()
    var sleep: Int = 2   // 1 poor, 2 ok, 3 great
    var stress: Int = 2  // 1 calm, 2 some, 3 high
    var mood: Int = 2    // 1 low, 2 ok, 3 good
    var unwell: Bool = false

    init(sleep: Int, stress: Int, mood: Int, unwell: Bool, date: Date = Date()) {
        self.sleep = sleep
        self.stress = stress
        self.mood = mood
        self.unwell = unwell
        self.date = date
    }

    /// Flags that make a dip "explained" (blocks the doctor card).
    var isConfounder: Bool { sleep == 1 || mood == 1 || unwell || stress == 3 }
}

/// Everyday slips logged from the widget or app ("I forgot something").
@Model
final class LapseLog {
    var date: Date = Date()
    var note: String = ""
    init(date: Date = Date(), note: String = "") {
        self.date = date
        self.note = note
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

/// One row per calendar day: did the quest happen, how many prompts were sent.
@Model
final class DayRecord {
    var day: Date = Date()
    var questDone: Bool = false
    var deckDone: Bool = false
    var stepsDone: Int = 0
    var stepsTotal: Int = 0
    var completedAt: Date?

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
    }
}

/// "Before anything else, real life": reversible-cause checks to discuss with a doctor.
@Model
final class ChecklistItem {
    var order: Int = 0
    var title: String = ""
    var done: Bool = false
    init(order: Int, title: String) {
        self.order = order
        self.title = title
    }

    static let defaults = [
        "Thyroid check (TSH)", "Vitamin B12", "Iron / ferritin", "Vitamin D",
        "Sleep — snoring or pauses in breathing?", "Mood & stress", "Hearing check",
        "Review current medicines", "Hormonal changes (e.g. perimenopause), if relevant",
    ]
}
