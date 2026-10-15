import Foundation

/// Operation span: remember letters while verifying simple equations in between.
/// Scored with partial-credit units (Conway et al. 2005) — the mean proportion of letters
/// recalled in the correct position per set — plus processing accuracy, which must stay
/// ≥ 85 % for the span score to count (so people can't skip the maths to rehearse).
public struct SpanItem: Equatable, Sendable {
    public let equation: String
    public let equationIsTrue: Bool
    public let letter: String
}

public struct ComplexSpanScore: Equatable, Sendable {
    public var partialCredit: Double     // 0…1
    public var absolute: Int             // sum of set sizes recalled perfectly
    public var processingAccuracy: Double
    public var valid: Bool { processingAccuracy >= 0.85 }
}

public enum ComplexSpan {
    public static let letters = ["F", "H", "J", "K", "L", "N", "P", "Q", "R", "S", "T", "Y"]

    /// Set sizes in a shuffled order so people can't predict the length.
    public static func setSizes(minSize: Int, maxSize: Int, repetitions: Int = 1, seed: String) -> [Int] {
        var rng = SeededRandom(seed + "-sizes")
        return Array(repeating: Array(minSize...maxSize), count: repetitions).flatMap { $0 }.shuffled(using: &rng)
    }

    public static func set(size: Int, seed: String) -> [SpanItem] {
        var rng = SeededRandom(seed)
        let picked = letters.shuffled(using: &rng).prefix(size)
        return picked.map { letter in
            let a = Int.random(in: 2...9, using: &rng)
            let b = Int.random(in: 1...9, using: &rng)
            let mult = Bool.random(using: &rng)
            let truth = mult ? a * b : a + b
            let isTrue = Bool.random(using: &rng)
            let shown = isTrue ? truth : truth + [-2, -1, 1, 2].randomElement(using: &rng)!
            return SpanItem(equation: "\(a) \(mult ? "×" : "+") \(b) = \(shown)", equationIsTrue: isTrue, letter: letter)
        }
    }

    public static func score(sets: [[SpanItem]], recalled: [[String]], processingCorrect: Int, processingTotal: Int) -> ComplexSpanScore {
        var credit = 0.0, absolute = 0
        for (set, answer) in zip(sets, recalled) {
            let correct = zip(set, answer).filter { $0.0.letter == $0.1 }.count
            credit += Double(correct) / Double(max(set.count, 1))
            if correct == set.count && answer.count == set.count { absolute += set.count }
        }
        return ComplexSpanScore(partialCredit: sets.isEmpty ? 0 : credit / Double(sets.count), absolute: absolute,
                                processingAccuracy: processingTotal > 0 ? Double(processingCorrect) / Double(processingTotal) : 0)
    }
}

/// Forward digit span: two trials per length; stop when both trials at a length fail.
public enum DigitSpan {
    public static func digits(length: Int, seed: String) -> [Int] {
        var rng = SeededRandom(seed + "-\(length)")
        var out: [Int] = []
        while out.count < length {
            let d = Int.random(in: 0...9, using: &rng)
            if d != out.last { out.append(d) }
        }
        return out
    }

    /// Longest length with at least one correct trial, given (length, correct) results in order.
    public static func span(_ results: [(length: Int, correct: Bool)]) -> Int {
        results.filter(\.correct).map(\.length).max() ?? 0
    }

    public static func shouldStop(_ results: [(length: Int, correct: Bool)]) -> Bool {
        guard let last = results.last else { return false }
        let atLength = results.filter { $0.length == last.length }
        return atLength.count >= 2 && atLength.allSatisfy { !$0.correct }
    }
}
