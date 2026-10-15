import Foundation

/// Thompson-sampling contextual bandit over reminder slots × task types (JITAI layer, phase 3),
/// plus micro-randomised prompting and a daily prompt cap to limit reminder fatigue.
public struct ThompsonBandit: Codable, Equatable, Sendable {
    public struct Arm: Codable, Equatable, Sendable {
        public var id: String
        public var alpha: Double
        public var beta: Double
    }

    public private(set) var arms: [Arm]

    /// `priors` lets us start from sensible defaults (e.g. mornings for the older user).
    public init(armIDs: [String], priors: [String: (alpha: Double, beta: Double)] = [:]) {
        arms = armIDs.map { id in
            let p = priors[id] ?? (1, 1)
            return Arm(id: id, alpha: p.alpha, beta: p.beta)
        }
    }

    public func choose<G: RandomNumberGenerator>(using rng: inout G) -> String? {
        arms.max { a, b in
            Self.sampleBeta(a.alpha, a.beta, &rng) < Self.sampleBeta(b.alpha, b.beta, &rng)
        }?.id
    }

    /// reward in [0, 1]: session completion, optionally blended with accuracy vs predicted R.
    public mutating func update(armID: String, reward: Double) {
        guard let i = arms.firstIndex(where: { $0.id == armID }) else { return }
        let r = min(max(reward, 0), 1)
        arms[i].alpha += r
        arms[i].beta += 1 - r
    }

    public func mean(of armID: String) -> Double? {
        arms.first { $0.id == armID }.map { $0.alpha / ($0.alpha + $0.beta) }
    }

    // Beta(a,b) = X/(X+Y), X~Gamma(a), Y~Gamma(b)
    static func sampleBeta<G: RandomNumberGenerator>(_ a: Double, _ b: Double, _ rng: inout G) -> Double {
        let x = sampleGamma(a, &rng)
        let y = sampleGamma(b, &rng)
        return x / (x + y)
    }

    // Marsaglia–Tsang
    static func sampleGamma<G: RandomNumberGenerator>(_ shape: Double, _ rng: inout G) -> Double {
        if shape < 1 {
            let u = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &rng)
            return sampleGamma(shape + 1, &rng) * pow(u, 1 / shape)
        }
        let d = shape - 1.0 / 3.0
        let c = 1 / (9 * d).squareRoot()
        while true {
            var x: Double, v: Double
            repeat {
                x = sampleNormal(&rng)
                v = 1 + c * x
            } while v <= 0
            v = v * v * v
            let u = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &rng)
            if log(u) < 0.5 * x * x + d - d * v + d * log(v) { return d * v }
        }
    }

    static func sampleNormal<G: RandomNumberGenerator>(_ rng: inout G) -> Double {
        let u1 = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &rng)
        let u2 = Double.random(in: 0..<1, using: &rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

public struct PromptPolicy: Sendable {
    public var dailyCap: Int
    public var promptProbability: Double

    public init(dailyCap: Int = 3, promptProbability: Double = 0.6) {
        self.dailyCap = dailyCap
        self.promptProbability = promptProbability
    }

    /// Micro-randomised decision: under the cap, prompt with probability p (60/40 by default).
    public func shouldPrompt<G: RandomNumberGenerator>(sentToday: Int, using rng: inout G) -> Bool {
        guard sentToday < dailyCap else { return false }
        return Double.random(in: 0..<1, using: &rng) < promptProbability
    }
}
