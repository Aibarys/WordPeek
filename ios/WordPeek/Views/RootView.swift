import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            TodayView()
                .tabItem { Label("Сейчас", systemImage: "sparkles") }
                .tag(AppModel.Tab.today)
            DictionaryView()
                .tabItem { Label("Словарь", systemImage: "magnifyingglass") }
                .tag(AppModel.Tab.dictionary)
            HistoryView()
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
                .tag(AppModel.Tab.history)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(AppModel.Tab.settings)
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
    @State private var showWidgetHowTo = false

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
                        EmptyState(
                            title: "Словарь пуст",
                            systemImage: "book.closed",
                            description: "Выбери хотя бы один уровень в настройках."
                        )
                        .padding(.top, 60)
                    }

                    Button {
                        showWidgetHowTo = true
                    } label: {
                        Label("Как добавить виджет на экран блокировки", systemImage: "questionmark.circle")
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Сейчас")
            .sheet(isPresented: $showWidgetHowTo) {
                WidgetHowToView()
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("слот \(model.currentSlot)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            #endif
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

/// `ContentUnavailableView` needs iOS 17, and the deployment target is 16.1 —
/// lock screen widgets arrived in 16.1, so the app should run there too.
struct EmptyState: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
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
        let recent = model.recentWords()
        NavigationStack {
            List(recent, id: \.entry.id) { item in
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
                        Text(Self.formatter.string(from: item.entry.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("История")
            .overlay {
                if recent.isEmpty {
                    EmptyState(title: "Пока пусто", systemImage: "clock")
                }
            }
        }
    }
}
