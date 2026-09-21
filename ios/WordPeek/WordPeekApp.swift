import SwiftUI

@main
struct WordPeekApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onOpenURL { url in model.handle(url: url) }
        }
    }
}

/// Owns the state the UI observes and forwards every change to `SharedStore`,
/// which is what the widget reads.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var currentWord: Word?
    @Published private(set) var currentSlot: Int = 0
    /// Set when the user taps the widget; overrides the clock until dismissed.
    @Published var pinnedWord: Word?
    @Published var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            store.settings = settings
            store.rebuildSchedule(preservingAnchor: settings.slotMinutes == oldValue.slotMinutes)
            refresh()
        }
    }

    private let store = SharedStore.shared
    private let database = WordDatabase.shared
    private var timer: Timer?

    var isAppGroupConfigured: Bool { store.isAppGroupConfigured }
    var wordCount: Int { database.words(levels: settings.levels).count }

    init() {
        self.settings = SharedStore.shared.settings
        ensureSchedule()
        refresh()
        startTimer()
    }

    deinit { timer?.invalidate() }

    /// Builds a rotation on first launch, or after a settings change made the
    /// existing one invalid.
    private func ensureSchedule() {
        let schedule = store.schedule
        if schedule.queue.isEmpty || schedule.slotMinutes != settings.slotMinutes {
            store.rebuildSchedule(preservingAnchor: false)
        }
    }

    func refresh() {
        let now = Date()
        store.materializeHistory(now: now)
        let schedule = store.schedule
        currentSlot = schedule.slotIndex(for: now)
        currentWord = schedule.word(at: now, in: database)
    }

    /// Ticks often enough that the card in the app never lags the lock screen
    /// by more than a few seconds.
    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Answers

    func progress(for word: Word) -> WordProgress { store.progress(for: word.id) }

    func answer(_ answer: SharedStore.Answer, for word: Word) {
        store.record(answer, for: word.id, database: database)
        refresh()
        objectWillChange.send()
    }

    func resetProgress() {
        store.resetProgress(database: database)
        refresh()
    }

    // MARK: - History

    /// What was actually shown, most recent first — read from the persisted
    /// journal, so answers appear immediately and rebuilds never rewrite it.
    func recentWords(count: Int = 40) -> [(entry: SharedStore.HistoryEntry, word: Word)] {
        store.materializeHistory()
        return store.history.suffix(count).reversed().compactMap { entry in
            database.word(id: entry.wordID).map { (entry: entry, word: $0) }
        }
    }

    // MARK: - Deep links

    /// `wordpeek://word/<id>` — sent by a widget tap. The card sheet only
    /// opens when the tapped word is NOT the one already on screen (e.g. the
    /// slot changed between the glance and the unlock) — otherwise the sheet
    /// would just duplicate the card underneath it.
    func handle(url: URL) {
        guard url.scheme == "wordpeek", url.host == "word" else { return }
        let id = url.lastPathComponent
        guard let word = database.word(id: id) else { return }
        refresh()
        guard word.id != currentWord?.id else { return }
        pinnedWord = word
    }
}
