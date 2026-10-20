import SwiftUI
import SwiftData
import MemoryCore

/// FSRS-6 review with active recall: type the answer first (generation effect), then grade.
/// Cards from different decks are interleaved; new cards are limited per session.
struct ReviewSessionView: View {
    @Bindable var profile: Profile
    let countsForSession: Bool
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [UUID] = []
    @State private var current: UUID?
    @State private var revealed = false
    @State private var typed = ""
    @State private var reviewed = 0
    @State private var started = Date()
    @State private var loaded = false
    @FocusState private var focused: Bool

    /// Warm-up cap so the Vault never eats the whole session.
    private var timeCapSeconds: Double { countsForSession ? Double(max(profile.dailyMinutes / 3, 3)) * 60 : .infinity }

    private var scheduler: FSRSScheduler { FSRSScheduler(desiredRetention: profile.desiredRetention) }

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: 18) {
                if let id = current, let card = card(id) {
                    reviewView(card)
                } else {
                    finishedView
                }
            }
            .padding(20)
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { finish() } } }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func card(_ id: UUID) -> MemoryCard? {
        try? Store.context.fetch(FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.id == id })).first
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let due = Quest.dueCards()
        let old = due.filter { !$0.isNew }
        let new = due.filter(\.isNew).prefix(10)
        // Interleave decks: round-robin by deck.
        let byDeck = Dictionary(grouping: old + new, by: \.deck).mapValues { $0.map(\.id) }
        var lists = Array(byDeck.values)
        var out: [UUID] = []
        while lists.contains(where: { !$0.isEmpty }) {
            for i in lists.indices where !lists[i].isEmpty { out.append(lists[i].removeFirst()) }
        }
        queue = Array(out.prefix(60))
        started = Date()
        advance()
    }

    private func advance() {
        revealed = false
        typed = ""
        if Date().timeIntervalSince(started) > timeCapSeconds || queue.isEmpty {
            current = nil
            if reviewed > 0 || countsForSession { _ = Quest.markVaultDone(profile: profile) }
            return
        }
        current = queue.removeFirst()
        focused = profile.typedAnswers
    }

    private func reviewView(_ c: MemoryCard) -> some View {
        let correct = AnswerMatch.matches(typed, c.answer)
        return VStack(spacing: 16) {
            Text("\(queue.count + 1) left · \(c.deck)").font(theme.caption).foregroundStyle(theme.secondaryText)
            cardFace(c, showAnswer: revealed)
            if !revealed {
                if profile.typedAnswers {
                    TextField("Type your answer", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { revealed = true }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                        .foregroundStyle(theme.text)
                }
                Button(profile.typedAnswers ? "Check" : "Show answer") { revealed = true; Haptic.tap() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                if profile.typedAnswers && !typed.isEmpty {
                    Label(correct ? "You had it" : "You wrote: \(typed)", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle")
                        .font(theme.bodyEmphasis).foregroundStyle(correct ? theme.success : theme.primary)
                }
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
        if rating == .again { c.lapses += 1; queue.append(c.id) } // see it again this session
        Store.context.insert(ReviewLogEntry(cardID: c.id, rating: rating, retrievability: r))
        Store.save()
        reviewed += 1
        if rating == .again { SFX.play(.gentle) } else { SFX.play(.correct) }
        advance()
    }

    private func cardFace(_ c: MemoryCard, showAnswer: Bool) -> some View {
        VStack(spacing: 14) {
            if let data = c.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(c.prompt).font(theme.display(28)).foregroundStyle(theme.text).multilineTextAlignment(.center)
            if showAnswer {
                Divider().overlay(theme.ornament)
                Text(c.answer).font(theme.display(28)).foregroundStyle(theme.primary).multilineTextAlignment(.center)
                if !c.hint.isEmpty {
                    Text("\(Image(systemName: "lightbulb")) \(c.hint)").font(theme.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
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
            Text(reviewed > 0 ? "Vault done" : "Nothing due right now").font(theme.display(30)).foregroundStyle(theme.text)
            Text(reviewed > 0 ? "\(reviewed) recalls. Each one makes the memory more durable."
                              : "Add cards or a starter pack in the Vault tab.")
                .font(theme.body).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
            Button("Done") { finish() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func finish() {
        if reviewed > 0 && current != nil { _ = Quest.markVaultDone(profile: profile) }
        dismiss()
    }
}
