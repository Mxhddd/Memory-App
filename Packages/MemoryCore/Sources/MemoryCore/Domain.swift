import Foundation

/// Memory domains ("realms") measured and trained separately.
public enum MemoryDomain: String, Codable, CaseIterable, Sendable {
    case associative
    case episodicVerbal
    case prospective
    case speed
    case workingMemory
    case everydayLapses
}

/// Every playable task in the app. Several tasks can feed one domain.
public enum RealmTask: String, Codable, CaseIterable, Sendable, Identifiable {
    case faceName
    case snackPrices
    case wordList
    case stash
    case sequences
    case runeSort
    case moonBell
    case ancientRunes

    public var id: String { rawValue }

    public var domain: MemoryDomain {
        switch self {
        case .faceName, .snackPrices, .stash, .ancientRunes: return .associative
        case .wordList: return .episodicVerbal
        case .moonBell: return .prospective
        case .runeSort: return .speed
        case .sequences: return .workingMemory
        }
    }

    /// Multi-day learning tasks keep the *same* stimuli for a whole burst so a curve can be fitted.
    public var isMultiDayLearning: Bool {
        self == .faceName || self == .ancientRunes
    }
}
