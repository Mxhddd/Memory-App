import Foundation

/// Multi-day learning curve (BRANCH / ORCA-LLT style), the app's headline metric.
///
///   y_d = A − (A − y₁)·e^(−λ(d−1))        d = 1…n, y in [0, 1]
public struct LearningCurveFit: Equatable, Sendable {
    public var asymptote: Double   // A
    public var rate: Double        // λ
    public var day1: Double        // y₁ (observed)
    public var sse: Double

    public func predict(day: Double) -> Double {
        asymptote - (asymptote - day1) * exp(-rate * (day - 1))
    }
}

public enum LearningCurve {
    /// Least-squares fit. For a fixed λ the model is linear in A, so we grid-search λ and solve A
    /// in closed form — robust with only 3–7 points and no optimiser dependency.
    public static func fit(_ daily: [Double]) -> LearningCurveFit? {
        guard daily.count >= 3 else { return nil }
        let y1 = daily[0]
        var best: LearningCurveFit?
        var lambda = 0.01
        while lambda <= 4.0 {
            var sgg = 0.0, sgr = 0.0
            for (i, y) in daily.enumerated() {
                let e = exp(-lambda * Double(i))
                let g = 1 - e
                sgg += g * g
                sgr += g * (y - y1 * e)
            }
            if sgg > 0 {
                let a = min(max(sgr / sgg, 0), 1)
                let candidate = LearningCurveFit(asymptote: a, rate: lambda, day1: y1, sse: 0)
                let sse = daily.enumerated().reduce(0.0) { acc, pair in
                    let r = pair.element - candidate.predict(day: Double(pair.offset + 1))
                    return acc + r * r
                }
                if best == nil || sse < best!.sse - 1e-12 {
                    best = LearningCurveFit(asymptote: a, rate: lambda, day1: y1, sse: sse)
                }
            }
            lambda += 0.01
        }
        return best
    }

    /// MDLC-style normalised area under the day-by-day accuracy curve (trapezoid rule), 0…1.
    /// Combines day-1 performance with the trajectory over later days.
    public static func normalizedAUC(_ daily: [Double]) -> Double? {
        guard daily.count >= 2 else { return daily.first }
        var area = 0.0
        for i in 1..<daily.count { area += (daily[i - 1] + daily[i]) / 2 }
        return area / Double(daily.count - 1)
    }

    /// Practice gain = mean(days 5–7) − day 1. With fewer days, uses the last ⌈n/3⌉ days.
    /// SWAN: the *absence* of this gain is the perimenopause signature.
    public static func practiceGain(_ daily: [Double]) -> Double? {
        guard daily.count >= 3 else { return nil }
        let tail = daily.count >= 7 ? Array(daily[4..<7]) : Array(daily.suffix(Int(ceil(Double(daily.count) / 3))))
        return tail.reduce(0, +) / Double(tail.count) - daily[0]
    }
}
