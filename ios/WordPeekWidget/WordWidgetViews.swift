import WidgetKit
import SwiftUI

/// Lock screen widgets are rendered monochrome and vibrant: colour is stripped,
/// so hierarchy has to come from weight, size and opacity alone.
struct WordWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordTimelineEntry

    var body: some View {
        content
            .widgetURL(URL(string: "wordpeek://word/\(entry.word.id)"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // One line, no styling control: pack the pair in and let the system
            // truncate.
            Text("\(entry.word.word) — \(entry.hideTranslation ? entry.word.pos : entry.word.ru)")

        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.word.level.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
                Text(entry.word.word)
                    .font(.system(size: 13, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            .padding(2)

        case .accessoryRectangular:
            rectangular

        case .systemLarge:
            largeCard

        default:
            homeScreen
        }
    }

    /// The main lock screen layout — this is the one that sits under the clock.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.word.word)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if entry.hideTranslation {
                Text(entry.word.defEn)
                    .font(.caption2)
                    .lineLimit(2)
                    .opacity(0.9)
            } else {
                Text(entry.word.ru)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.word.defEn)
                    .font(.caption2)
                    .lineLimit(1)
                    .opacity(0.75)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// The full card, mirroring `WordCardView` in the app: everything the
    /// smaller families have to leave out. No speaker button — widgets
    /// cannot play audio; the tap opens the card in the app instead.
    private var largeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.word.level.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.tint.opacity(0.15)))
                    .foregroundStyle(.tint)
                Text(entry.word.pos)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(entry.word.word)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(entry.word.ipa)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(entry.word.ru)
                .font(.body.weight(.medium))
                .lineLimit(2)

            Divider()

            Text(entry.word.defEn)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.word.example)
                    .font(.footnote.italic())
                    .lineLimit(2)
                Text(entry.word.exampleRu)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Label {
                Text(entry.word.noteRu)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } icon: {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.word.level.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.tint.opacity(0.15)))
                Spacer()
                Text(entry.word.pos)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.word.word)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(entry.word.ipa)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(entry.word.ru)
                .font(.callout)
                .lineLimit(2)

            if family == .systemMedium {
                Text(entry.word.example)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WordPeekWidget: Widget {
    let kind = "WordPeekWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            if #available(iOS 17.0, *) {
                WordWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WordWidgetEntryView(entry: entry)
                    .padding()
            }
        }
        .configurationDisplayName("Слово дня")
        .description("Новое слово с переводом при каждом взгляде на экран.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

@main
struct WordPeekWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordPeekWidget()
    }
}
