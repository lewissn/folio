import WidgetKit
import SwiftUI
import ActivityKit

nonisolated struct ReadingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var elapsedSeconds: Int
        var startDate: Date
    }

    var bookTitle: String
    var authorName: String
}

struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .font(.system(.title3, design: .monospaced, weight: .light))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.bookTitle)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.attributes.authorName.isEmpty {
                        Text(context.attributes.authorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .font(.caption)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "book.fill")
                    .font(.caption2)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<ReadingActivityAttributes>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.78, green: 0.75, blue: 0.68))

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.bookTitle)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .lineLimit(1)

                if !context.attributes.authorName.isEmpty {
                    Text(context.attributes.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(context.state.startDate, style: .timer)
                .font(.system(.title3, design: .monospaced, weight: .light))
                .monospacedDigit()
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.96, green: 0.95, blue: 0.92))
    }
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entries = [SimpleEntry(date: .now)]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

nonisolated struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct ReadingRoomActivity: Widget {
    let kind: String = "ReadingRoomActivity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Text(entry.date, style: .time)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Reading Room")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
