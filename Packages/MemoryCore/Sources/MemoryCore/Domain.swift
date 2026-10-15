import Foundation

/// What each kind of training builds.
public enum MemoryDomain: String, Codable, CaseIterable, Sendable {
    case mnemonics       // method of loci, Major system — the strongest trainable memory skill
    case workingMemory   // n-back, complex span, simple span
    case associative     // binding pairs: names–faces, symbols–meanings, objects–places
    case retention       // long-term retrieval: next-day checks, spaced repetition
}

/// Every playable drill in the app.
public enum RealmTask: String, Codable, CaseIterable, Sendable, Identifiable {
    // Memory Palace program
    case routeWalk        // recall your palace's stops in order
    case wordSprint       // memorise N words in order with a palace
    case numberSprint     // memorise digits with the Major system
    case sprintRetention  // next-day recall of yesterday's sprint
    // Working-memory gym
    case dualNBack
    case complexSpan
    case sequences        // simple spatial span
    // Arcade (associative)
    case faceName
    case ancientRunes
    case stash
    // Benchmarks (technique-free transfer measures)
    case wordRecall       // 30-word free recall
    case digitSpan

    public var id: String { rawValue }

    public var domain: MemoryDomain {
        switch self {
        case .routeWalk, .wordSprint, .numberSprint: return .mnemonics
        case .dualNBack, .complexSpan, .sequences, .digitSpan: return .workingMemory
        case .faceName, .ancientRunes, .stash: return .associative
        case .sprintRetention, .wordRecall: return .retention
        }
    }

    public var isBenchmark: Bool { self == .wordRecall || self == .digitSpan }
}
