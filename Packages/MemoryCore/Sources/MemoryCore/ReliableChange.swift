import Foundation

/// Reliable-change statistics for comparing one burst with the previous one.
public enum ReliableChange {
    /// Standard error of measurement: SEM = s·√(1 − r_xx)
    public static func sem(sd: Double, reliability: Double) -> Double {
        sd * (1 - reliability).squareRoot()
    }

    /// S_diff = √(2·SEM²)
    public static func sDiff(sd: Double, reliability: Double) -> Double {
        (2 * pow(sem(sd: sd, reliability: reliability), 2)).squareRoot()
    }

    /// Jacobson–Truax RCI = (X2 − X1) / S_diff
    public static func jacobsonTruax(x1: Double, x2: Double, sd: Double, reliability: Double) -> Double {
        (x2 - x1) / sDiff(sd: sd, reliability: reliability)
    }

    /// Chelune practice-adjusted RCI = [(X2 − X1) − (M2 − M1)] / S_diff.
    // verify against Chelune et al. 1993 before relying on it clinically (form taken from secondary sources).
    public static func practiceAdjusted(x1: Double, x2: Double, expectedGain: Double, sd: Double, reliability: Double) -> Double {
        ((x2 - x1) - expectedGain) / sDiff(sd: sd, reliability: reliability)
    }

    /// McSweeny standardised regression-based change: z = (Y2 − Ŷ) / SEE
    public static func srbZ(observed: Double, predicted: Double, see: Double) -> Double {
        (observed - predicted) / see
    }

    /// Precision-weighted shrinkage of a personal practice-gain estimate toward a published prior.
    /// With no personal data the prior is returned unchanged.
    public static func shrunkExpectedGain(personal: [Double], prior: Double, priorWeight: Double = 2) -> Double {
        guard !personal.isEmpty else { return prior }
        let n = Double(personal.count)
        let mean = personal.reduce(0, +) / n
        return (prior * priorWeight + mean * n) / (priorWeight + n)
    }

    public static let threshold90 = -1.645
    public static let threshold95 = -1.96
}
