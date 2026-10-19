import Foundation

/// 3.7: deterministic IDs. Every entity gets its ID from `StableID.next()` instead of a random `UUID()`.
/// IDs feed hashed rolls (benchmark noise, rival rumours, people and science rolls) and orderings, so random IDs
/// made two runs of the same seed play differently. The stream is seeded from the game's seed when a game is
/// created and from the save when one is loaded (`GameState.idStream`), so the same seed always gives the same
/// IDs and the same game. A new game still gets a random seed, so real games are as varied as before.
///
/// The stream is only used on the main thread, where the game runs; anything built off the main thread
/// (save summaries decoded in the background) gets an ordinary random UUID and never disturbs the stream.
enum StableID {
    /// SplitMix64 position of the stream; 0 = not seeded (random UUIDs).
    nonisolated(unsafe) private static var position: UInt64 = 0

    /// Where the stream stands (saved with the game so a loaded game continues it).
    static var current: UInt64 { position }

    /// Starts the stream for a new game from its seed.
    static func seed(_ seed: UInt64) {
        guard Thread.isMainThread else { return }
        position = mix(seed ^ 0x51AB_1E1D_0DE7_E2A1) | 1
    }

    /// Continues the stream of a loaded game; older saves (no stream) start one from their RNG state.
    static func resume(_ s: GameState) {
        guard Thread.isMainThread else { return }
        position = s.idStream != 0 ? s.idStream : (mix(s.rng.state ^ 0x0DE7_E2A1_51AB_1E1D) | 1)
    }

    /// Runs `body` without moving the stream (what-if simulations on copies of the game).
    static func isolated<T>(_ body: () throws -> T) rethrows -> T {
        let saved = position
        defer { if Thread.isMainThread { position = saved } }
        return try body()
    }

    static func next() -> UUID {
        guard position != 0, Thread.isMainThread else { return UUID() }
        position &+= 0x9E37_79B9_7F4A_7C15
        let a = mix(position)
        position &+= 0x9E37_79B9_7F4A_7C15
        let b = mix(position)
        func byte(_ x: UInt64, _ i: UInt64) -> UInt8 { UInt8(truncatingIfNeeded: x >> (8 * i)) }
        // RFC 4122 version 4 layout (bytes 6 and 8), like UUID().
        return UUID(uuid: (byte(a, 0), byte(a, 1), byte(a, 2), byte(a, 3), byte(a, 4), byte(a, 5),
                           (byte(a, 6) & 0x0F) | 0x40, byte(a, 7),
                           (byte(b, 0) & 0x3F) | 0x80, byte(b, 1), byte(b, 2), byte(b, 3),
                           byte(b, 4), byte(b, 5), byte(b, 6), byte(b, 7)))
    }

    private static func mix(_ x: UInt64) -> UInt64 {
        var z = x
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
