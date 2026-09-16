import SwiftUI

/// Step-by-step guide to adding the lock screen widget. The whole point of
/// the app lives there, and nothing in iOS leads the user to it on its own —
/// this screen is the bridge, for the user and for App Review alike.
struct WidgetHowToView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id: Int
        let icon: String
        let text: String
    }

    private static let lockScreenSteps: [Step] = [
        Step(id: 1, icon: "lock.iphone",
             text: "Заблокируй iPhone, затем нажми и удерживай экран блокировки."),
        Step(id: 2, icon: "slider.horizontal.3",
             text: "Нажми «Настроить» и выбери экран блокировки."),
        Step(id: 3, icon: "rectangle.dashed",
             text: "Тапни область виджетов под часами."),
        Step(id: 4, icon: "plus.circle",
             text: "Найди WordPeek в списке и добавь виджет."),
        Step(id: 5, icon: "clock",
             text: "Готово. Слово будет меняться само — интервал настраивается на вкладке «Настройки».")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Self.lockScreenSteps) { step in
                        Label {
                            Text(step.text)
                        } icon: {
                            Image(systemName: step.icon)
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("На экран блокировки")
                } footer: {
                    Text("Виджет показывает слово при каждом взгляде на часы — это главный режим WordPeek.")
                }

                Section {
                    Label {
                        Text("Нажми и удерживай пустое место на домашнем экране, затем «+» в левом верхнем углу — и найди WordPeek.")
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Или на домашний экран")
                }
            }
            .navigationTitle("Как добавить виджет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
