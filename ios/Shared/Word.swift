import Foundation

/// One example sentence with its Russian translation.
struct ExamplePair: Codable, Hashable {
    let en: String
    let ru: String
}

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
    /// 1–2 more examples beyond the primary one. Kept separate from
    /// `example`/`example_ru` so the widget and the web prototype keep
    /// reading the primary pair unchanged.
    let extraExamples: [ExamplePair]
    let topic: String

    enum CodingKeys: String, CodingKey {
        case id, word, ipa, pos, level, ru, topic
        case defEn = "def_en"
        case noteRu = "note_ru"
        case example
        case exampleRu = "example_ru"
        case extraExamples = "examples_extra"
    }
}

extension Word {
    /// Custom decoding lives in an extension to keep the memberwise
    /// initialiser. `examples_extra` is optional in the JSON: a dictionary
    /// entry without it decodes with an empty list instead of failing the
    /// whole bundle load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        word = try c.decode(String.self, forKey: .word)
        ipa = try c.decode(String.self, forKey: .ipa)
        pos = try c.decode(String.self, forKey: .pos)
        level = try c.decode(Level.self, forKey: .level)
        ru = try c.decode(String.self, forKey: .ru)
        defEn = try c.decode(String.self, forKey: .defEn)
        noteRu = try c.decode(String.self, forKey: .noteRu)
        example = try c.decode(String.self, forKey: .example)
        exampleRu = try c.decode(String.self, forKey: .exampleRu)
        extraExamples = try c.decodeIfPresent([ExamplePair].self, forKey: .extraExamples) ?? []
        topic = try c.decode(String.self, forKey: .topic)
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
        extraExamples: [],
        topic: "core"
    )
}
