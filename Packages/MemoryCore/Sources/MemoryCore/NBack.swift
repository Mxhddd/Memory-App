import Foundation

/// Dual n-back (Jaeggi et al. 2008 protocol): a square flashes on a 3×3 grid while a letter is
/// spoken; respond when the position and/or the letter matches the one n steps back.
/// Blocks are 20 + n trials with a fixed number of targets per modality; the level adapts:
/// up when both modalities have < 3 errors, down when either has > 5.
public struct NBackTrial: Equatable, Sendable {
    public let position: Int   // 0…8
    public let letter: String
    public let positionMatch: Bool
    public let letterMatch: Bool
}

public struct NBackResponse: Equatable, Sendable {
    public var position: Bool
    public var letter: Bool
    public init(position: Bool = false, letter: Bool = false) {
        self.position = position
        self.letter = letter
    }
}

public struct NBackBlockScore: Equatable, Sendable {
    public var positionErrors: Int   // misses + false alarms
    public var letterErrors: Int
    public var hits: Int
    public var targets: Int
    public var accuracy: Double { targets > 0 ? Double(hits) / Double(targets) : 0 }
}

public enum NBack {
    /// Consonants that are easy to tell apart when spoken (as in the original studies).
    public static let letters = ["C", "H", "K", "L", "Q", "R", "S", "T"]
    public static let targetsPerModality = 6
    public static let bothTargets = 2

    public static func trialCount(n: Int) -> Int { 20 + n }

    public static func block(n: Int, seed: String) -> [NBackTrial] {
        precondition(n >= 1)
        var rng = SeededRandom("\(seed)-n\(n)")
        let count = trialCount(n: n)
        let eligible = Array(n..<count).shuffled(using: &rng)
        // `bothTargets` trials match on both; the rest of each modality's targets are separate.
        let both = Set(eligible.prefix(bothTargets))
        let positionOnly = Set(eligible.dropFirst(bothTargets).prefix(targetsPerModality - bothTargets))
        let letterOnly = Set(eligible.dropFirst(targetsPerModality).prefix(targetsPerModality - bothTargets))
        let posTargets = both.union(positionOnly)
        let letTargets = both.union(letterOnly)

        var positions: [Int] = []
        var chosenLetters: [String] = []
        for i in 0..<count {
            if posTargets.contains(i) {
                positions.append(positions[i - n])
            } else {
                var p = Int.random(in: 0..<9, using: &rng)
                while i >= n && p == positions[i - n] { p = Int.random(in: 0..<9, using: &rng) }
                positions.append(p)
            }
            if letTargets.contains(i) {
                chosenLetters.append(chosenLetters[i - n])
            } else {
                var l = letters.randomElement(using: &rng)!
                while i >= n && l == chosenLetters[i - n] { l = letters.randomElement(using: &rng)! }
                chosenLetters.append(l)
            }
        }
        var trials: [NBackTrial] = []
        for i in 0..<count {
            let posMatch = i >= n && positions[i] == positions[i - n]
            let letMatch = i >= n && chosenLetters[i] == chosenLetters[i - n]
            trials.append(NBackTrial(position: positions[i], letter: chosenLetters[i],
                                     positionMatch: posMatch, letterMatch: letMatch))
        }
        return trials
    }

    public static func score(_ trials: [NBackTrial], responses: [NBackResponse]) -> NBackBlockScore {
        var pe = 0, le = 0, hits = 0, targets = 0
        for (t, r) in zip(trials, responses) {
            if t.positionMatch { targets += 1; if r.position { hits += 1 } else { pe += 1 } } else if r.position { pe += 1 }
            if t.letterMatch { targets += 1; if r.letter { hits += 1 } else { le += 1 } } else if r.letter { le += 1 }
        }
        return NBackBlockScore(positionErrors: pe, letterErrors: le, hits: hits, targets: targets)
    }

    /// Jaeggi staircase.
    public static func nextLevel(current n: Int, score: NBackBlockScore, maxLevel: Int = 9) -> Int {
        if score.positionErrors < 3 && score.letterErrors < 3 { return min(n + 1, maxLevel) }
        if score.positionErrors > 5 || score.letterErrors > 5 { return max(1, n - 1) }
        return n
    }
}
