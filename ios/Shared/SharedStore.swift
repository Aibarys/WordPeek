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

    /// Records an answer and rebuilds the upcoming rotation so the change is
    /// visible on the lock screen within one slot.
    func record(_ answer: Answer, for id: String, database: WordDatabase = .shared) {
        var all = progress
        var entry = all[id] ?? .new
        switch answer {
        case .known: entry.markKnown()
        case .learning: entry.markLearning()
        }
        all[id] = entry
        progress = all
        rebuildSchedule(database: database, preservingAnchor: true)
    }

    enum Answer { case known, learning }

    // MARK: - Rebuilding the rotation

    /// Rebuilds the queue from the current settings and progress.
    ///
    /// `preservingAnchor` keeps the slot grid where it is, so answering a word
    /// does not reshuffle the clock underneath the user; only the contents of
    /// upcoming slots change.
    func rebuildSchedule(database: WordDatabase = .shared, preservingAnchor: Bool = false) {
        let current = schedule
        let settings = self.settings
        let pool = database.words(levels: settings.levels)
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: progress)

        let anchor: Date
        if preservingAnchor, current.anchor.timeIntervalSince1970 > 0,
           current.slotMinutes == settings.slotMinutes {
            anchor = current.anchor
        } else {
            anchor = Date()
        }

        schedule = Schedule(anchor: anchor, slotMinutes: settings.slotMinutes, queue: queue)
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
