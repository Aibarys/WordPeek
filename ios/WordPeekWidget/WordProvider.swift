import WidgetKit
import SwiftUI

struct WordTimelineEntry: TimelineEntry {
    let date: Date
    let word: Word
    let hideTranslation: Bool
}

/// The mechanism that makes this app work on iOS.
///
/// iOS gives no "screen turned on" event, and WidgetKit budgets how often a
/// widget may *rebuild* its timeline — roughly a few dozen times a day. What it
/// does not budget is how many entries one timeline contains. So instead of
/// asking to be woken every five minutes, this provider hands the system a full
/// day of pre-computed entries at once: the word on the lock screen changes on
/// every slot boundary, at no refresh cost.
///
/// The entries are pure functions of `Schedule`, so no state has to survive
/// between refreshes.
struct WordProvider: TimelineProvider {
    /// Hard cap on entries per timeline. Well inside the widget extension's
    /// memory budget while covering a full day at the 5-minute default. At the
    /// 2-minute setting the cap shortens coverage to about ten hours; the
    /// timeline then ends and the `.after` policy asks for a rebuild — two or
    /// three extra refreshes a day, far inside the WidgetKit budget.
    static let maxEntries = 288
    /// Never plan further ahead than this; the app rebuilds long before it.
    static let maxHorizon: TimeInterval = 24 * 60 * 60

    private let store = SharedStore.shared
    private let database = WordDatabase.shared

    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: Date(), word: .placeholder, hideTranslation: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordTimelineEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordTimelineEntry>) -> Void) {
        let schedule = store.schedule
        let settings = store.settings

        guard !schedule.queue.isEmpty else {
            // The app has not run yet, so there is no rotation. Show a single
            // entry and ask for a refresh shortly — opening the app fixes it.
            let single = entry(at: Date())
            completion(Timeline(entries: [single], policy: .after(Date().addingTimeInterval(15 * 60))))
            return
        }

        let now = Date()
        let slot = schedule.slotDuration
        let firstIndex = schedule.slotIndex(for: now)

        // How many slots fit in the horizon, capped by the entry limit. A
        // short queue still needs an entry per slot — it wraps, so the word
        // keeps changing on every boundary even while the cycle repeats.
        let slotsInHorizon = slot > 0 ? Int(Self.maxHorizon / slot) : Self.maxEntries
        let count = max(1, min(Self.maxEntries, slotsInHorizon))

        var entries: [WordTimelineEntry] = []
        entries.reserveCapacity(count)

        for offset in 0..<count {
            let index = firstIndex + offset
            let date = schedule.slotStart(index)
            guard let id = schedule.wordID(atSlot: index),
                  let word = database.word(id: id) else { continue }
            // The first entry must not be in the future or the widget shows
            // stale content until the next boundary.
            let entryDate = offset == 0 ? min(date, now) : date
            entries.append(
                WordTimelineEntry(
                    date: entryDate,
                    word: word,
                    hideTranslation: settings.hideTranslationOnLockScreen
                )
            )
        }

        guard let last = entries.last else {
            completion(Timeline(entries: [entry(at: now)], policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }

        completion(Timeline(entries: entries, policy: .after(last.date)))
    }

    private func entry(at date: Date) -> WordTimelineEntry {
        let settings = store.settings
        let word = store.schedule.word(at: date, in: database)
            ?? database.words(levels: settings.levels).first
            ?? .placeholder
        return WordTimelineEntry(
            date: date,
            word: word,
            hideTranslation: settings.hideTranslationOnLockScreen
        )
    }
}
