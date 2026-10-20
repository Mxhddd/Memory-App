import Foundation

/// Everything worth remembering, from every game, lives in one ledger and is scheduled by one
/// FSRS model. Games are just different ways to *encode* and *retrieve* items; the ledger
/// decides when each item comes back (just before it would fade).
public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case delivery      // The Journey: one thing carried to one palace stop
    case personName    // The Gathering: face → name
    case personFact    // The Gathering: name → what they do
    case peg           // Number Vault: 00–99 → peg word
    case number        // Number Vault: a meaningful number (phone, PIN, date)
    case dayNote       // Day Recall: what you noted on a given day
    case card          // Vault flashcards
}

public struct MemoryItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: ItemKind
    /// The cue shown at recall time ("Weekend errands · stop 3 · Sofa", "face:p:…", "47").
    public var cue: String
    /// The expected answer; `alternatives` are also accepted.
    public var answer: String
    public var alternatives: [String]
    /// Where it was learned ("journey:2026-10-20"), so a session can be reviewed as a set.
    public var source: String
    public var fsrs: FSRSCard
    public var reps: Int
    public var lapses: Int

    public init(id: String, kind: ItemKind, cue: String, answer: String, alternatives: [String] = [],
                source: String, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.cue = cue
        self.answer = answer
        self.alternatives = alternatives
        self.source = source
        fsrs = FSRSCard(due: createdAt)
        reps = 0
        lapses = 0
    }

    public var isNew: Bool { fsrs.lastReview == nil }

    /// Lenient check of a typed answer against the answer and its alternatives.
    public func accepts(_ given: String) -> Bool {
        ([answer] + alternatives).contains { AnswerMatch.matches(given, $0) }
    }
}

/// How an attempt went. The *first* retrieval of a session is what counts for scheduling:
/// a word you only got after being shown it was still forgotten.
public enum Attempt: String, Codable, Sendable {
    case recalled        // produced it unaided, first try
    case recognised      // picked it from choices (weaker evidence than recall)
    case missed          // wrong or blank on the first try
}

public enum Ledger {
    /// Ledger items skip FSRS's minute-scale learning steps: in-session relearning is handled by
    /// `RelearningQueue`, so the scheduler only decides the days between sessions.
    public static func scheduler(parameters: [Double] = FSRSScheduler.defaultParameters,
                                 desiredRetention: Double = 0.9, fuzz: Bool = true) -> FSRSScheduler {
        FSRSScheduler(parameters: parameters, desiredRetention: desiredRetention,
                      learningSteps: [], relearningSteps: [], enableFuzzing: fuzz)
    }

    public static func rating(for attempt: Attempt) -> Rating {
        switch attempt {
        case .recalled: return .good
        case .recognised: return .hard
        case .missed: return .again
        }
    }

    /// Grades one item from its first attempt this session.
    public static func record(_ item: inout MemoryItem, _ attempt: Attempt, at date: Date,
                              scheduler: FSRSScheduler, random: () -> Double = { Double.random(in: 0..<1) }) {
        item.fsrs = scheduler.review(item.fsrs, rating: rating(for: attempt), at: date, random: random)
        item.reps += 1
        if attempt == .missed { item.lapses += 1 }
    }

    /// Items due now, weakest first (lowest predicted recall), capped.
    public static func due(_ items: [MemoryItem], at date: Date, limit: Int,
                           scheduler: FSRSScheduler = Ledger.scheduler()) -> [MemoryItem] {
        let due = items.filter { !$0.isNew && $0.fsrs.due <= date }
        let ranked = due.sorted {
            let a = scheduler.retrievability(of: $0.fsrs, at: date), b = scheduler.retrievability(of: $1.fsrs, at: date)
            return a == b ? $0.id < $1.id : a < b
        }
        return interleave(Array(ranked.prefix(limit)))
    }

    /// Round-robin by kind, keeping each kind's order: mixing kinds is harder in the moment and
    /// better for memory than blocks of the same thing (interleaving).
    public static func interleave(_ items: [MemoryItem]) -> [MemoryItem] {
        var buckets: [ItemKind: [MemoryItem]] = [:]
        var order: [ItemKind] = []
        for item in items {
            if buckets[item.kind] == nil { order.append(item.kind) }
            buckets[item.kind, default: []].append(item)
        }
        var out: [MemoryItem] = []
        while out.count < items.count {
            for kind in order where !(buckets[kind]?.isEmpty ?? true) {
                out.append(buckets[kind]!.removeFirst())
            }
        }
        return out
    }
}

/// Successive relearning inside a session: every miss is shown, then asked again a little later
/// (after `gap` other items when possible) until it's right or has had `maxTries` attempts.
public struct RelearningQueue: Equatable, Sendable {
    public private(set) var upcoming: [String]
    public private(set) var tries: [String: Int] = [:]
    public private(set) var firstAttempt: [String: Attempt] = [:]
    public private(set) var resolved: Set<String> = []
    public let maxTries: Int
    public let gap: Int
    private let all: [String]

    public init(_ ids: [String], maxTries: Int = 3, gap: Int = 2) {
        upcoming = ids
        all = ids
        self.maxTries = maxTries
        self.gap = gap
    }

    public var current: String? { upcoming.first }
    public var isFinished: Bool { upcoming.isEmpty }
    /// True while the current item is being asked again after a miss.
    public var isRetry: Bool { current.map { (tries[$0] ?? 0) > 0 } ?? false }

    public mutating func answer(_ attempt: Attempt) {
        guard let id = upcoming.first else { return }
        upcoming.removeFirst()
        tries[id, default: 0] += 1
        if firstAttempt[id] == nil { firstAttempt[id] = attempt }
        if attempt != .missed {
            resolved.insert(id)
        } else if tries[id]! < maxTries {
            upcoming.insert(id, at: min(gap, upcoming.count))
        }
    }

    public var missedFirstTime: [String] { all.filter { firstAttempt[$0] == .missed } }
    public var relearned: [String] { missedFirstTime.filter { resolved.contains($0) } }
    public var unresolved: [String] { all.filter { firstAttempt[$0] != nil && !resolved.contains($0) } }
    public var firstTryCorrect: Int { all.filter { firstAttempt[$0] != nil && firstAttempt[$0] != .missed }.count }
}

/// A simple up/down staircase. `successesToHarder`-down/1-up converges near 71 % correct for 2
/// (Levitt 1971). Works additively (number of orders) or multiplicatively (display time).
public struct Staircase: Codable, Equatable, Sendable {
    public enum Scale: String, Codable, Sendable { case additive, multiplicative }

    public var value: Double
    public let lower: Double
    public let upper: Double
    public let scale: Scale
    /// Additive: amount added to make it harder (negative to make it smaller). Multiplicative: factor.
    public let harder: Double
    public let easier: Double
    public let successesToHarder: Int
    public private(set) var streak = 0
    public private(set) var reversals: [Double] = []
    private var lastMove = 0   // +1 harder, −1 easier

    public init(start: Double, lower: Double, upper: Double, scale: Scale, harder: Double, easier: Double, successesToHarder: Int = 2) {
        value = min(max(start, lower), upper)
        self.lower = lower
        self.upper = upper
        self.scale = scale
        self.harder = harder
        self.easier = easier
        self.successesToHarder = successesToHarder
    }

    public mutating func record(correct: Bool) {
        if correct {
            streak += 1
            guard streak >= successesToHarder else { return }
            streak = 0
            move(+1)
        } else {
            streak = 0
            move(-1)
        }
    }

    private mutating func move(_ direction: Int) {
        if lastMove != 0 && direction != lastMove { reversals.append(value) }
        lastMove = direction
        let step = direction > 0 ? harder : easier
        let next = scale == .additive ? value + step : value * step
        value = min(max(next, lower), upper)
    }

    /// Mean of the last six reversals once there are at least four.
    public var threshold: Double? {
        guard reversals.count >= 4 else { return nil }
        let last = reversals.suffix(6)
        return last.reduce(0, +) / Double(last.count)
    }
}
