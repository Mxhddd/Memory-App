import Foundation

/// EWMA control chart over a domain's daily z-scores (relative to the person's own baseline).
///   z_t = λ·x_t + (1 − λ)·z_(t−1);   lower limit = μ0 − L·σ·√(λ/(2−λ)·(1 − (1−λ)^(2t)))
public struct EWMAChart: Codable, Equatable, Sendable {
    public var lambda: Double
    public var L: Double
    public var mu0: Double
    public var sigma: Double
    public private(set) var value: Double
    public private(set) var count: Int

    public init(lambda: Double = 0.2, L: Double = 2.7, mu0: Double = 0, sigma: Double = 1) {
        self.lambda = lambda
        self.L = L
        self.mu0 = mu0
        self.sigma = sigma
        value = mu0
        count = 0
    }

    public var lowerLimit: Double {
        let t = Double(max(count, 1))
        let width = (lambda / (2 - lambda) * (1 - pow(1 - lambda, 2 * t))).squareRoot()
        return mu0 - L * sigma * width
    }

    /// Asymptotic limit (t → ∞): μ0 − L·σ·√(λ/(2−λ))
    public var asymptoticLowerLimit: Double {
        mu0 - L * sigma * (lambda / (2 - lambda)).squareRoot()
    }

    public var isBelowLimit: Bool { count > 0 && value < lowerLimit }

    @discardableResult
    public mutating func add(_ x: Double) -> Double {
        value = lambda * x + (1 - lambda) * value
        count += 1
        return value
    }
}
