import Foundation

/// Memory-sports style scoring for ordered recall with a memory palace.
public struct SprintScore: Equatable, Sendable {
    public var inPlace: Int      // correct item at the correct position
    public var anyPlace: Int     // correct item anywhere (free recall)
    public var total: Int
    public var accuracy: Double { total > 0 ? Double(inPlace) / Double(total) : 0 }
}

public enum Loci {
    /// Words: lenient matching (case, accents, one typo for longer words).
    public static func scoreWords(recalled: [String], targets: [String]) -> SprintScore {
        var inPlace = 0
        for (i, t) in targets.enumerated() where i < recalled.count {
            if AnswerMatch.matches(recalled[i], t) { inPlace += 1 }
        }
        var remaining = targets
        var any = 0
        for r in recalled where !r.trimmingCharacters(in: .whitespaces).isEmpty {
            if let j = remaining.firstIndex(where: { AnswerMatch.matches(r, $0) }) {
                any += 1
                remaining.remove(at: j)
            }
        }
        return SprintScore(inPlace: inPlace, anyPlace: any, total: targets.count)
    }

    /// Digits: exact match per position.
    public static func scoreDigits(recalled: String, target: String) -> SprintScore {
        let r = Array(recalled.filter(\.isNumber)), t = Array(target)
        let inPlace = zip(r, t).filter { $0 == $1 }.count
        return SprintScore(inPlace: inPlace, anyPlace: inPlace, total: t.count)
    }

    /// A palace walk needs one stop per item.
    public static func stopsNeeded(items: Int, perStop: Int = 1) -> Int {
        Int((Double(items) / Double(max(perStop, 1))).rounded(.up))
    }
}
