import SwiftUI

/// The whole library, browsable by level and searchable by headword or
/// translation. Tapping a row opens the full card via the shared
/// `pinnedWord` sheet.
struct DictionaryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private let database = WordDatabase.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Word] {
        database.search(trimmedQuery)
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    ForEach(Level.allCases, id: \.self) { level in
                        Section {
                            ForEach(database.words.filter { $0.level == level }) { word in
                                row(word)
                            }
                        } header: {
                            Text("\(level.title) · \(level.subtitle)")
                        }
                    }
                } else {
                    ForEach(results) { word in
                        row(word)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Слово или перевод")
            .navigationTitle("Словарь")
            .overlay {
                if !trimmedQuery.isEmpty, results.isEmpty {
                    EmptyState(
                        title: "Ничего не нашлось",
                        systemImage: "magnifyingglass",
                        description: "Попробуй другое слово или его перевод."
                    )
                }
            }
        }
    }

    private func row(_ word: Word) -> some View {
        Button {
            model.pinnedWord = word
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.word).font(.body.weight(.medium))
                    Text(word.ru)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(word.level.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}
