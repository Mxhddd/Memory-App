import Foundation

// MARK: - Lookout (speed of processing)

/// Lookout: a glimpse, then two questions — what was in the middle, and where did the lantern
/// appear? The glimpse gets shorter as you improve. Modelled on the "useful field of view" speed
/// training of the ACTIVE trial (the one trained ability with long-term aging evidence).
/// Stage 1: centre + target. Stage 2: the target sits farther out. Stage 3: look-alike clutter.
public struct LookoutTrial: Equatable, Sendable {
    /// Which of the two centre figures was shown (0 or 1).
    public var center: Int
    /// Direction of the lantern, 0–7 clockwise from the top.
    public var direction: Int
    /// Ring of the lantern: 0 = near, 1 = middle, 2 = outer.
    public var ring: Int
    /// Clutter slots (ring * 8 + direction), never the lantern's slot.
    public var distractors: [Int]
    public var stage: Int
}

public enum Lookout {
    public static let directions = 8
    public static let rings = 3
    public static let startMs = 300.0
    public static let fastestMs = 34.0          // two frames at 60 Hz
    public static let stageUpBelowMs = 120.0
    public static let trialsPerRound = 24

    public static func staircase(startMs: Double = startMs) -> Staircase {
        Staircase(start: startMs, lower: fastestMs, upper: 500, scale: .multiplicative, harder: 0.85, easier: 1.2)
    }

    public static func trial(seed: String, index: Int, stage: Int) -> LookoutTrial {
        var rng = SeededRandom("\(seed)#look\(index)")
        let center = Int(rng.next() % 2)
        let direction = Int(rng.next() % UInt64(directions))
        let ring = stage == 1 ? Int(rng.next() % 2) + 1 : 2
        var distractors: [Int] = []
        if stage >= 3 {
            let target = ring * directions + direction
            distractors = Array(0..<(rings * directions)).filter { $0 != target && $0 >= directions }   // middle and outer rings
        }
        return LookoutTrial(center: center, direction: direction, ring: ring, distractors: distractors, stage: stage)
    }

    /// A trial counts only if both answers are right (guessing both: 1 in 16).
    public static func isCorrect(_ t: LookoutTrial, center: Int, direction: Int) -> Bool {
        t.center == center && t.direction == direction
    }

    /// Move up a stage once the glimpse is short and the threshold is stable.
    public static func nextStage(current: Int, threshold: Double?) -> Int {
        guard let threshold, current < 3, threshold < stageUpBelowMs else { return current }
        return current + 1
    }
}

// MARK: - The Kitchen (working memory)

/// The Kitchen: customers give their orders one by one; between orders you check a customer's
/// change. Then serve every order, in order. A complex-span task (Conway et al. 2005) in a form
/// that resembles real life: keeping things in mind while something else interrupts.
public struct KitchenRound: Equatable, Sendable {
    public struct Interruption: Equatable, Sendable {
        public var bill: Int
        public var paid: Int
        public var claimedChange: Int
        public var isCorrect: Bool { paid - bill == claimedChange }
        public var prompt: String { "Bill \(bill), paid \(paid). Change \(claimedChange)?" }
    }
    public var orders: [String]
    public var interruptions: [Interruption]   // one after each order
    public var menu: [String]                  // what you can serve from (orders + look-alikes)
}

public struct KitchenScore: Equatable, Sendable {
    public var inPlace: Int
    public var total: Int
    public var checksRight: Int
    public var checks: Int
    /// Change checks must stay ≥ 85 % right, or the orders were just rehearsed, not juggled.
    public var checksAccuracy: Double { checks == 0 ? 1 : Double(checksRight) / Double(checks) }
    public var perfect: Bool { inPlace == total && checksAccuracy >= 0.85 }
}

public enum Kitchen {
    public static let dishes = [
        "chai", "samosa", "biryani", "paratha", "lassi", "naan", "kebab", "halwa", "pakora", "kheer",
        "omelette", "soup", "salad", "pizza", "pasta", "burger", "toast", "pancakes", "coffee", "juice",
        "muffin", "noodles", "curry", "sandwich",
    ]
    public static let minOrders = 2.0
    public static let maxOrders = 9.0

    public static func staircase(start: Double = 3) -> Staircase {
        Staircase(start: start, lower: minOrders, upper: maxOrders, scale: .additive, harder: 1, easier: -1)
    }

    public static func round(size: Int, seed: String) -> KitchenRound {
        var rng = SeededRandom("\(seed)#kitchen")
        let shuffled = dishes.shuffled(using: &rng)
        let n = min(max(size, 1), dishes.count)
        let orders = Array(shuffled.prefix(n))
        let menuSize = max(9, ((n + 2) / 3) * 3 + 3)
        let menu = Array(shuffled.prefix(min(menuSize, dishes.count))).shuffled(using: &rng)
        let interruptions = (0..<n).map { _ -> KitchenRound.Interruption in
            let bill = Int(rng.next() % 90) + 10
            let paid = [50, 100, 200, 500].first { $0 > bill } ?? 500
            let truth = paid - bill
            let honest = rng.next() % 2 == 0
            let off = [5, 10, 1][Int(rng.next() % 3)] * (rng.next() % 2 == 0 ? 1 : -1)
            return .init(bill: bill, paid: paid, claimedChange: honest ? truth : max(0, truth + off))
        }
        return KitchenRound(orders: orders, interruptions: interruptions, menu: menu)
    }

    public static func score(_ round: KitchenRound, served: [String], checks: [Bool]) -> KitchenScore {
        let inPlace = zip(round.orders, served).filter { AnswerMatch.normalize($0) == AnswerMatch.normalize($1) }.count
        let right = zip(round.interruptions, checks).filter { $0.isCorrect == $1 }.count
        return KitchenScore(inPlace: inPlace, total: round.orders.count, checksRight: right, checks: min(checks.count, round.interruptions.count))
    }
}

// MARK: - Missions (prospective memory)

/// Missions: a session can begin with an intention — "When you see the red lantern, tap it" —
/// and the cue turns up later inside another game. Remembering to act at the right moment is
/// prospective memory, the kind behind most everyday slips; forming an if–then plan
/// ("implementation intention", Gollwitzer) is the best-supported way to strengthen it.
public struct Mission: Codable, Equatable, Sendable {
    public enum Cue: String, Codable, CaseIterable, Sendable {
        case redLantern, silverBell, blueMoth, goldStar
        public var label: String {
            switch self {
            case .redLantern: return "red lantern"
            case .silverBell: return "silver bell"
            case .blueMoth: return "blue moth"
            case .goldStar: return "gold star"
            }
        }
    }
    public var cue: Cue
    /// Seconds into the host game when the cue appears.
    public var appearsAfter: Int
    /// How long the cue stays before it counts as missed.
    public var window: Int
    public var intention: String { "When I see the \(cue.label), I'll tap it." }
}

public enum Missions {
    /// About three days in five carry a mission, so it never becomes a fixed habit.
    public static func mission(seed: String) -> Mission? {
        var rng = SeededRandom("\(seed)#mission")
        guard rng.unit() < 0.6 else { return nil }
        let cue = Mission.Cue.allCases[Int(rng.next() % UInt64(Mission.Cue.allCases.count))]
        return Mission(cue: cue, appearsAfter: 15 + Int(rng.next() % 31), window: 6)
    }

    public static func hitRate(_ outcomes: [Bool]) -> Double? {
        outcomes.isEmpty ? nil : Double(outcomes.filter { $0 }.count) / Double(outcomes.count)
    }
}

// MARK: - Day Recall (your own life)

/// Day Recall: in the evening, jot down a few things from today. Days later: "What did you note
/// last Tuesday?" Retrieving your own experiences is the memory people care most about, and
/// spaced retrieval keeps those days from blurring together.
public struct DayEntry: Codable, Equatable, Sendable {
    public var day: Int            // yyyymmdd
    public var notes: [String]
    public init(day: Int, notes: [String]) { self.day = day; self.notes = notes }
}

public enum DayRecall {
    /// Words that carry content (the ones worth checking for).
    static let stop: Set<String> = ["the", "and", "with", "for", "from", "that", "this", "then", "went", "had", "was", "were", "have", "about", "into", "some", "after", "before", "again", "very", "just", "our", "her", "his", "their", "them", "they", "she", "him"]

    public static func keywords(_ text: String) -> [String] {
        AnswerMatch.normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stop.contains($0) }
    }

    /// Same word, a typo of it, or another form of it ("rain" / "rained").
    static func sameWord(_ a: String, _ b: String) -> Bool {
        AnswerMatch.matches(a, b) || (a.count >= 4 && b.hasPrefix(a)) || (b.count >= 4 && a.hasPrefix(b))
    }

    /// A note counts as recalled when at least a third of its keywords (at least one) come back —
    /// the gist, not the exact wording.
    public static func recalled(note: String, in answer: String) -> Bool {
        let want = keywords(note)
        guard !want.isEmpty else { return false }
        let have = keywords(answer)
        let hits = want.filter { w in have.contains { sameWord($0, w) } }.count
        return hits >= 1 && hits * 3 >= want.count
    }

    public static func score(entry: DayEntry, answer: String) -> (recalled: Int, total: Int) {
        (entry.notes.filter { recalled(note: $0, in: answer) }.count, entry.notes.count)
    }
}
