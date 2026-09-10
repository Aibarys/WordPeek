import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Сейчас", systemImage: "sparkles") }
            HistoryView()
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .sheet(item: $model.pinnedWord) { word in
            NavigationStack {
                ScrollView {
                    WordCardView(word: word)
                        .padding()
                }
                .navigationTitle("Карточка")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { model.pinnedWord = nil }
                    }
                }
            }
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !model.isAppGroupConfigured {
                        AppGroupWarning()
                    }

                    if let word = model.currentWord {
                        WordCardView(word: word)
                        AnswerButtons(word: word)
                    } else {
                        ContentUnavailableView(
                            "Словарь пуст",
                            systemImage: "book.closed",
                            description: Text("Выбери хотя бы один уровень в настройках.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Сейчас")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("слот \(model.currentSlot)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AnswerButtons: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    model.answer(.learning, for: word)
                } label: {
                    Label("Учить", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    model.answer(.known, for: word)
                } label: {
                    Label("Знаю", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Text(boxDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var boxDescription: String {
        switch model.progress(for: word).box {
        case 0: return "Новое слово — будет появляться часто"
        case 1: return "На повторении — появляется регулярно"
        case 2: return "Почти выучено — появляется редко"
        default: return "Выучено — убрано из ротации"
        }
    }
}

private struct AppGroupWarning: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Group не настроена").font(.subheadline.weight(.semibold))
                Text("Приложение работает, но виджет не увидит твой прогресс. Включи capability App Groups на обоих таргетах — см. README.")
                    .font(.caption)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.yellow.opacity(0.15)))
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            List(model.recentWords(), id: \.slot) { item in
                Button {
                    model.pinnedWord = item.word
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.word.word).font(.body.weight(.medium))
                            Text(item.word.ru)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(Self.formatter.string(from: item.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("История")
            .overlay {
                if model.recentWords().isEmpty {
                    ContentUnavailableView("Пока пусто", systemImage: "clock")
                }
            }
        }
    }
}
