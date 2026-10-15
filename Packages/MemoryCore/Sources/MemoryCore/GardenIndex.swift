import Foundation

/// Composite "Memory Garden Index": a weighted mean of the person's own domain z-scores.
/// Displayed only as den/garden growth — never as a percentile against other people.
public enum GardenIndex {
    public static let weights: [MemoryDomain: Double] = [
        .associative: 0.25,
        .episodicVerbal: 0.20,
        .prospective: 0.20,
        .speed: 0.15,
        .workingMemory: 0.10,
        .everydayLapses: 0.10,
    ]

    /// Weighted mean over the domains that have data (weights renormalised).
    public static func index(_ z: [MemoryDomain: Double]) -> Double? {
        var total = 0.0, weightSum = 0.0
        for (domain, value) in z {
            guard let w = weights[domain], value.isFinite else { continue }
            total += w * value
            weightSum += w
        }
        return weightSum > 0 ? total / weightSum : nil
    }

    /// Den growth stage 0…5 from *consistency* (active days in the last 28) — effort, not score.
    public static func growthStage(activeDaysLast28: Int) -> Int {
        switch activeDaysLast28 {
        case ..<1: return 0
        case 1..<4: return 1
        case 4..<9: return 2
        case 9..<15: return 3
        case 15..<21: return 4
        default: return 5
        }
    }
}

/// Person-relative z-score: (x − μ_baseline) / σ_within. Falls back to a floor σ early on.
public func personalZ(_ x: Double, baseline: [Double], sdFloor: Double = 0.05) -> Double? {
    guard baseline.count >= 2 else { return nil }
    let mean = baseline.reduce(0, +) / Double(baseline.count)
    let variance = baseline.map { pow($0 - mean, 2) }.reduce(0, +) / Double(baseline.count - 1)
    return (x - mean) / max(variance.squareRoot(), sdFloor)
}
