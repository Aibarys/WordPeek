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

    /// The words shown over the last `count` slots, most recent first.
    func recentWords(count: Int = 40) -> [(slot: Int, date: Date, word: Word)] {
        let schedule = store.schedule
        guard !schedule.queue.isEmpty else { return [] }
        let newest = schedule.slotIndex(for: Date())
        let oldest = max(0, newest - count + 1)
        return stride(from: newest, through: oldest, by: -1).compactMap { index in
            guard let id = schedule.wordID(atSlot: index),
                  let word = database.word(id: id) else { return nil }
            return (slot: index, date: schedule.slotStart(index), word: word)
        }
    }

    // MARK: - Deep links

    /// `wordpeek://word/<id>` — sent by a widget tap.
    func handle(url: URL) {
        guard url.scheme == "wordpeek", url.host == "word" else { return }
        let id = url.lastPathComponent
        guard let word = database.word(id: id) else { return }
        pinnedWord = word
    }
}
