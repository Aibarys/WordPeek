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
}

final class ScheduleBuilderTests: XCTestCase {
    private func word(_ id: String, level: Level = .b1) -> Word {
        Word(id: id, word: id, ipa: "/x/", pos: "noun", level: level,
             ru: "перевод", defEn: "definition", noteRu: "заметка",
             example: "Example.", exampleRu: "Пример.", topic: "core")
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

    func testQueueIsCapped() {
        let pool = (0..<500).map { word("w\($0)") }
        let queue = ScheduleBuilder.buildQueue(from: pool, progress: [:], seed: 3)
        XCTAssertLessThanOrEqual(queue.count, ScheduleBuilder.maxQueueLength)
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
        }
    }

    func testLevelFilterFallsBackRatherThanReturningNothing() {
        let database = WordDatabase(words: [
            Word(id: "x", word: "x", ipa: "/x/", pos: "noun", level: .c1,
                 ru: "перевод", defEn: "definition", noteRu: "заметка",
                 example: "Example.", exampleRu: "Пример.", topic: "core")
        ])
        XCTAssertEqual(database.words(levels: [.a2]).count, 1)
    }
}
