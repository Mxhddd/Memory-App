import SwiftUI
import SwiftData
import MemoryCore

struct TodayView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @EnvironmentObject private var router: Router
    @Query(filter: #Predicate<Intention> { $0.active == true }, sort: \Intention.time) private var intentions: [Intention]

    @Environment(\.scenePhase) private var scenePhase
    @State private var steps: [QuestStep] = []
    @State private var stats = DayStats()
    @State private var shownDay = Calendar.current.startOfDay(for: Date())
    @State private var playing: GameContext?
    @State private var reviewing = false
    @State private var lesson: Lesson?
    @State private var celebrate = false
    /// Whether the day was already complete when the current step started (to celebrate once, after the sheet closes).
    @State private var wasDoneBefore = false

    /// Numbers that need database reads, computed once per refresh instead of on every render.
    struct DayStats {
        var active3 = 0
        var active28 = 0
        var weekDays = 0
        var streak = 0
        var planDay = 1
    }

    private var mood: MascotMood {
        if steps.allSatisfy(\.done) && !steps.isEmpty { return .happy }
        return stats.active3 == 0 && stats.active28 > 0 ? .sleepy : .idle
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(spacing: 22) {
                    greetingBlock
                    trail
                    nextIntentionCard
                    levelsRow
                    weekRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(ThemedBackground())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(theme.copy.appTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView(profile: profile) } label: {
                    Image(systemName: "gearshape.fill").foregroundStyle(theme.text)
                }
                .accessibilityLabel("Settings")
            }
        }
        .onAppear(perform: refresh)
        // A new day while the app sat open or in the background: rebuild the plan.
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refresh() }
        .onChange(of: router.pending) { _, _ in handleRoute() }
        .task { handleRoute() }
        .fullScreenCover(item: Binding(get: { playing.map(GameItem.init) }, set: { if $0 == nil { playing = nil } }),
                         onDismiss: afterStep) { item in
            GameHost(ctx: item.ctx, profile: profile) { _ in playing = nil }
                .environment(\.theme, theme)
        }
        .fullScreenCover(isPresented: $reviewing, onDismiss: afterStep) {
            NavigationStack { ReviewSessionView(profile: profile, countsForSession: true) }
                .environment(\.theme, theme)
        }
        .sheet(item: $lesson, onDismiss: afterStep) { l in
            LessonView(lesson: l) {
                _ = Quest.markLessonRead(l.id, profile: profile)
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $celebrate) {
            CelebrationSheet(profile: profile).environment(\.theme, theme).presentationDetents([.medium])
        }
    }

    // MARK: Sections

    private var stage: Int { DenGrowth.stage(activeDaysLast28: stats.active28) }

    /// The room, with today's course day in the corner.
    private var hero: some View {
        let day = stats.planDay
        return RoomSceneView(stage: stage, mood: mood)
            .overlay(alignment: .topTrailing) {
                Text("Day \(day) of \(Course.length)")
                    .font(theme.display(24))
                    .foregroundStyle(theme.ornament)
                    .padding(.top, 104)
                    .padding(.trailing, 18)
                    .accessibilityLabel("Course day \(day) of \(Course.length)")
            }
    }

    private var greetingBlock: some View {
        let todo = steps.filter { !$0.done }.count
        return VStack(alignment: .leading, spacing: 6) {
            Text(mood == .sleepy ? theme.copy.napLine
                 : theme.copy.greeting(name: profile.displayName, mascot: profile.mascotName,
                                       hour: Calendar.current.component(.hour, from: Date())))
                .font(theme.display(26))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(theme.copy.questTitle) · \(todo == 0 && !steps.isEmpty ? "done" : "~\(profile.dailyMinutes) min") · \(profile.shinies) \(theme.copy.shinyName)")
                .font(theme.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, -6)
    }

    /// Today's steps as stepping stones on a winding path, not rows in a box.
    private var trail: some View {
        let next = steps.firstIndex { !$0.done }
        return VStack(spacing: 18) {
            TrailPath(count: steps.count, doneCount: steps.filter(\.done).count) { i in
                let step = steps[i]
                TrailNode(icon: icon(for: step), title: title(for: step), subtitle: i == next ? "Next · \(subtitle(for: step))" : subtitle(for: step),
                          state: step.done ? .done : (i == next ? .next : .ahead), leading: i % 2 == 0) { start(step) }
            }
            if let n = next {
                Button { start(steps[n]) } label: {
                    Label("\(steps.contains(where: \.done) ? "Continue" : "Start") · \(title(for: steps[n]))", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if !steps.isEmpty {
                Text(theme.copy.celebrations.randomElement() ?? "All done!")
                    .font(theme.bodyEmphasis)
                    .foregroundStyle(theme.success)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var levelsRow: some View {
        HStack(spacing: 0) {
            level("\(profile.wordLevel)", "words")
            Rectangle().fill(theme.hairline).frame(width: 1, height: 40)
            level("\(profile.digitLevel)", "digits")
            Rectangle().fill(theme.hairline).frame(width: 1, height: 40)
            level("\(profile.nBackLevel)-back", "n-back")
        }
        .accessibilityElement(children: .combine)
    }

    private func level(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(theme.display(26)).foregroundStyle(theme.ornament)
            Text(label).font(.caption).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var nextIntentionCard: some View {
        let now = Date()
        let upcoming = intentions.flatMap { i in
            Notifications.occurrences(of: i, from: now, days: 2, calendar: .current)
                .filter { $0 > now && !i.isDone(on: $0) }.map { (i, $0) }
        }.min { $0.1 < $1.1 }
        if let upcoming {
            let intention = upcoming.0
            let date = upcoming.1
            HStack(spacing: 12) {
                Image(systemName: intention.level == .alarm ? "alarm.fill" : "bell.fill").font(.title2).foregroundStyle(theme.ornament)
                VStack(alignment: .leading, spacing: 2) {
                    Text(intention.text).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    Text(date, format: .dateTime.weekday(.wide).hour().minute()).font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Button("Done") {
                    Notifications.markIntentionDone(intention.id, on: date)
                    Haptic.success()
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 96)
            }
            .padding(14)
            .background(theme.shape(step: 6, radius: 22).fill(theme.raised.opacity(0.7)))
        }
    }

    private var weekRow: some View {
        let days = stats.weekDays
        let streak = stats.streak
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    theme.shape(step: 3, radius: 7)
                        .fill(i < days ? theme.primary : theme.raised)
                        .frame(width: 14, height: 14)
                }
                Text("\(days) of 4 days this week").font(theme.caption.weight(.semibold)).foregroundStyle(theme.text)
            }
            Text(streak > 0 ? "\(streak)-week streak" : "Weekly goal: 4 days. Missed days never reset anything.")
                .font(.caption).foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private func refresh() {
        guard Store.isLive(profile) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if today != shownDay { shownDay = today; AppEvents.appBecameActive() }
        steps = Quest.steps(for: profile)
        stats = DayStats(active3: Quest.activeDays(last: 3), active28: Quest.activeDays(last: 28),
                         weekDays: Quest.questDays(), streak: Quest.weeklyStreak(),
                         planDay: Store.dayRecord().planCourseDay ?? profile.courseDay)
        LiveActivityService.sync(profile: profile)
    }

    /// After a game, review or lesson closes: refresh, and celebrate if that step finished the day.
    private func afterStep() {
        refresh()
        if !wasDoneBefore && Store.dayRecord().questDone { celebrate = true }
    }

    private func handleRoute() {
        guard router.pending == .startQuest else { return }   // other routes belong to other tabs
        router.pending = nil
        refresh()
        if let next = steps.first(where: { !$0.done }) { start(next) }
    }

    private func start(_ step: QuestStep) {
        wasDoneBefore = Store.dayRecord().questDone
        Haptic.tap()
        switch step.kind {
        case .vault: reviewing = true
        case .lesson(let id): lesson = Course.lesson(id)
        case .task(let t, let size): playing = Quest.context(for: t, size: size, profile: profile)
        }
    }

    private func title(for step: QuestStep) -> String { StepText.title(step, theme: theme) }
    private func subtitle(for step: QuestStep) -> String { StepText.subtitle(step, theme: theme, profile: profile) }
    private func icon(for step: QuestStep) -> String { StepText.symbol(step) }
}

/// Identifiable wrapper so a `GameContext` can drive `fullScreenCover(item:)`.
struct GameItem: Identifiable {
    let ctx: GameContext
    var id: String { ctx.seed + "-\(ctx.size)" }
}

// MARK: Celebration

struct CelebrationSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let profile: Profile

    var body: some View {
        VStack(spacing: 16) {
            MascotView(mood: .happy, size: 140)
            Text(theme.copy.celebrations.randomElement() ?? "Done!").font(theme.display(32)).foregroundStyle(theme.text)
            Text("Session complete · +3 \(theme.copy.shinyName)").font(theme.bodyEmphasis).foregroundStyle(theme.ornament)
            if let next = Sprites.trinketOrder[safe: (profile.shinies / 5) % Sprites.trinketOrder.count],
               let art = Sprites.trinkets[next] {
                HStack {
                    PixelSpriteView(art: art).frame(width: 40, height: 40)
                    Text("Something new sparkles on your shelf…").font(theme.caption).foregroundStyle(theme.secondaryText)
                }
            }
            Button("Yay") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemedBackground())
        .onAppear { SFX.play(.levelup); Haptic.success() }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: Trail

/// Lays nodes out on alternating sides of a dashed, winding path; the walked part is solid.
struct TrailPath<Node: View>: View {
    @Environment(\.theme) private var theme
    let count: Int
    let doneCount: Int
    @ViewBuilder let node: (Int) -> Node

    /// Grows with Dynamic Type so long titles never run into the next stone.
    @ScaledMetric(relativeTo: .body) var rowHeight: CGFloat = 104

    var body: some View {
        GeometryReader { geo in
            let pts = points(width: geo.size.width)
            ZStack(alignment: .topLeading) {
                path(pts).stroke(theme.hairline, style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 1.5, lineCap: .round, dash: theme.pixelBorders ? [6, 6] : [3, 5]))
                path(Array(pts.prefix(doneCount + 1))).stroke(theme.primary.opacity(0.7), style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 2, lineCap: .round, dash: theme.pixelBorders ? [6, 6] : []))
                ForEach(0..<count, id: \.self) { i in
                    node(i)
                        .frame(width: geo.size.width, height: rowHeight)
                        .offset(y: pts[i].y - rowHeight / 2)
                }
            }
        }
        .frame(height: CGFloat(count) * rowHeight)
        .accessibilityElement(children: .contain)
    }

    private func points(width: CGFloat) -> [CGPoint] {
        (0..<count).map { CGPoint(x: $0 % 2 == 0 ? 44 : width - 44, y: rowHeight / 2 + CGFloat($0) * rowHeight) }
    }

    private func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for (a, b) in zip(pts, pts.dropFirst()) {
            p.addCurve(to: b, control1: CGPoint(x: a.x, y: a.y + 62), control2: CGPoint(x: b.x, y: b.y - 62))
        }
        return p
    }
}

/// One stepping stone: a diamond (Den) or medallion (Atelier), with its label beside it.
struct TrailNode: View {
    enum Phase { case done, next, ahead }
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let icon: String
    let title: String
    let subtitle: String
    let state: Phase
    let leading: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if leading { stone; labels(.leading); Spacer(minLength: 0) } else { Spacer(minLength: 0); labels(.trailing); stone }
            }
            .padding(.horizontal, 44 - size / 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .done)
        .accessibilityLabel("\(title). \(subtitle)\(state == .done ? ". Done" : "")")
        // Follows the stone's state, so only the current "next" stone pulses.
        .task(id: state == .next) {
            pulse = false
            guard state == .next, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var size: CGFloat { state == .next ? 64 : state == .done ? 40 : 48 }

    private var stone: some View {
        let fill: Color = state == .next ? theme.primary : state == .done ? theme.success.opacity(theme.pixelBorders ? 1 : 0.85) : theme.raised
        let fg: Color = state == .ahead ? theme.secondaryText : theme.onPrimary
        return ZStack {
            if theme.pixelBorders {
                Rectangle().fill(fill).rotationEffect(.degrees(45)).frame(width: size * 0.72, height: size * 0.72)
            } else {
                Circle().fill(fill)
                    .shadow(color: state == .next ? theme.primary.opacity(0.3) : .clear, radius: 10, y: 6)
                if state == .ahead { Circle().stroke(theme.ornament.opacity(0.6), lineWidth: 1) }
            }
            Image(systemName: state == .done ? "checkmark" : state == .next ? "play.fill" : icon)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(state == .done && theme.pixelBorders ? Color(hex: 0x17121F) : fg)
        }
        .frame(width: size, height: size)
        .scaleEffect(pulse ? 1.06 : 1)
        .accessibilityHidden(true)
    }

    private func labels(_ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(title).font(theme.bodyEmphasis).foregroundStyle(state == .done ? theme.secondaryText : theme.text)
            Text(subtitle).font(.caption).foregroundStyle(theme.secondaryText).lineLimit(2)
        }
        .multilineTextAlignment(align == .leading ? .leading : .trailing)
    }
}
