import SwiftUI
import SwiftData
import MemoryCore

/// Review due cards with FSRS-6, and learn new cards errorlessly:
/// show answer → recall at 30 s, 1, 2, 4 min (in-session) → graduate into FSRS.
struct ReviewSessionView: View {
    @Bindable var profile: Profile
    let countsForQuest: Bool
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Equatable {
        case learn(UUID)       // errorless presentation (answer visible)
        case recall(UUID)      // errorless recall check
        case review(UUID)      // FSRS review
        case waiting
        case finished
    }

    @State private var mode: Mode = .finished
    @State private var revealed = false
    @State private var errorless = ErrorlessSession<UUID>()
    @State private var newQueue: [UUID] = []
    @State private var reviewQueue: [UUID] = []
    @State private var reviewedCount = 0
    @State private var waitSeconds = 0
    @State private var loaded = false

    private var scheduler: FSRSScheduler {
        FSRSScheduler(desiredRetention: profile.desiredRetention, enableFuzzing: true)
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: 18) {
                switch mode {
                case .learn(let id): if let c = card(id) { learnView(c) }
                case .recall(let id): if let c = card(id) { recallView(c) }
                case .review(let id): if let c = card(id) { reviewView(c) }
                case .waiting: waitingView
                case .finished: finishedView
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .task(id: mode) {
            guard mode == .waiting else { return }
            while mode == .waiting {
                waitSeconds = Int(errorless.secondsUntilNext(from: Date()) ?? 0)
                if waitSeconds <= 0 { advance(); return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
        }
    }

    // MARK: Data

    private func card(_ id: UUID) -> MemoryCard? {
        try? Store.context.fetch(FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.id == id })).first
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let due = Quest.dueCards()
        let newLimit = profile.errorlessNewCards ? 3 : 5 // small batches of new material
        newQueue = due.filter { $0.isNew && $0.needsErrorless && profile.errorlessNewCards }.prefix(newLimit).map(\.id)
        reviewQueue = due.filter { !newQueue.contains($0.id) }.prefix(30).map(\.id)
        advance()
    }

    private func advance() {
        revealed = false
        let now = Date()
        if let id = errorless.due(at: now).first { mode = .recall(id); return }
        if let id = newQueue.first { newQueue.removeFirst(); mode = .learn(id); return }
        if let id = reviewQueue.first { reviewQueue.removeFirst(); mode = .review(id); return }
        if !errorless.isFinished && !errorless.items.isEmpty { mode = .waiting; return }
        mode = .finished
        if countsForQuest || reviewedCount > 0 {
            if Quest.markDeckDone(profile: profile) { SFX.play(.levelup) }
        }
    }

    // MARK: Errorless

    private func learnView(_ c: MemoryCard) -> some View {
        VStack(spacing: 16) {
            Text("New — just take it in").font(theme.caption).foregroundStyle(theme.secondaryText)
            cardFace(c, showAnswer: true)
            Button("I've got it") {
                errorless.present(c.id, at: Date())
                Haptic.soft()
                advance()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func recallView(_ c: MemoryCard) -> some View {
        VStack(spacing: 16) {
            Text("Do you remember? No guessing needed").font(theme.caption).foregroundStyle(theme.secondaryText)
            cardFace(c, showAnswer: revealed)
            if !revealed {
                Button("I remember — show me") { revealed = true }.buttonStyle(PrimaryButtonStyle())
                Button("Not sure — show me") { errorlessResult(c, recalled: false) }.buttonStyle(SecondaryButtonStyle())
            } else {
                Text("Was that what you had in mind?").font(theme.body).foregroundStyle(theme.text)
                HStack {
                    Button("Not quite") { errorlessResult(c, recalled: false) }.buttonStyle(SecondaryButtonStyle())
                    Button("Yes!") { errorlessResult(c, recalled: true) }.buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private func errorlessResult(_ c: MemoryCard, recalled: Bool) {
        let graduated = errorless.record(c.id, recalled: recalled, at: Date())
        if recalled { SFX.play(.correct) }
        if !recalled {
            // Errorless: re-show the answer right away; presenting again restarts the ladder.
            newQueue.insert(c.id, at: 0)
        }
        if graduated {
            // Hand over to FSRS as a successfully learned card (no further learning steps).
            var graduateScheduler = scheduler
            graduateScheduler.learningSteps = []
            c.fsrs = graduateScheduler.review(c.fsrs, rating: .good, at: Date())
            c.needsErrorless = false
            c.reps += 1
            Store.save()
            reviewedCount += 1
        }
        advance()
    }

    private var waitingView: some View {
        VStack(spacing: 16) {
            MascotView(mood: .idle, size: 120)
            Text("Breather").font(theme.display(30)).foregroundStyle(theme.text)
            Text("Spacing helps it stick. Next recall in \(waitSeconds) s.")
                .font(theme.body).foregroundStyle(theme.secondaryText)
            Button("Finish later") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: FSRS review

    private func reviewView(_ c: MemoryCard) -> some View {
        VStack(spacing: 16) {
            Text("\(reviewQueue.count + 1) left").font(theme.caption).foregroundStyle(theme.secondaryText)
            cardFace(c, showAnswer: revealed)
            if !revealed {
                Button("Show answer") { revealed = true; Haptic.tap() }.buttonStyle(PrimaryButtonStyle())
            } else if profile.simpleRatings {
                HStack {
                    Button("Not yet") { rate(c, .again) }.buttonStyle(SecondaryButtonStyle())
                    Button("Got it") { rate(c, .good) }.buttonStyle(PrimaryButtonStyle())
                }
            } else {
                HStack(spacing: 8) {
                    Button("Again") { rate(c, .again) }.buttonStyle(SecondaryButtonStyle())
                    Button("Hard") { rate(c, .hard) }.buttonStyle(SecondaryButtonStyle())
                    Button("Good") { rate(c, .good) }.buttonStyle(PrimaryButtonStyle())
                    Button("Easy") { rate(c, .easy) }.buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func rate(_ c: MemoryCard, _ rating: Rating) {
        let r = scheduler.retrievability(of: c.fsrs)
        c.fsrs = scheduler.review(c.fsrs, rating: rating)
        c.reps += 1
        if rating == .again { c.lapses += 1 }
        c.needsErrorless = false
        Store.context.insert(ReviewLogEntry(cardID: c.id, rating: rating, retrievability: r))
        Store.save()
        reviewedCount += 1
        if rating == .again { SFX.play(.gentle) } else { SFX.play(.correct) }
        advance()
    }

    // MARK: Shared

    private func cardFace(_ c: MemoryCard, showAnswer: Bool) -> some View {
        VStack(spacing: 14) {
            if let data = c.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: c.kind.icon).font(.system(size: 48)).foregroundStyle(theme.primary)
            }
            Text(c.prompt).font(theme.bodyEmphasis).foregroundStyle(theme.text).multilineTextAlignment(.center)
            if showAnswer {
                Divider().overlay(theme.ornament)
                Text(c.answer).font(theme.display(30)).foregroundStyle(theme.text).multilineTextAlignment(.center)
                if !c.hint.isEmpty {
                    Text("💡 \(c.hint)").font(theme.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .themedCard()
        .accessibilityElement(children: .combine)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            MascotView(mood: .happy, size: 130)
            Text(reviewedCount > 0 ? "Deck done!" : "Nothing due right now").font(theme.display(30)).foregroundStyle(theme.text)
            Text(reviewedCount > 0 ? "\(reviewedCount) memories refreshed. They'll come back right before you'd forget them."
                                   : "Add a few personal cards in Practice — they come back at just the right time.")
                .font(theme.body).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }
}
