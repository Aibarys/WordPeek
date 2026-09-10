import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Level.allCases, id: \.self) { level in
                        Toggle(isOn: binding(for: level)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title)
                                Text(level.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Уровни")
                } footer: {
                    Text("В ротации сейчас \(model.wordCount) слов.")
                }

                Section {
                    Picker("Менять слово каждые", selection: $model.settings.slotMinutes) {
                        ForEach(Settings.slotOptions, id: \.self) { minutes in
                            Text(label(forMinutes: minutes)).tag(minutes)
                        }
                    }
                    Toggle("Скрывать перевод на локскрине", isOn: $model.settings.hideTranslationOnLockScreen)
                } header: {
                    Text("Показ")
                } footer: {
                    Text("Со скрытым переводом на экране блокировки видно слово и английское определение — перевод открывается по тапу.")
                }

                Section {
                    Button("Сбросить прогресс", role: .destructive) {
                        showResetConfirmation = true
                    }
                } footer: {
                    Text("Все слова снова станут новыми.")
                }
            }
            .navigationTitle("Настройки")
            .confirmationDialog(
                "Сбросить весь прогресс?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Сбросить", role: .destructive) { model.resetProgress() }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    /// Toggling the last enabled level off would empty the rotation, so the
    /// final one stays locked on.
    private func binding(for level: Level) -> Binding<Bool> {
        Binding(
            get: { model.settings.levels.contains(level) },
            set: { isOn in
                var levels = model.settings.levels
                if isOn {
                    levels.insert(level)
                } else {
                    guard levels.count > 1 else { return }
                    levels.remove(level)
                }
                model.settings.levels = levels
            }
        )
    }

    private func label(forMinutes minutes: Int) -> String {
        minutes < 60 ? "\(minutes) мин" : "1 час"
    }
}
