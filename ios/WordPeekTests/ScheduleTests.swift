import XCTest
@testable import WordPeek

final class ScheduleTests: XCTestCase {
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSchedule(slotMinutes: Int = 5, queue: [String]) -> Schedule {
        Schedule(anchor: anchor, slotMinutes: slotMinutes, queue: queue)
    }

    func testSlotIndexAdvancesOnBoundaries() {
        let schedule = makeSchedule(queue: ["a", "b", "c"])
        XCTAssertEqual(schedule.slotIndex(for: anchor), 0)
        XCTAssertEqual(schedule.slotIndex(for: anchor.addingTimeInterval(299)), 0)
        XCTAssertEqual(schedule.slotIndex(for: anchor.addingTimeInterval(300)), 1)
        XCTAssertEqual(schedule.slotIndex(for: anchor.addingTimeInterval(3600)), 12)
    }

    func testSlotIndexClampsBeforeAnchor() {
        let schedule = makeSchedule(queue: ["a"])
        XCTAssertEqual(schedule.slotIndex(for: anchor.addingTimeInterval(-10_000)), 0)
    }

    func testQueueWrapsAround() {
        let schedule = makeSchedule(queue: ["a", "b", "c"])
        XCTAssertEqual(schedule.wordID(atSlot: 0), "a")
        XCTAssertEqual(schedule.wordID(atSlot: 3), "a")
        XCTAssertEqual(schedule.wordID(atSlot: 7), "b")
    }

    func testEmptyQueueYieldsNoWord() {
        XCTAssertNil(makeSchedule(queue: []).wordID(atSlot: 4))
    }

    func testSlotStartIsInverseOfSlotIndex() {
        let schedule = makeSchedule(slotMinutes: 15, queue: ["a"])
        for index in [0, 1, 9, 137] {
            XCTAssertEqual(schedule.slotIndex(for: schedule.slotStart(index)), index)
        }
    }

    func testStartSlotShiftsTheQueue() {
        let schedule = Schedule(anchor: anchor, slotMinutes: 5, queue: ["a", "b", "c"], startSlot: 10)
        XCTAssertEqual(schedule.wordID(atSlot: 10), "a")
        XCTAssertEqual(schedule.wordID(atSlot: 12), "c")
        XCTAssertEqual(schedule.wordID(atSlot: 13), "a")
        // Slots before the start are clamped to the queue head.
        XCTAssertEqual(schedule.wordID(atSlot: 4), "a")
    }

    func testDecodingScheduleWithoutStartSlotDefaultsToZero() throws {
        // A schedule persisted by 1.0 — no startSlot key.
        let stored = try JSONEncoder().encode(
            Schedule(anchor: anchor, slotMinutes: 5, queue: ["a", "b"])
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [String: Any])
        json.removeValue(forKey: "startSlot")
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(Schedule.self, from: data)
        XCTAssertEqual(decoded.startSlot, 0)
        XCTAssertEqual(decoded.queue, ["a", "b"])
    }
}

final class ScheduleBuilderTests: XCTestCase {
    private func word(_ id: String, level: Level = .b1) -> Word {
        Word(id: id, word: id, ipa: "/x/", pos: "noun", level: level,
             ru: "перевод", defEn: "definition", noteRu: "заметка",
             example: "Example.", exampleRu: "Пример.", extraExamples: [],
             topic: "core")
    }

    func testNewWordsAppearMoreOftenThanAlmostLearnedOnes() {
        let pool = [word("new"), word("old")]
        let progress = ["old": WordProgress(box: 2, lastSeen: nil)]
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: progress, seed: 1)

        let newCount = queue.filter { $0 == "new" }.count
        let oldCount = queue.filter { $0 == "old" }.count
        XCTAssertGreaterThan(newCount, oldCount)
    }

    func testLearnedWordsLeaveTheRotation() {
        let pool = [word("a"), word("b")]
        let progress = ["b": WordProgress(box: 3, lastSeen: nil)]
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: progress, seed: 1)
        XCTAssertFalse(queue.contains("b"))
        XCTAssertTrue(queue.contains("a"))
    }

    func testFullyLearnedDeckStillProducesAReviewQueue() {
        let pool = [word("a"), word("b")]
        let progress = [
            "a": WordProgress(box: 3, lastSeen: nil),
            "b": WordProgress(box: 3, lastSeen: nil)
        ]
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: progress, seed: 1)
        XCTAssertEqual(Set(queue), ["a", "b"])
    }

    func testSameSeedProducesSameQueue() {
        let pool = (0..<20).map { word("w\($0)") }
        let first = ScheduleBuilder.buildQueue(from: pool, progress: [:], seed: 42)
        let second = ScheduleBuilder.buildQueue(from: pool, progress: [:], seed: 42)
        XCTAssertEqual(first, second)
    }

    func testDuplicatesAreSpacedApart() {
        let pool = (0..<12).map { word("w\($0)") }
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: [:], seed: 7)
        for (offset, id) in queue.enumerated() {
            let window = queue[queue.index(after: offset)..<min(offset + 4, queue.count)]
            XCTAssertFalse(window.contains(id), "\(id) repeats within 3 slots at index \(offset)")
        }
    }

    func testTailPendingIsInterleavedWhenPossible() {
        // "a" keeps getting deferred and "b" joins it; a naive tail append
        // would emit "...a, a, b". The final drain must interleave what still
        // fits instead of dumping the held ids next to their twins.
        let spaced = ScheduleBuilder.spaceOutDuplicates(
            ["a", "b", "a", "a", "b", "c", "d"], minimumGap: 3
        )
        XCTAssertEqual(spaced.sorted(), ["a", "a", "a", "b", "b", "c", "d"], "no id may be dropped")
        for index in 1..<spaced.count {
            XCTAssertNotEqual(spaced[index], spaced[index - 1],
                              "adjacent duplicate at index \(index)")
        }
    }

    func testQueueIsCapped() {
        let pool = (0..<500).map { word("w\($0)") }
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: [:], seed: 3)
        XCTAssertLessThanOrEqual(queue.count, ScheduleBuilder.maxQueueLength)
    }

    func testRecentIdsAreKeptOutOfTheQueueHead() {
        let pool = (0..<12).map { word("w\($0)") }
        for seed in 0..<50 as Range<UInt64> {
            let queue = ScheduleBuilder.buildQueue(
                from: pool, progress: [:], seed: seed,
                avoidingRecent: ["w0", "w1", "w2"]
            )
            let head = queue.prefix(3)
            XCTAssertFalse(head.contains("w0"), "w0 at head for seed \(seed)")
            XCTAssertFalse(head.contains("w1"), "w1 at head for seed \(seed)")
            XCTAssertFalse(head.contains("w2"), "w2 at head for seed \(seed)")
            XCTAssertEqual(queue.count, 12 * 4, "eviction must not drop entries")
        }
    }
}

final class SharedStoreTests: XCTestCase {
    private var store: SharedStore!
    private var database: WordDatabase!

    override func setUp() {
        super.setUp()
        let suiteName = "wordpeek.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = SharedStore(defaults: defaults)
        database = WordDatabase(words: (0..<10).map { index in
            Word(id: "w\(index)", word: "w\(index)", ipa: "/x/", pos: "noun", level: .b1,
                 ru: "перевод", defEn: "definition", noteRu: "заметка",
                 example: "Example.", exampleRu: "Пример.", extraExamples: [],
                 topic: "core")
        })
    }

    func testAnswerAlwaysAdvancesToADifferentWord() {
        store.rebuildSchedule(database: database)
        let now = Date()
        for _ in 0..<20 {
            let before = store.schedule.word(at: now, in: database)!.id
            store.record(.learning, for: before, database: database, now: now)
            let after = store.schedule.word(at: now, in: database)!.id
            XCTAssertNotEqual(before, after, "the card must advance on every answer")
        }
    }

    func testAnswersAreJournaledInOrder() {
        store.rebuildSchedule(database: database)
        let now = Date()
        let first = store.schedule.word(at: now, in: database)!.id
        store.record(.known, for: first, database: database, now: now)
        let second = store.schedule.word(at: now, in: database)!.id

        let journal = store.history.map(\.wordID)
        XCTAssertTrue(journal.contains(first), "the answered word must stay in the history")
        XCTAssertEqual(journal.last, second, "the freshly shown word must be journaled")
    }

    func testJournalIsCapped() {
        store.rebuildSchedule(database: database)
        let now = Date()
        for _ in 0..<(SharedStore.historyLimit + 20) {
            let current = store.schedule.word(at: now, in: database)!.id
            store.record(.learning, for: current, database: database, now: now)
        }
        XCTAssertLessThanOrEqual(store.history.count, SharedStore.historyLimit)
    }
}

final class WordDatabaseTests: XCTestCase {
    func testBundledDatabaseLoads() {
        let database = WordDatabase.shared
        XCTAssertGreaterThan(database.words.count, 50, "words.json did not load from the bundle")
    }

    func testEveryBundledEntryIsComplete() {
        for word in WordDatabase.shared.words {
            XCTAssertFalse(word.word.isEmpty, "\(word.id) has no headword")
            XCTAssertFalse(word.ru.isEmpty, "\(word.id) has no translation")
            XCTAssertFalse(word.defEn.isEmpty, "\(word.id) has no definition")
            XCTAssertFalse(word.example.isEmpty, "\(word.id) has no example")
            XCTAssertFalse(word.extraExamples.isEmpty, "\(word.id) has no extra examples")
            XCTAssertLessThanOrEqual(word.extraExamples.count, 2, "\(word.id) has too many extra examples")
        }
    }

    func testLevelFilterFallsBackRatherThanReturningNothing() {
        let database = WordDatabase(words: [
            Word(id: "x", word: "x", ipa: "/x/", pos: "noun", level: .c1,
                 ru: "перевод", defEn: "definition", noteRu: "заметка",
                 example: "Example.", exampleRu: "Пример.", extraExamples: [],
                 topic: "core")
        ])
        XCTAssertEqual(database.words(levels: [.a2]).count, 1)
    }
}
