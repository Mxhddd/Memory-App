import SwiftUI
import MemoryCore

/// Intro (text + read-aloud, no time pressure) → the game → a cozy result screen.
struct GameHost: View {
    let ctx: GameContext
    let profile: Profile
    let onClose: (_ completedQuest: Bool) -> Void

    @Environment(\.theme) private var theme
    private enum Phase { case intro, playing, result(GameOutcome, Bool) }
    @State private var phase: Phase = .intro

    var body: some View {
        ZStack {
            ThemedBackground()
            switch phase {
            case .intro: intro
            case .playing: game.moonBell(active: ctx.moonBell, gentle: ctx.gentle) { hit in
                Quest.recordMoonBell(hit: hit, ctx: ctx)
            }
            case .result(let outcome, let completed): result(outcome, completed: completed)
            }
        }
        .overlay(alignment: .topLeading) {
            if case .result = phase {} else {
                Button { onClose(false) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(theme.secondaryText)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Close")
                .padding(.leading, 8)
            }
        }
    }

    // MARK: Intro

    private var instructions: String {
        if ctx.delayedRecall { return "Earlier you saw a list of words. Tap the ones you remember — no rush, and guesses are fine." }
        switch ctx.task {
        case .faceName: return "You'll meet a few people. Look at each face and say the name in your head. Then pick each person's name."
        case .ancientRunes: return "Each old symbol has a meaning. Study them at your own pace, then match symbol to meaning. You'll see the same ones all week — it gets easier!"
        case .snackPrices: return "Look at each snack and its price. Then pick the right price for each one."
        case .wordList: return "Twelve words will appear one at a time. Picture each one. Then tap every word you saw."
        case .stash: return "Things get hidden in the grid. Remember where each one is, then point to its spot."
        case .sequences: return "Lights blink in an order. Watch, then tap the same order. It adapts to you."
        case .runeSort: return "Each symbol has a number in the key at the top. Tap the number for the symbol in the middle — as quickly as you comfortably can."
        case .moonBell: return "When the moon appears, tap it."
        }
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: 20) {
                MascotView(mood: .idle, size: 120).padding(.top, 48)
                Text(ctx.delayedRecall ? "Remember the list?" : theme.copy.realmName(ctx.task))
                    .font(theme.display(32))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                SpeechBubble(text: instructions)
                if ctx.moonBell {
                    HStack(alignment: .top, spacing: 12) {
                        Text(theme.id == .midnightRaccoon ? "🌙" : "🔔").font(.largeTitle)
                        Text("Side quest: at some point a \(theme.id == .midnightRaccoon ? "moon" : "bell") will peek out in the corner. Tap it when you see it!")
                            .font(theme.body).foregroundStyle(theme.text)
                    }
                    .themedCard(raised: true)
                }
                ReadAloudButton(text: instructions + (ctx.moonBell ? " Side quest: when the \(theme.id == .midnightRaccoon ? "moon" : "bell") appears, tap it." : ""))
                Button("I'm ready") {
                    Haptic.tap()
                    phase = .playing
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    // MARK: Game

    @ViewBuilder private var game: some View {
        let finish: (GameOutcome) -> Void = { outcome in
            let completed = Quest.record(outcome, ctx: ctx, profile: profile)
            SFX.play(.shiny)
            phase = .result(outcome, completed)
        }
        switch ctx.task {
        case .faceName:
            PairGame(items: PairBuilders.faceName(ctx), studyVerb: "Meet the regulars", testQuestion: "What's their name?",
                     seed: ctx.seed, difficulty: DifficultyStore.difficulty(ofLevel: ctx.level), onFinish: finish)
        case .ancientRunes:
            PairGame(items: PairBuilders.runes(ctx, color: theme.text), studyVerb: "Learn the symbols", testQuestion: "What does this mean?",
                     seed: ctx.seed, difficulty: DifficultyStore.difficulty(ofLevel: ctx.level), onFinish: finish)
        case .snackPrices:
            PairGame(items: PairBuilders.snackPrices(ctx, theme: theme), studyVerb: "Remember the prices", testQuestion: "How much was it?",
                     seed: ctx.seed, difficulty: DifficultyStore.difficulty(ofLevel: ctx.level), onFinish: finish)
        case .wordList:
            WordListGame(ctx: ctx, onFinish: finish)
        case .stash:
            StashGame(ctx: ctx, onFinish: finish)
        case .sequences:
            SequencesGame(ctx: ctx, onFinish: finish)
        case .runeSort, .moonBell:
            RuneSortGame(ctx: ctx, onFinish: finish)
        }
    }

    // MARK: Result

    private func result(_ outcome: GameOutcome, completed: Bool) -> some View {
        VStack(spacing: 18) {
            Spacer()
            MascotView(mood: .happy, size: 150)
            Text(theme.copy.celebrations.randomElement() ?? "Nice!")
                .font(theme.display(34))
                .foregroundStyle(theme.text)
            Text(resultLine(outcome))
                .font(theme.body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Label("+1 \(theme.copy.shinyName)", systemImage: "sparkles")
                .font(theme.bodyEmphasis)
                .foregroundStyle(theme.ornament)
            if ctx.task == .wordList && !ctx.delayedRecall {
                Text("I'll ask about these words again in about 20 minutes. 🛎")
                    .font(theme.caption)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(completed ? "Finish quest ✨" : "Back") { onClose(completed) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    /// Effort-focused feedback. Day-to-day wobble is normal, so we never grade harshly.
    private func resultLine(_ o: GameOutcome) -> String {
        switch ctx.task {
        case .sequences: return "You followed \(o.correct) of \(o.total) sequences."
        case .runeSort, .moonBell: return "\(o.correct) matched. Speed grows with practice."
        case .wordList: return "You found \(o.correct) of \(o.total) words."
        default:
            if ctx.isMeasurement, let day = ctx.burst?.day, day > 1 {
                return "\(o.correct) of \(o.total) today — same set all week, watch it grow."
            }
            return "\(o.correct) of \(o.total) remembered."
        }
    }
}
