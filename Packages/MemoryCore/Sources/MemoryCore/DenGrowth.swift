import Foundation

/// The den grows with *consistency* (days practised), never with scores — effort is rewarded.
public enum DenGrowth {
    public static func stage(activeDaysLast28: Int) -> Int {
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
