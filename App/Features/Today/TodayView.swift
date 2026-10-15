import SwiftUI
import SwiftData
import MemoryCore

struct TodayView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @EnvironmentObject private var router: Router
    @Query(filter: #Predicate<Intention> { $0.active == true }, sort: \Intention.time) private var intentions: [Intention]

    @State private var steps: [QuestStep] = []
    @State private var playing: GameContext?
    @State private var reviewing = false
    @State private var lesson: Lesson?
    @State private var celebrate = false

    private var mood: MascotMood {
        if steps.allSatisfy(\.done) && !steps.isEmpty { return .happy }
        return Quest.activeDays(last: 3) == 0 && Quest.activeDays(last: 28) > 0 ? .sleepy : .idle
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                sessionCard
                courseCard
                nextIntentionCard
                weekCard
            }
            .padding(16)
        }
        .background(ThemedBackground())
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
        .onChange(of: router.pending) { _, _ in handleRoute() }
        .task { handleRoute() }
        .fullScreenCover(item: Binding(get: { playing.map(GameItem.init) }, set: { if $0 == nil { playing = nil } })) { item in
            GameHost(ctx: item.ctx, profile: profile) { completed in
                playing = nil
                refresh()
                if completed { celebrate = true }
            }
            .environment(\.theme, theme)
        }
        .fullScreenCover(isPresented: $reviewing, onDismiss: refresh) {
            NavigationStack { ReviewSessionView(profile: profile, countsForSession: true) }
                .environment(\.theme, theme)
        }
        .sheet(item: $lesson, onDismiss: refresh) { l in
            LessonView(lesson: l) {
                if Quest.markLessonRead(l.id, profile: profile) { celebrate = true }
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $celebrate) {
            CelebrationSheet(profile: profile).environment(\.theme, theme).presentationDetents([.medium])
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            MascotView(mood: mood, size: 112)
            VStack(alignment: .leading, spacing: 8) {
                Text(mood == .sleepy ? theme.copy.napLine
                     : theme.copy.greeting(name: profile.displayName, mascot: profile.mascotName,
                                           hour: Calendar.current.component(.hour, from: Date())))
                    .font(theme.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Label("\(profile.shinies) \(theme.copy.shinyName)", systemImage: "sparkles")
                    .font(theme.caption.weight(.semibold))
                    .foregroundStyle(theme.ornament)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionCard: some View {
        let done = steps.filter(\.done).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(theme.copy.questTitle).font(theme.display(28)).foregroundStyle(theme.text)
                Spacer()
                Text("~\(profile.dailyMinutes) min").font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(theme.accent.opacity(0.3)))
                    .foregroundStyle(theme.text)
            }
            ProgressPips(done: done, total: steps.count)
            ForEach(steps) { step in
                Button { start(step) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: step.done ? "checkmark.seal.fill" : icon(for: step))
                            .font(.title2)
                            .foregroundStyle(step.done ? theme.success : theme.primary)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(for: step)).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                            Text(subtitle(for: step)).font(theme.caption).foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        if !step.done { Image(systemName: "play.fill").foregroundStyle(theme.primary) }
                    }
                    .frame(minHeight: theme.minTouch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(step.done)
            }
            if let next = steps.first(where: { !$0.done }) {
                Button(done == 0 ? "Start" : "Continue") { start(next) }
                    .buttonStyle(PrimaryButtonStyle())
            } else if !steps.isEmpty {
                Text(theme.copy.celebrations.randomElement() ?? "All done!")
                    .font(theme.bodyEmphasis)
                    .foregroundStyle(theme.success)
                    .frame(maxWidth: .infinity)
            }
        }
        .themedCard()
    }

    private var courseCard: some View {
        let course = Quest.courseDay(profile)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memory Palace course").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                Spacer()
                Text("Day \(course.day) of \(Course.length)").font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            ProgressView(value: Double(course.day - 1), total: Double(Course.length)).tint(theme.primary)
            Text("Words: \(profile.wordLevel) · Digits: \(profile.digitLevel) · n-back: \(profile.nBackLevel)")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard(raised: true)
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
                    Notifications.markIntentionDone(intention.id)
                    Haptic.success()
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 96)
            }
            .themedCard()
        }
    }

    private var weekCard: some View {
        let days = Quest.questDays()
        let streak = Quest.weeklyStreak()
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This week").font(theme.caption).foregroundStyle(theme.secondaryText)
                Text("\(days) of 4 days").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                Text(streak > 0 ? "\(streak)-week streak" : "Weekly goal: 4 days. Missed days never reset anything.")
                    .font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            Spacer()
            ProgressView(value: Double(min(days, 4)), total: 4)
                .progressViewStyle(.circular)
                .tint(theme.primary)
                .scaleEffect(1.4)
                .accessibilityLabel("\(days) of 4 days this week")
        }
        .themedCard()
    }

    // MARK: Actions

    private func refresh() {
        steps = Quest.steps(for: profile)
        LiveActivityService.sync(profile: profile)
    }

    private func handleRoute() {
        guard let destination = router.pending else { return }
        router.pending = nil
        refresh()
        if destination == .startQuest, let next = steps.first(where: { !$0.done }) { start(next) }
    }

    private func start(_ step: QuestStep) {
        Haptic.tap()
        switch step.kind {
        case .vault: reviewing = true
        case .lesson(let id): lesson = Course.lesson(id)
        case .task(let t, let size): playing = Quest.context(for: t, size: size, profile: profile)
        }
    }

    private func title(for step: QuestStep) -> String {
        switch step.kind {
        case .vault: return "Vault warm-up"
        case .lesson(let id): return "Lesson · \(Course.lesson(id)?.title ?? "")"
        case .task(let t, let size):
            switch t {
            case .wordSprint, .sprintRetention: return "\(theme.copy.realmName(t)) · \(size) words"
            case .numberSprint: return "\(theme.copy.realmName(t)) · \(size) digits"
            case .dualNBack: return "\(theme.copy.realmName(t)) · \(size)-back"
            default: return theme.copy.realmName(t)
            }
        }
    }

    private func subtitle(for step: QuestStep) -> String {
        switch step.kind {
        case .vault:
            let due = Quest.dueCards().count
            return due > 0 ? "\(due) cards ready — recall before you reveal" : "Cards reviewed"
        case .lesson: return "A few minutes of technique"
        case .task(let t, _): return theme.copy.realmBlurb(t)
        }
    }

    private func icon(for step: QuestStep) -> String {
        switch step.kind {
        case .vault: return "rectangle.stack.fill"
        case .lesson: return "book.fill"
        case .task(let t, _):
            switch t {
            case .routeWalk: return "figure.walk"
            case .wordSprint, .sprintRetention: return "building.columns.fill"
            case .numberSprint: return "number"
            case .dualNBack: return "square.grid.3x3.fill"
            case .complexSpan: return "plusminus"
            case .sequences: return "sparkles"
            case .faceName: return "person.2.fill"
            case .ancientRunes: return "character.book.closed.fill"
            case .stash: return "shippingbox.fill"
            case .wordRecall, .digitSpan: return "flag.checkered"
            }
        }
    }
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
