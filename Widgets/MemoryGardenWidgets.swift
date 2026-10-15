import WidgetKit
import SwiftUI
import AppIntents
#if canImport(ActivityKit)
import ActivityKit
#endif
import MemoryCore

// The ONE app extension (free-account SideStore limit): widgets + Live Activity live here.

@main
struct MemoryGardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        DenWidget()
        LockScreenWidget()
        QuestLiveActivity()
    }
}

// MARK: Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads timelines whenever something changes; refresh hourly as a fallback,
        // and right after midnight so yesterday's progress doesn't linger.
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        let next = min(now.addingTimeInterval(3600), midnight.addingTimeInterval(60))
        var e = entry()
        if !Calendar.current.isDate(e.snapshot.updatedAt, inSameDayAs: now) {
            e = SnapshotEntry(date: now, snapshot: dayRolledOver(e.snapshot), isPlaceholder: e.isPlaceholder)
        }
        completion(Timeline(entries: [e], policy: .after(next)))
    }

    private func entry() -> SnapshotEntry {
        if let s = SharedStore.readSnapshot() { return SnapshotEntry(date: Date(), snapshot: s, isPlaceholder: false) }
        return SnapshotEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    private func dayRolledOver(_ s: WidgetSnapshot) -> WidgetSnapshot {
        var copy = s
        copy.questDone = 0
        copy.questComplete = false
        copy.lapsesToday = 0
        return copy
    }
}

private extension WidgetSnapshot {
    var theme: Theme { Theme.forID(ThemeID(rawValue: themeRaw) ?? .midnightRaccoon) }
}

// MARK: Home Screen

struct DenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DenWidget", provider: SnapshotProvider()) { entry in
            DenWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [entry.snapshot.theme.backgroundTop, entry.snapshot.theme.background],
                                   startPoint: .top, endPoint: .bottom)
                }
                .widgetURL(URL(string: "memorygarden://quest"))
        }
        .configurationDisplayName("The Den")
        .description("Your companion, today's quest and your next reminder.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DenWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        let theme = s.theme
        let art = s.questComplete ? theme.mascotHappy : theme.mascotIdle
        switch family {
        case .systemMedium:
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    PixelSpriteView(art: art).frame(width: 70, height: 70)
                    Text(s.mascotName).font(.caption.weight(.semibold)).foregroundStyle(theme.text)
                }
                VStack(alignment: .leading, spacing: 6) {
                    questLine(s, theme)
                    if let text = s.nextIntentionText, let time = s.nextIntentionTime {
                        Label { Text("\(text) · \(time, style: .time)").lineLimit(1) } icon: { Image(systemName: "bell.fill") }
                            .font(.caption).foregroundStyle(theme.text)
                    }
                    if s.dueCards > 0 {
                        Label("\(s.dueCards) cards ready", systemImage: "rectangle.stack.fill").font(.caption).foregroundStyle(theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    lapseButton(theme)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PixelSpriteView(art: art).frame(width: 52, height: 52)
                    Spacer()
                    Label("\(s.shinies)", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
                }
                questLine(s, theme)
                Spacer(minLength: 0)
                lapseButton(theme)
            }
        }
    }

    private func questLine(_ s: WidgetSnapshot, _ theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.questComplete ? "Quest done ✨" : theme.copy.questTitle)
                .font(.subheadline.weight(.bold)).foregroundStyle(theme.text).lineLimit(1)
            ProgressView(value: Double(s.questDone), total: Double(max(s.questTotal, 1)))
                .tint(theme.primary)
        }
    }

    private func lapseButton(_ theme: Theme) -> some View {
        Button(intent: LogLapseIntent()) {
            Label("I forgot something", systemImage: "exclamationmark.bubble.fill")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .tint(theme.accent)
        .foregroundStyle(theme.onPrimary)
    }
}

// MARK: Lock Screen

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreenWidget", provider: SnapshotProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "memorygarden://quest"))
        }
        .configurationDisplayName("Quest & reminders")
        .description("Today's progress or your next reminder, at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(s.questDone), in: 0...Double(max(s.questTotal, 1))) {
                Image(systemName: s.questComplete ? "sparkles" : "moon.stars.fill")
            } currentValueLabel: {
                Text("\(s.questDone)/\(s.questTotal)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            if let text = s.nextIntentionText, let time = s.nextIntentionTime {
                Text("🔔 \(text) \(time, style: .time)")
            } else {
                Text(s.questComplete ? "✨ Quest done" : "🌙 Quest \(s.questDone)/\(s.questTotal)")
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(s.questComplete ? "Quest done ✨" : "Quest \(s.questDone)/\(s.questTotal)").font(.headline)
                if let text = s.nextIntentionText, let time = s.nextIntentionTime {
                    Text("\(text) · \(time, style: .time)").font(.caption).lineLimit(1)
                } else if s.dueCards > 0 {
                    Text("\(s.dueCards) cards ready").font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Live Activity

struct QuestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestActivityAttributes.self) { context in
            let theme = Theme.forID(ThemeID(rawValue: context.attributes.themeRaw) ?? .midnightRaccoon)
            HStack(spacing: 12) {
                PixelSpriteView(art: context.state.done == context.state.total ? theme.mascotHappy : theme.mascotIdle)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.state.headline).font(.headline).foregroundStyle(theme.text)
                    ProgressView(value: Double(context.state.done), total: Double(max(context.state.total, 1))).tint(theme.primary)
                }
                Text("\(context.state.done)/\(context.state.total)").font(.title3.monospacedDigit().weight(.bold)).foregroundStyle(theme.text)
            }
            .padding(16)
            .activityBackgroundTint(theme.background)
            .activitySystemActionForegroundColor(theme.text)
            .widgetURL(URL(string: "memorygarden://quest"))
        } dynamicIsland: { context in
            let theme = Theme.forID(ThemeID(rawValue: context.attributes.themeRaw) ?? .midnightRaccoon)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelSpriteView(art: theme.mascotIdle).frame(width: 40, height: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.done)/\(context.state.total)").font(.title3.weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline).font(.subheadline)
                }
            } compactLeading: {
                PixelSpriteView(art: theme.mascotIdle).frame(width: 22, height: 22)
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)").font(.caption.weight(.bold))
            } minimal: {
                Text("\(context.state.done)").font(.caption.weight(.bold))
            }
            .widgetURL(URL(string: "memorygarden://quest"))
        }
    }
}
