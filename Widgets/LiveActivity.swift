import WidgetKit
import SwiftUI
import ActivityKit
import MemoryCore

/// Today's trail on the Lock Screen and in the Dynamic Island, with a live countdown while a
/// study timer runs (it keeps ticking after you leave the app — no updates needed).
struct QuestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestActivityAttributes.self) { context in
            let theme = Self.theme(context.attributes)
            LockScreenActivityView(state: context.state, theme: theme, mascotName: context.attributes.mascotName)
                .padding(16)
                .activityBackgroundTint(theme.background)
                .activitySystemActionForegroundColor(theme.text)
                .widgetURL(WidgetLinks.quest)
        } dynamicIsland: { context in
            let theme = Self.theme(context.attributes)
            // The island is always black: use light, high-contrast colours there in both looks.
            let island = Theme.midnightRaccoon
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelSpriteView(art: state.complete ? theme.mascotHappy : theme.mascotIdle)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = state.countdownEnd {
                        Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(island.primary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                    } else {
                        ActivityRing(done: state.done, total: state.total, theme: island, size: 40)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.countdownLabel ?? state.headline)
                        .font(.headline).foregroundStyle(.white).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        StoneRow(steps: state.steps, theme: island, size: 9)
                        if let next = state.nextTitle, state.countdownEnd == nil {
                            Link(destination: WidgetLinks.quest) {
                                Label("Next: \(next)", systemImage: state.nextSymbol ?? "play.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(island.primary.opacity(0.25)))
                            }
                        }
                    }
                }
            } compactLeading: {
                PixelSpriteView(art: state.complete ? theme.mascotHappy : theme.mascotIdle).frame(width: 22, height: 22)
            } compactTrailing: {
                if let end = state.countdownEnd {
                    Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(island.primary)
                        .frame(maxWidth: 44)
                } else {
                    ActivityRing(done: state.done, total: state.total, theme: island, size: 20)
                }
            } minimal: {
                ActivityRing(done: state.done, total: state.total, theme: island, size: 20)
            }
            .keylineTint(island.primary)
            .widgetURL(WidgetLinks.quest)
        }
    }

    static func theme(_ attributes: QuestActivityAttributes) -> Theme {
        Theme.forID(ThemeID(rawValue: attributes.themeRaw) ?? .midnightRaccoon)
    }
}

struct LockScreenActivityView: View {
    let state: QuestActivityAttributes.ContentState
    let theme: Theme
    let mascotName: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PixelSpriteView(art: state.complete ? theme.mascotHappy : theme.mascotIdle)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                if let end = state.countdownEnd {
                    Text(state.countdownLabel ?? "Study time").font(.subheadline.weight(.semibold)).foregroundStyle(theme.secondaryText)
                    Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                        .font(.system(size: 34, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.text)
                } else {
                    Text(state.headline).font(.headline).foregroundStyle(theme.text)
                    StoneRow(steps: state.steps, theme: theme, size: 10)
                    if let next = state.nextTitle {
                        Label(next, systemImage: state.nextSymbol ?? "play.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(theme.secondaryText).lineLimit(1)
                    } else if state.complete {
                        Text("\(mascotName) is proud of you.").font(.caption).foregroundStyle(theme.secondaryText)
                    }
                }
            }
            Spacer(minLength: 0)
            ActivityRing(done: state.done, total: state.total, theme: theme, size: 44)
        }
    }
}

struct ActivityRing: View {
    let done: Int
    let total: Int
    let theme: Theme
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(theme.primary.opacity(0.25), lineWidth: size / 9)
            Circle().trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
                .stroke(theme.primary, style: StrokeStyle(lineWidth: size / 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if size >= 30 {
                Text("\(done)/\(total)").font(.system(size: size * 0.28, weight: .bold)).foregroundStyle(theme.text)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(done) of \(total) steps done")
    }
}
