import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// State shared between the app and the widget extension through an App Group.
///
/// The app is the only writer. The widget reads `schedule` and `settings` when
/// it builds a timeline and never writes back — a widget extension gets a very
/// small time and memory budget, and concurrent writes from a process that may
/// be killed mid-refresh are not worth the risk.
final class SharedStore {
    /// Must match the App Group capability on BOTH targets.
    static let appGroupID = "group.com.wordpeek.shared"

    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let schedule = "schedule.v1"
        static let progress = "progress.v1"
        static let settings = "settings.v1"
        static let history = "history.v1"
    }

    /// Falls back to `.standard` so the app still runs (widget sharing aside)
    /// if the App Group entitlement is missing — a common first-build snag.
    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if SharedStore.hasAppGroupContainer,
                  let suite = UserDefaults(suiteName: SharedStore.appGroupID) {
            self.defaults = suite
        } else {
            self.defaults = .standard
        }
    }

    /// `UserDefaults(suiteName:)` returns a usable-looking object even when the
    /// entitlement is missing — writes just silently stay private to the
    /// process. The container URL is the check that actually fails without the
    /// capability, so it is what both the warning and the fallback rely on.
    private static var hasAppGroupContainer: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStore.appGroupID
        ) != nil
    }

    var isAppGroupConfigured: Bool {
        SharedStore.hasAppGroupContainer
    }

    // MARK: - Settings

    var settings: Settings {
        get { read(Key.settings) ?? .default }
        set { write(newValue, to: Key.settings) }
    }

    // MARK: - Schedule

    var schedule: Schedule {
        get { read(Key.schedule) ?? .empty }
        set { write(newValue, to: Key.schedule) }
    }

    // MARK: - Progress

    var progress: [String: WordProgress] {
        get { read(Key.progress) ?? [:] }
        set { write(newValue, to: Key.progress) }
    }

    func progress(for id: String) -> WordProgress {
        progress[id] ?? .new
    }

    // MARK: - History

    /// A persisted journal of what was actually shown. The queue is rebuilt
    /// on every answer, so deriving "the past" from the current queue would
    /// rewrite it retroactively; the journal is append-only.
    struct HistoryEntry: Codable, Equatable, Identifiable {
        let id: UUID
        let date: Date
        let wordID: String

        init(date: Date, wordID: String) {
            self.id = UUID()
            self.date = date
            self.wordID = wordID
        }
    }

    static let historyLimit = 60

    var history: [HistoryEntry] {
        get { read(Key.history) ?? [] }
        set { write(newValue, to: Key.history) }
    }

    /// Appends every slot that has elapsed since the last journal entry,
    /// using the current schedule. All mutations happen in the app process,
    /// so between mutations the current schedule is exactly what the lock
    /// screen displayed. Cheap when nothing elapsed.
    func materializeHistory(now: Date = Date()) {
        let schedule = self.schedule
        guard !schedule.queue.isEmpty else { return }

        var log = history
        let lastDate = log.last?.date ?? .distantPast
        let currentSlot = schedule.slotIndex(for: now)
        let firstCandidate = max(schedule.startSlot, currentSlot - Self.historyLimit + 1)
        guard firstCandidate <= currentSlot else { return }

        var appended = false
        for slot in firstCandidate...currentSlot {
            let start = schedule.slotStart(slot)
            guard start > lastDate, start <= now else { continue }
            guard let id = schedule.wordID(atSlot: slot) else { continue }
            log.append(HistoryEntry(date: start, wordID: id))
            appended = true
        }
        guard appended else { return }
        if log.count > Self.historyLimit {
            log.removeFirst(log.count - Self.historyLimit)
        }
        history = log
    }

    /// Journals an entry "right now" — used when an answer switches the card
    /// mid-slot, so the new word appears in the history immediately.
    private func appendToHistory(_ wordID: String, at date: Date) {
        var log = history
        guard log.last?.wordID != wordID else { return }
        log.append(HistoryEntry(date: date, wordID: wordID))
        if log.count > Self.historyLimit {
            log.removeFirst(log.count - Self.historyLimit)
        }
        history = log
    }

    /// Records an answer, journals the history, and restarts the rotation
    /// from the current slot — the card (and the lock screen) always advance
    /// to a fresh word, never back to the one just answered.
    func record(_ answer: Answer, for id: String, database: WordDatabase = .shared, now: Date = Date()) {
        materializeHistory(now: now)

        var all = progress
        var entry = all[id] ?? .new
        switch answer {
        case .known: entry.markKnown(now: now)
        case .learning: entry.markLearning(now: now)
        }
        all[id] = entry
        progress = all

        rebuildSchedule(database: database, preservingAnchor: true, answered: id, now: now)

        // The card switched mid-slot; put the new word into the journal so
        // the history reflects what is actually on screen.
        if let shown = schedule.wordID(atSlot: schedule.slotIndex(for: now)) {
            appendToHistory(shown, at: now)
        }
    }

    enum Answer { case known, learning }

    // MARK: - Rebuilding the rotation

    /// Rebuilds the queue from the current settings and progress.
    ///
    /// `preservingAnchor` keeps the slot grid where it is, so answering a word
    /// does not reshuffle the clock underneath the user. The new queue starts
    /// at the current slot (`startSlot`), and `answered` plus the last few
    /// journal entries are kept out of its head, so the user never sees the
    /// same word twice in a row.
    func rebuildSchedule(
        database: WordDatabase = .shared,
        preservingAnchor: Bool = false,
        answered: String? = nil,
        now: Date = Date()
    ) {
        materializeHistory(now: now)

        let current = schedule
        let settings = self.settings
        let pool = database.words(levels: settings.levels)
        var recent = history.suffix(3).map(\.wordID)
        if let answered { recent.append(answered) }
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: progress, avoidingRecent: recent)

        let anchor: Date
        let startSlot: Int
        if preservingAnchor, current.anchor.timeIntervalSince1970 > 0,
           current.slotMinutes == settings.slotMinutes {
            anchor = current.anchor
            startSlot = current.slotIndex(for: now)
        } else {
            anchor = now
            startSlot = 0
        }

        schedule = Schedule(anchor: anchor, slotMinutes: settings.slotMinutes, queue: queue, startSlot: startSlot)
        reloadWidgets()
    }

    func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func resetProgress(database: WordDatabase = .shared) {
        progress = [:]
        rebuildSchedule(database: database)
    }

    // MARK: - Codable helpers

    private func read<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
