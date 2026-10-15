import Foundation

/// SplitMix64: tiny, deterministic RNG so stimuli and alternate forms are reproducible per seed.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public init(_ string: String) {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325 // FNV-1a
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        self.init(seed: hash)
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
