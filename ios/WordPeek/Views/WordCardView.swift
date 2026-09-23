import SwiftUI
import AVFoundation

/// The full card: everything the lock screen had to leave out.
struct WordCardView: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            translation
            explanation
            example
            note
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(word.level.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(Color.accentColor)
                Text(word.pos)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Speaker.shared.say(word.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Произнести слово")
            }

            Text(word.word)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(word.ipa)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var translation: some View {
        Text(word.ru)
            .font(.title3.weight(.medium))
    }

    private var explanation: some View {
        section("Что это значит", systemImage: "text.book.closed") {
            Text(word.defEn)
                .font(.body)
        }
    }

    private var example: some View {
        section(word.extraExamples.isEmpty ? "Пример" : "Примеры", systemImage: "quote.opening") {
            VStack(alignment: .leading, spacing: 14) {
                examplePair(word.example, word.exampleRu)
                ForEach(word.extraExamples, id: \.self) { pair in
                    examplePair(pair.en, pair.ru)
                }
            }
        }
    }

    private func examplePair(_ en: String, _ ru: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(en)
                .font(.body.italic())
            Text(ru)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var note: some View {
        section("Как не ошибиться", systemImage: "lightbulb") {
            Text(word.noteRu)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Reads the headword aloud. One shared synthesiser: creating a new one per tap
/// clips the start of short utterances on some devices.
///
/// The audio session uses the `.playback` category so the voice is heard
/// even with the ring/silent switch on silent — the user explicitly tapped
/// the speaker button, so sound is expected, like in any dictionary app.
/// Background music ducks while the word is spoken and recovers afterwards.
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private let synthesiser = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesiser.delegate = self
    }

    func say(_ text: String, language: String = "en-GB") {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.42
        synthesiser.stopSpeaking(at: .immediate)
        synthesiser.speak(utterance)
    }

    /// Releases the session once speech ends so ducked audio (music,
    /// podcasts) returns to full volume. Not done on cancel: a cancel only
    /// happens when a new utterance is about to start.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
