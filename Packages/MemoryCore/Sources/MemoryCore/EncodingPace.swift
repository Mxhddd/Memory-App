import Foundation

/// The encoding speed ladder. Memory athletes speed up only once accuracy holds; so does this:
/// the per-item study budget shrinks after a clearly mastered sprint and grows back after a
/// rough one, between a comfortable start and a sensible floor.
public enum EncodingPace {
    public static func start(_ kind: DrillKind) -> Double {
        switch kind {
        case .wordSprint: return 6
        case .numberSprint: return 3
        case .faceName: return 8
        case .routeWalk: return 0
        }
    }

    public static func floor(_ kind: DrillKind) -> Double {
        switch kind {
        case .wordSprint: return 3
        case .numberSprint: return 1.5
        case .faceName: return 5
        case .routeWalk: return 0
        }
    }

    public static func ceiling(_ kind: DrillKind) -> Double { start(kind) * 1.5 }

    public static let masteredAccuracy = 0.9
    public static let roughAccuracy = 0.6

    public static func next(current: Double, accuracy: Double, kind: DrillKind) -> Double {
        let raw = accuracy >= masteredAccuracy ? current * 0.9 : accuracy < roughAccuracy ? current * 1.15 : current
        return (min(max(raw, floor(kind)), ceiling(kind)) * 10).rounded() / 10
    }

    /// Replays past course sprints (oldest first) to find today's per-item budget.
    public static func pace(kind: DrillKind, accuracies: [Double]) -> Double {
        accuracies.reduce(start(kind)) { next(current: $0, accuracy: $1, kind: kind) }
    }
}

extension Course {
    /// Encoding time for a sprint at the person's own pace (seconds per item from the ladder).
    public static func encodingSeconds(kind: DrillKind, size: Int, pace: Double) -> Int {
        let minimum: Int
        switch kind {
        case .wordSprint: minimum = 45
        case .numberSprint: minimum = 30
        case .faceName: minimum = 40
        case .routeWalk: return 0
        }
        return max(minimum, Int((Double(size) * pace).rounded()))
    }
}
