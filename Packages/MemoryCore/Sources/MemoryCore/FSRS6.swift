import Foundation

/// FSRS-6 spaced-repetition scheduler.
///
/// A line-by-line port of the reference implementation `py-fsrs` (open-spaced-repetition, v6),
/// so the two can be cross-checked with the same review history (see `FSRS6Tests`).
///
///   R(t,S) = (1 + factor·t/S)^(−w20),   factor = 0.9^(−1/w20) − 1   ⇒ R(S,S) = 0.9
///   I(r,S) = (S/factor)·(r^(−1/w20) − 1)

public enum Rating: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard = 2, good = 3, easy = 4
}

public enum CardState: Int, Codable, Sendable {
    case learning = 1, review = 2, relearning = 3
}

public struct FSRSCard: Codable, Equatable, Sendable {
    public var state: CardState
    public var step: Int?
    public var stability: Double?
    public var difficulty: Double?
    public var due: Date
    public var lastReview: Date?

    public init(
        state: CardState = .learning,
        step: Int? = nil,
        stability: Double? = nil,
        difficulty: Double? = nil,
        due: Date = Date(),
        lastReview: Date? = nil
    ) {
        self.state = state
        self.step = (state == .learning && step == nil) ? 0 : step
        self.stability = stability
        self.difficulty = difficulty
        self.due = due
        self.lastReview = lastReview
    }
}

public struct FSRSScheduler: Sendable {
    public static let defaultDecay = 0.1542
    public static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796,
        1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, defaultDecay,
    ]

    static let stabilityMin = 0.001
    static let minDifficulty = 1.0
    static let maxDifficulty = 10.0
    static let day: TimeInterval = 86_400

    public let parameters: [Double]
    public var desiredRetention: Double
    public var learningSteps: [TimeInterval]
    public var relearningSteps: [TimeInterval]
    public var maximumInterval: Int
    public var enableFuzzing: Bool

    private let decay: Double
    private let factor: Double

    public init(
        parameters: [Double] = FSRSScheduler.defaultParameters,
        desiredRetention: Double = 0.9,
        learningSteps: [TimeInterval] = [60, 600],
        relearningSteps: [TimeInterval] = [600],
        maximumInterval: Int = 36_500,
        enableFuzzing: Bool = true
    ) {
        precondition(parameters.count == 21, "FSRS-6 expects 21 parameters")
        self.parameters = parameters
        self.desiredRetention = desiredRetention
        self.learningSteps = learningSteps
        self.relearningSteps = relearningSteps
        self.maximumInterval = maximumInterval
        self.enableFuzzing = enableFuzzing
        self.decay = -parameters[20]
        self.factor = pow(0.9, 1 / decay) - 1
    }

    // MARK: Public API

    /// Probability of recall at `date` (0 for never-reviewed cards).
    public func retrievability(of card: FSRSCard, at date: Date = Date()) -> Double {
        guard let last = card.lastReview, let s = card.stability else { return 0 }
        let elapsed = max(0, Self.wholeDays(from: last, to: date))
        return retrievability(elapsedDays: Double(elapsed), stability: s)
    }

    public func retrievability(elapsedDays t: Double, stability s: Double) -> Double {
        pow(1 + factor * t / s, decay)
    }

    /// Returns the updated card. `random` supplies uniform [0,1) numbers for interval fuzz.
    public func review(
        _ input: FSRSCard,
        rating: Rating,
        at now: Date = Date(),
        random: () -> Double = { Double.random(in: 0..<1) }
    ) -> FSRSCard {
        var card = input
        let daysSince = card.lastReview.map { Self.wholeDays(from: $0, to: now) }
        let next: TimeInterval

        switch card.state {
        case .learning, .relearning:
            let steps = card.state == .learning ? learningSteps : relearningSteps
            let step = card.step ?? 0

            if card.state == .learning, card.stability == nil || card.difficulty == nil {
                card.stability = initialStability(rating)
                card.difficulty = initialDifficulty(rating, clamp: true)
            } else if let d = daysSince, d < 1 {
                card.stability = shortTermStability(card.stability!, rating)
                card.difficulty = nextDifficulty(card.difficulty!, rating)
            } else {
                card.stability = nextStability(
                    difficulty: card.difficulty!, stability: card.stability!,
                    retrievability: retrievability(of: card, at: now), rating: rating)
                card.difficulty = nextDifficulty(card.difficulty!, rating)
            }

            if steps.isEmpty || (step >= steps.count && rating != .again) {
                card.state = .review
                card.step = nil
                next = days(nextInterval(card.stability!))
            } else {
                switch rating {
                case .again:
                    card.step = 0
                    next = steps[0]
                case .hard:
                    if step == 0 && steps.count == 1 {
                        next = steps[0] * 1.5
                    } else if step == 0 && steps.count >= 2 {
                        next = (steps[0] + steps[1]) / 2
                    } else {
                        next = steps[step]
                    }
                case .good:
                    if step + 1 == steps.count {
                        card.state = .review
                        card.step = nil
                        next = days(nextInterval(card.stability!))
                    } else {
                        card.step = step + 1
                        next = steps[step + 1]
                    }
                case .easy:
                    card.state = .review
                    card.step = nil
                    next = days(nextInterval(card.stability!))
                }
            }

        case .review:
            if let d = daysSince, d < 1 {
                card.stability = shortTermStability(card.stability!, rating)
            } else {
                card.stability = nextStability(
                    difficulty: card.difficulty!, stability: card.stability!,
                    retrievability: retrievability(of: card, at: now), rating: rating)
            }
            card.difficulty = nextDifficulty(card.difficulty!, rating)

            if rating == .again && !relearningSteps.isEmpty {
                card.state = .relearning
                card.step = 0
                next = relearningSteps[0]
            } else {
                next = days(nextInterval(card.stability!))
            }
        }

        var interval = next
        if enableFuzzing && card.state == .review {
            interval = fuzzed(interval, random: random)
        }
        card.due = now.addingTimeInterval(interval)
        card.lastReview = now
        return card
    }

    /// Interval in whole days for a given stability at the scheduler's desired retention.
    public func nextInterval(_ stability: Double) -> Int {
        let raw = (stability / factor) * (pow(desiredRetention, 1 / decay) - 1)
        let rounded = Int(raw.rounded(.toNearestOrEven)) // Python's round() is banker's rounding
        return min(max(rounded, 1), maximumInterval)
    }

    // MARK: Model internals

    func initialStability(_ r: Rating) -> Double {
        max(parameters[r.rawValue - 1], Self.stabilityMin)
    }

    func initialDifficulty(_ r: Rating, clamp: Bool) -> Double {
        let d = parameters[4] - exp(parameters[5] * Double(r.rawValue - 1)) + 1
        return clamp ? clampDifficulty(d) : d
    }

    func shortTermStability(_ s: Double, _ r: Rating) -> Double {
        var inc = exp(parameters[17] * (Double(r.rawValue) - 3 + parameters[18])) * pow(s, -parameters[19])
        if r != .again { inc = max(inc, 1) }
        return max(s * inc, Self.stabilityMin)
    }

    func nextDifficulty(_ d: Double, _ r: Rating) -> Double {
        let delta = -(parameters[6] * (Double(r.rawValue) - 3))
        let damped = d + (10 - d) * delta / 9
        let target = initialDifficulty(.easy, clamp: false)
        return clampDifficulty(parameters[7] * target + (1 - parameters[7]) * damped)
    }

    func nextStability(difficulty d: Double, stability s: Double, retrievability r: Double, rating: Rating) -> Double {
        let value: Double
        if rating == .again {
            let longTerm = parameters[11] * pow(d, -parameters[12]) * (pow(s + 1, parameters[13]) - 1)
                * exp((1 - r) * parameters[14])
            let shortTerm = s / exp(parameters[17] * parameters[18])
            value = min(longTerm, shortTerm)
        } else {
            let hardPenalty = rating == .hard ? parameters[15] : 1
            let easyBonus = rating == .easy ? parameters[16] : 1
            value = s * (1 + exp(parameters[8]) * (11 - d) * pow(s, -parameters[9])
                * (exp((1 - r) * parameters[10]) - 1) * hardPenalty * easyBonus)
        }
        return max(value, Self.stabilityMin)
    }

    private func clampDifficulty(_ d: Double) -> Double {
        min(max(d, Self.minDifficulty), Self.maxDifficulty)
    }

    private func days(_ n: Int) -> TimeInterval { TimeInterval(n) * Self.day }

    private func fuzzed(_ interval: TimeInterval, random: () -> Double) -> TimeInterval {
        let ivl = Int(interval / Self.day)
        guard Double(ivl) >= 2.5 else { return interval }
        let ranges: [(start: Double, end: Double, factor: Double)] = [
            (2.5, 7, 0.15), (7, 20, 0.1), (20, .infinity, 0.05),
        ]
        var delta = 1.0
        for range in ranges {
            delta += range.factor * max(min(Double(ivl), range.end) - range.start, 0)
        }
        var lo = Int((Double(ivl) - delta).rounded(.toNearestOrEven))
        var hi = Int((Double(ivl) + delta).rounded(.toNearestOrEven))
        lo = max(2, lo)
        hi = min(hi, maximumInterval)
        lo = min(lo, hi)
        let pick = min(Int((random() * Double(hi - lo + 1) + Double(lo)).rounded(.toNearestOrEven)), maximumInterval)
        return days(pick)
    }

    /// Whole days between two instants, floored (matches Python's `timedelta.days`).
    static func wholeDays(from a: Date, to b: Date) -> Int {
        Int((b.timeIntervalSince(a) / day).rounded(.down))
    }
}
