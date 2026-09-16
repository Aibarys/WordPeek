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
            // One placement per step: draining greedily here empties the
            // reserve early and leaves the tail with nothing to interleave.
            if !pending.isEmpty {
                for (offset, held) in pending.enumerated() where !result.suffix(minimumGap).contains(held) {
                    result.append(held)
                    pending.remove(at: offset)
                    break
                }
            }
        }

        // Ids still held when the pass ends cannot go at the tail, but may
        // fit elsewhere: inserting between two items only widens every other
        // pair's distance, so it cannot break spacing that already holds. An
        // id with no valid position anywhere (one word owns the whole tail)
        // is appended as-is — dropping it would skew the Leitner weights.
        for held in pending {
            result.insert(held, at: insertionIndex(for: held, in: result, minimumGap: minimumGap))
        }
        return result
    }

    /// First position where `id` would sit at least `minimumGap` items from
    /// every copy of itself on both sides; `endIndex` (a plain append) if no
    /// such position exists.
    private static func insertionIndex(for id: String, in result: [String], minimumGap: Int) -> Int {
        for index in result.indices {
            let before = result[max(0, index - minimumGap)..<index]
            let after = result[index..<min(result.count, index + minimumGap)]
            if !before.contains(id), !after.contains(id) { return index }
        }
        return result.count
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
