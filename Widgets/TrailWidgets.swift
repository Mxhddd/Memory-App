import WidgetKit
import SwiftUI
import MemoryCore

// MARK: Today's trail (Home Screen + StandBy)

struct TrailWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DenWidget", provider: SnapshotProvider()) { entry in
            TrailWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: entry.snapshot.theme) }
                .widgetURL(WidgetLinks.quest)
        }
        .configurationDisplayName("Today's trail")
        .description("Your room, today's steps and what's next. Tap to start.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TrailWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        let s = entry.snapshot
        let theme = s.theme
        switch family {
        case .systemLarge: large(s, theme)
        case .systemMedium: medium(s, theme)
        default: small(s, theme)
        }
    }

    // Small, also used in StandBy (no container background there: big and legible at night).
    private func small(_ s: WidgetSnapshot, _ theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                PixelSpriteView(art: s.questComplete ? theme.mascotHappy : theme.mascotIdle)
                    .frame(width: showsBackground ? 50 : 64, height: showsBackground ? 50 : 64)
                Spacer()
                progressRing(s, theme, size: 36)
            }
            Spacer(minLength: 0)
            Text(s.questComplete ? "Trained today" : (s.nextStep?.title ?? theme.copy.questTitle))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            StoneRow(steps: s.steps.map(\.done), theme: theme, size: 8)
            footer(s, theme)
        }
    }

    private func medium(_ s: WidgetSnapshot, _ theme: Theme) -> some View {
        HStack(spacing: 12) {
            WidgetRoom(theme: theme, stage: s.growthStage, happy: s.questComplete)
                .clipShape(theme.shape(step: 6, radius: 16))
                .widgetAccentable(false)
            VStack(alignment: .leading, spacing: 6) {
                Text(s.questComplete ? "Trained today" : theme.copy.questTitle)
                    .font(.headline).foregroundStyle(theme.text).lineLimit(1)
                StoneRow(steps: s.steps.map(\.done), theme: theme, size: 9)
                if let next = s.nextStep, !s.questComplete {
                    Label(next.title, systemImage: next.symbol)
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.text).lineLimit(2)
                }
                Spacer(minLength: 0)
                footer(s, theme)
            }
        }
    }

    private func large(_ s: WidgetSnapshot, _ theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetRoom(theme: theme, stage: s.growthStage, happy: s.questComplete)
                .clipShape(theme.shape(step: 8, radius: 18))
                .widgetAccentable(false)
            HStack {
                Text(s.questComplete ? "Trained today" : theme.copy.questTitle).font(.headline).foregroundStyle(theme.text)
                Spacer()
                Text("Day \(s.courseDay) of 42").font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
            }
            ForEach(Array(s.steps.prefix(5).enumerated()), id: \.offset) { _, step in
                HStack(spacing: 8) {
                    Image(systemName: step.done ? "checkmark.circle.fill" : step.symbol)
                        .foregroundStyle(step.done ? theme.success : theme.primary)
                        .frame(width: 20)
                    Text(step.title).font(.caption.weight(.semibold))
                        .foregroundStyle(step.done ? theme.secondaryText : theme.text)
                        .strikethrough(step.done, color: theme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            footer(s, theme)
        }
    }

    private func progressRing(_ s: WidgetSnapshot, _ theme: Theme, size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(theme.raised, lineWidth: 4)
            Circle().trim(from: 0, to: s.questTotal == 0 ? 0 : CGFloat(s.questDone) / CGFloat(s.questTotal))
                .stroke(theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(s.questDone)/\(s.questTotal)").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(theme.text)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(s.questDone) of \(s.questTotal) steps done")
    }

    @ViewBuilder private func footer(_ s: WidgetSnapshot, _ theme: Theme) -> some View {
        if let days = s.refreshSoon {
            Label(days == 0 ? "Refresh in SideStore today" : "Refresh in SideStore · \(days)d", systemImage: "arrow.clockwise")
                .font(.caption2.weight(.bold)).foregroundStyle(theme.danger).lineLimit(1)
        } else if let text = s.nextIntentionText, let time = s.nextIntentionTime {
            Label { Text("\(text) · \(time, style: .time)").lineLimit(1) } icon: { Image(systemName: "bell.fill") }
                .font(.caption2.weight(.semibold)).foregroundStyle(theme.secondaryText)
        } else if s.dueCards > 0 {
            Label("\(s.dueCards) cards ready", systemImage: "rectangle.stack.fill")
                .font(.caption2.weight(.semibold)).foregroundStyle(theme.secondaryText)
        } else {
            Label("\(s.shinies) \(theme.copy.shinyName)", systemImage: "sparkles")
                .font(.caption2.weight(.semibold)).foregroundStyle(theme.ornament)
        }
    }
}

// MARK: Lock Screen

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreenWidget", provider: SnapshotProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(WidgetLinks.quest)
        }
        .configurationDisplayName("Training & reminders")
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
            .widgetAccentable()
        case .accessoryInline:
            if let text = s.nextIntentionText, let time = s.nextIntentionTime {
                Text("\(Image(systemName: "bell.fill")) \(text) \(time, style: .time)")
            } else {
                Text(s.questComplete ? "\(Image(systemName: "sparkles")) Trained today" : "\(Image(systemName: "moon.stars.fill")) Training \(s.questDone)/\(s.questTotal)")
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(s.questComplete ? "Trained today" : "Training \(s.questDone)/\(s.questTotal)")
                    .font(.headline).widgetAccentable()
                if let next = s.nextStep, !s.questComplete {
                    Text(next.title).font(.caption).lineLimit(1)
                } else if let text = s.nextIntentionText, let time = s.nextIntentionTime {
                    Text("\(text) · \(time, style: .time)").font(.caption).lineLimit(1)
                }
                if let days = s.refreshSoon {
                    Text("Refresh in SideStore · \(days)d").font(.caption2.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
