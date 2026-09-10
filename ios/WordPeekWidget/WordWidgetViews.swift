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
            .systemMedium
        ])
    }
}

@main
struct WordPeekWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordPeekWidget()
    }
}
