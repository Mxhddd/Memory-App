import Foundation

/// 1-parameter (Rasch) adaptive difficulty: P(correct) = 1 / (1 + e^−(θ − b)).
/// θ is updated by EAP over a grid with a N(0,1) prior; items are chosen so P ≈ target
/// (≈0.75 normally, ≥0.9 in errorless mode).
public struct RaschAbility: Codable, Equatable, Sendable {
    public private(set) var responses: [Response] = []
    public var target: Double

    public struct Response: Codable, Equatable, Sendable {
        public var difficulty: Double
        public var correct: Bool
    }

    public init(target: Double = 0.75) { self.target = target }

    public static func probability(theta: Double, b: Double) -> Double {
        1 / (1 + exp(-(theta - b)))
    }

    public mutating func record(difficulty: Double, correct: Bool) {
        responses.append(.init(difficulty: difficulty, correct: correct))
        if responses.count > 60 { responses.removeFirst(responses.count - 60) } // recent window
    }

    /// Expected a-posteriori ability estimate.
    public var theta: Double {
        var num = 0.0, den = 0.0
        var t = -4.0
        while t <= 4.0001 {
            var logL = -t * t / 2 // N(0,1) prior
            for r in responses {
                let p = Self.probability(theta: t, b: r.difficulty)
                logL += r.correct ? log(p) : log(1 - p)
            }
            let w = exp(logL)
            num += t * w
            den += w
            t += 0.05
        }
        return den > 0 ? num / den : 0
    }

    /// Ideal item difficulty: b = θ − ln(p/(1−p)).
    public var targetDifficulty: Double {
        theta - log(target / (1 - target))
    }

    /// Pick the item whose difficulty is closest to the target.
    public func choose<T>(from items: [T], difficulty: (T) -> Double) -> T? {
        let b = targetDifficulty
        return items.min { abs(difficulty($0) - b) < abs(difficulty($1) - b) }
    }
}
