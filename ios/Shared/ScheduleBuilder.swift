import Foundation

/// Builds the word rotation.
///
/// The queue is a weighted, shuffled, de-clustered list of word ids. Weight
/// comes from the Leitner box, so new and difficult words come round several
/// times more often than ones already marked "знаю", while still leaving the
/// order unpredictable enough that the rotation does not feel like a list.
enum ScheduleBuilder {
    /// Upper bound on queue length. Sized against the dictionary: a cap below
    /// the number of eligible words would retire part of the deck for a whole
    /// cycle, since the queue is a sample of the weighted pool. At the
    /// 5-minute default this is about three days of slots before anything
    /// repeats.
    static let maxQueueLength = 800

    static func buildQueue(
        from pool: [Word],
        progress: [String: WordProgress],
        seed: UInt64 = UInt64(Date().timeIntervalSince1970) / 3600
    ) -> [String] {
        guard !pool.isEmpty else { return [] }

        var weighted: [String] = []
        for word in pool {
            let weight = (progress[word.id] ?? .new).weight
            for _ in 0..<weight { weighted.append(word.id) }
        }

        // Everything is in the top box: the user has finished the deck. Keep a
        // light review rotation rather than showing nothing.
        if weighted.isEmpty {
            weighted = pool.map(\.id)
        }

        var rng = SplitMix64(seed: seed)
        weighted.shuffle(using: &rng)

        if weighted.count > maxQueueLength {
            weighted = Array(weighted.prefix(maxQueueLength))
        }

        return spaceOutDuplicates(weighted)
    }

    /// Pushes any id that would land next to a copy of itself further down the
    /// queue. A single forward pass is enough in practice and, unlike a full
    /// re-shuffle, cannot loop forever when one id dominates the pool.
    static func spaceOutDuplicates(_ ids: [String], minimumGap: Int = 3) -> [String] {
        guard ids.count > minimumGap else { return ids }
        var result: [String] = []
        result.reserveCapacity(ids.count)
        var pending: [String] = []

        for id in ids {
            if result.suffix(minimumGap).contains(id) {
                pending.append(id)
                continue
            }
            result.append(id)

            // Drain anything that has now moved far enough from its twin.
            if !pending.isEmpty {
                for (offset, held) in pending.enumerated() where !result.suffix(minimumGap).contains(held) {
                    result.append(held)
                    pending.remove(at: offset)
                    break
                }
            }
        }
        result.append(contentsOf: pending)
        return result
    }
}

/// Small deterministic PRNG so a rebuild with the same inputs produces the same
/// rotation. `SystemRandomNumberGenerator` would reshuffle the whole day every
/// time the widget's host process rebuilt state.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
