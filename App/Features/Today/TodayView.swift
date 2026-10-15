import SwiftUI
import SwiftData
import MemoryCore

struct TodayView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @EnvironmentObject private var router: Router
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query(filter: #Predicate<Intention> { $0.active == true }, sort: \Intention.time) private var intentions: [Intention]

    @State private var steps: [QuestStep] = []
    @State private var playing: GameContext?
    @State private var reviewing = false
    @State private var showCheckIn = false
    @State private var celebrate = false
    @State private var delayedReady: DelayedRecall.Pending?

    private var checkedInToday: Bool {
        checkIns.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    private var mood: MascotMood {
        if steps.allSatisfy(\.done) && !steps.isEmpty { return .happy }
        let lastDays = Quest.activeDays(last: 3)
        return lastDays == 0 && Quest.activeDays(last: 28) > 0 ? .sleepy : .idle
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                if !checkedInToday { checkInChip }
                questCard
                if let pending = delayedReady { delayedCard(pending) }
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
            GameHost(ctx: item.ctx, profile: profile) { completedQuest in
                playing = nil
                refresh()
                if completedQuest { celebrate = true }
            }
            .environment(\.theme, theme)
        }
        .fullScreenCover(isPresented: $reviewing, onDismiss: refresh) {
            NavigationStack { ReviewSessionView(profile: profile, countsForQuest: true) }
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showCheckIn, onDismiss: refresh) {
            CheckInSheet().environment(\.theme, theme).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $celebrate) {
            CelebrationSheet(profile: profile).environment(\.theme, theme).presentationDetents([.medium])
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            MascotView(mood: mood, size: theme.largeTargets ? 110 : 120)
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

    private var checkInChip: some View {
        Button { showCheckIn = true } label: {
            HStack {
                Image(systemName: "heart.text.square.fill")
                Text("Quick check-in: sleep, stress, mood")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(theme.bodyEmphasis)
            .foregroundStyle(theme.text)
            .themedCard(raised: true)
        }
        .buttonStyle(.plain)
    }

    private var questCard: some View {
        let done = steps.filter(\.done).count
        let burst = Quest.isBurstDay(profile) ? profile.planner.burstDay(for: Date()) : nil
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(theme.copy.questTitle).font(theme.display(28)).foregroundStyle(theme.text)
                Spacer()
                if let burst {
                    Text("Check-in week · day \(burst.day)/7")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(theme.accent.opacity(0.3)))
                        .foregroundStyle(theme.text)
                }
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

    private func delayedCard(_ pending: DelayedRecall.Pending) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(theme.id == .midnightRaccoon ? "🛒 \(profile.mascotName) wants the list back" : "Letter recall")
                .font(theme.bodyEmphasis).foregroundStyle(theme.text)
            Text("Which words do you still remember from earlier? One minute.")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
            Button("Recall now") { playing = Quest.delayedRecallContext(pending, profile: profile) }
                .buttonStyle(PrimaryButtonStyle())
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
                Text(streak > 0 ? "\(streak)-week streak" : "Weekly goal: 4 days. Missed days never break anything.")
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
        delayedReady = DelayedRecall.ready()
        LiveActivityService.sync(profile: profile)
    }

    private func handleRoute() {
        guard let destination = router.pending else { return }
        router.pending = nil
        refresh()
        switch destination {
        case .startQuest:
            if let next = steps.first(where: { !$0.done }) { start(next) }
        case .delayedRecall:
            if let p = DelayedRecall.ready() { playing = Quest.delayedRecallContext(p, profile: profile) }
        default: break
        }
    }

    private func start(_ step: QuestStep) {
        Haptic.tap()
        switch step.kind {
        case .deck: reviewing = true
        case .task(let t): playing = Quest.context(for: t, profile: profile)
        }
    }

    private func title(for step: QuestStep) -> String {
        switch step.kind {
        case .deck: return "Your memory cards"
        case .task(let t): return theme.copy.realmName(t)
        }
    }

    private func subtitle(for step: QuestStep) -> String {
        switch step.kind {
        case .deck:
            let due = Quest.dueCards().count
            return due > 0 ? "\(due) ready to review" : "A quick look at your cards"
        case .task(let t): return theme.copy.realmBlurb(t)
        }
    }

    private func icon(for step: QuestStep) -> String {
        switch step.kind {
        case .deck: return "rectangle.stack.fill"
        case .task(let t):
            switch t {
            case .faceName: return "person.2.fill"
            case .snackPrices: return "cart.fill"
            case .wordList: return "list.bullet.rectangle"
            case .stash: return "square.grid.3x3.fill"
            case .sequences: return "sparkles"
            case .runeSort: return "bolt.fill"
            case .moonBell: return "bell.fill"
            case .ancientRunes: return "character.book.closed.fill"
            }
        }
    }
}

/// Identifiable wrapper so a `GameContext` can drive `fullScreenCover(item:)`.
struct GameItem: Identifiable {
    let ctx: GameContext
    var id: String { ctx.seed + (ctx.delayedRecall ? "-d" : "") }
}

// MARK: Check-in

struct CheckInSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var sleep = 2
    @State private var stress = 2
    @State private var mood = 2
    @State private var unwell = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    row("Last night's sleep", value: $sleep, options: ["😴 Poor", "🙂 OK", "✨ Great"])
                    row("Stress right now", value: $stress, options: ["🌿 Calm", "🌤 Some", "🌩 High"])
                    row("Mood", value: $mood, options: ["🌧 Low", "⛅️ OK", "☀️ Good"])
                    Toggle("Feeling unwell today", isOn: $unwell).font(theme.body).foregroundStyle(theme.text).tint(theme.primary)
                    Text("This only helps read your practice fairly — on a rough day, lower scores are expected and never count against you.")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                    Button("Save") {
                        context.insert(CheckIn(sleep: sleep, stress: stress, mood: mood, unwell: unwell))
                        try? context.save()
                        Haptic.success()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
            }
            .background(ThemedBackground())
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, value: Binding<Int>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(theme.bodyEmphasis).foregroundStyle(theme.text)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Button(options[i]) { value.wrappedValue = i + 1; Haptic.tap() }
                        .buttonStyle(ChoiceButtonStyle(state: value.wrappedValue == i + 1 ? .selected : .idle))
                }
            }
        }
    }
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
            Text("Quest complete · +3 \(theme.copy.shinyName)").font(theme.bodyEmphasis).foregroundStyle(theme.ornament)
            if let next = Sprites.trinketOrder[safe: (profile.shinies / 5) % Sprites.trinketOrder.count],
               let art = Sprites.trinkets[next] {
                HStack {
                    PixelSpriteView(art: art).frame(width: 40, height: 40)
                    Text("Something new sparkles in \(theme.copy.denTitle.lowercased())…").font(theme.caption).foregroundStyle(theme.secondaryText)
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
