import Foundation

/// The rotation plan the widget reads to decide which word belongs to which
/// minute of the day.
///
/// The widget never writes state and never runs custom logic between refreshes:
/// given the same `Schedule`, any point in time maps to exactly one word. That
/// is what makes a 24-hour timeline buildable in a single pass — see
/// `WordProvider`.
struct Schedule: Codable, Equatable {
    /// The instant slot 0 began.
    var anchor: Date
    /// How long one word stays on the lock screen.
    var slotMinutes: Int
    /// Word ids in display order; wraps around when exhausted.
    var queue: [String]

    static let empty = Schedule(anchor: Date(timeIntervalSince1970: 0), slotMinutes: 5, queue: [])

    var slotDuration: TimeInterval { TimeInterval(slotMinutes * 60) }

    /// Which slot a given instant falls into. Negative values (a date before the
    /// anchor) are clamped to 0 so history views never index backwards past the
    /// start of the queue.
    func slotIndex(for date: Date) -> Int {
        guard slotDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(anchor)
        return max(0, Int(floor(elapsed / slotDuration)))
    }

    /// The instant a given slot begins.
    func slotStart(_ index: Int) -> Date {
        anchor.addingTimeInterval(TimeInterval(index) * slotDuration)
    }

    func wordID(atSlot index: Int) -> String? {
        guard !queue.isEmpty else { return nil }
        return queue[((index % queue.count) + queue.count) % queue.count]
    }

    func word(at date: Date, in database: WordDatabase = .shared) -> Word? {
        guard let id = wordID(atSlot: slotIndex(for: date)) else { return nil }
        return database.word(id: id)
    }
}

/// How well the user knows one word. A plain Leitner box: a word answered
/// "знаю" moves up and appears less often; "учить" drops it back to the front.
struct WordProgress: Codable, Equatable {
    var box: Int
    var lastSeen: Date?

    static let new = WordProgress(box: 0, lastSeen: nil)

    /// Relative frequency in the rotation. Box 3 is retired from the queue
    /// unless the remaining pool is too small to fill it.
    var weight: Int {
        switch box {
        case ..<1: return 4
        case 1: return 3
        case 2: return 1
        default: return 0
        }
    }

    mutating func markKnown(now: Date = Date()) {
        box = min(3, box + 1)
        lastSeen = now
    }

    mutating func markLearning(now: Date = Date()) {
        box = 0
        lastSeen = now
    }
}

struct Settings: Codable, Equatable {
    var levels: Set<Level>
    var slotMinutes: Int
    /// Show the Russian translation on the lock screen, or make it a guess and
    /// reveal only on tap.
    var hideTranslationOnLockScreen: Bool

    static let `default` = Settings(
        levels: [.b1, .b2],
        slotMinutes: 5,
        hideTranslationOnLockScreen: false
    )

    static let slotOptions = [2, 5, 10, 15, 30, 60]
}
