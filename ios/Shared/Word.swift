import Foundation

/// One vocabulary entry, decoded straight from `words.json`.
struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let ipa: String
    let pos: String
    let level: Level
    /// Russian translation.
    let ru: String
    /// Short English definition — the "explanation in the language itself".
    let defEn: String
    /// Russian usage note: false friends, collocations, pronunciation traps.
    let noteRu: String
    let example: String
    let exampleRu: String
    let topic: String

    enum CodingKeys: String, CodingKey {
        case id, word, ipa, pos, level, ru, topic
        case defEn = "def_en"
        case noteRu = "note_ru"
        case example
        case exampleRu = "example_ru"
    }
}

enum Level: String, Codable, CaseIterable, Hashable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .a2: return "Базовый"
        case .b1: return "Средний"
        case .b2: return "Выше среднего"
        case .c1: return "Продвинутый"
        }
    }
}

/// The bundled dictionary. Both the app and the widget extension load it.
struct WordDatabase {
    let words: [Word]
    private let index: [String: Word]

    static let shared = WordDatabase.loadFromBundle()

    init(words: [Word]) {
        self.words = words
        self.index = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func word(id: String) -> Word? { index[id] }

    func words(levels: Set<Level>) -> [Word] {
        let filtered = words.filter { levels.contains($0.level) }
        return filtered.isEmpty ? words : filtered
    }

    /// Never fails at runtime: a missing or corrupt bundle resource yields a
    /// single placeholder entry rather than a crash inside a widget refresh,
    /// where a crash would silently blank the lock screen.
    private static func loadFromBundle() -> WordDatabase {
        struct Payload: Codable { let words: [Word] }
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.words.isEmpty
        else {
            return WordDatabase(words: [.placeholder])
        }
        return WordDatabase(words: payload.words)
    }
}

extension Word {
    static let placeholder = Word(
        id: "placeholder",
        word: "serendipity",
        ipa: "/ˌserənˈdɪpəti/",
        pos: "noun",
        level: .c1,
        ru: "счастливая случайность",
        defEn: "the luck of finding something good without looking for it",
        noteRu: "Словарь не загрузился — это запасная карточка.",
        example: "Finding that café was pure serendipity.",
        exampleRu: "То, что мы нашли это кафе, — чистая счастливая случайность.",
        topic: "core"
    )
}
