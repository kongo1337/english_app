import Foundation

/// SplitMix64: a tiny deterministic generator. Used wherever the study logic needs
/// "randomness", so that results are reproducible between runs and in tests.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A stable pseudo-random number for `key`: unlike `Hasher`, it is the same on every
    /// launch and platform, and it does not depend on the other words in the set.
    public static func stableValue(seed: UInt64, key: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325  // FNV-1a
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        var generator = SeededRandom(seed: hash ^ seed)
        return generator.next()
    }
}
