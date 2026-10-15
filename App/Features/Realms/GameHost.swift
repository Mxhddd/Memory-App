import SwiftUI
import SwiftData
import MemoryCore

/// Intro (text + read-aloud) → the drill → result.
struct GameHost: View {
    let ctx: GameContext
    let profile: Profile
    let onClose: (_ completedSession: Bool) -> Void

    @Environment(\.theme) private var theme
    @Query(sort: \Palace.createdAt) private var palaces: [Palace]
    private enum Phase { case intro, playing, result(GameOutcome, Bool) }
    @State private var phase: Phase = .intro
    @State private var buildingPalace = false

    private var palace: Palace? {
        if let id = ctx.palaceID, let p = palaces.first(where: { $0.id == id }) { return p }
        return palaces.first
    }

    private var needsPalace: Bool { [.routeWalk, .wordSprint, .sprintRetention].contains(ctx.task) && palaces.isEmpty }

    var body: some View {
        ZStack {
            ThemedBackground()
            switch phase {
            case .intro: intro
            case .playing: game
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
        .sheet(isPresented: $buildingPalace) { NavigationStack { PalaceEditor(palace: nil) }.environment(\.theme, theme) }
    }

    // MARK: Intro

    private var instructions: String {
        switch ctx.task {
        case .routeWalk: return "Tap your palace's stops in walking order. A route you can walk without thinking is the backbone of the method."
        case .wordSprint: return "You'll see \(ctx.size) words. Place each one at the next stop of your palace as a big, strange, moving image. Then walk the route and type what you find at each stop."
        case .sprintRetention: return "Yesterday you placed \(ctx.size) words in your palace. Walk it again and see what survived the night — sleep is when memories set."
        case .numberSprint: return "Turn each pair of digits into its Major-system picture (71 = cat, 92 = bone) and place them along a route. Then type the whole number back."
        case .dualNBack: return "A square lights up and a letter is spoken every 3 seconds. Tap POSITION when the square is where it was \(ctx.size) steps ago, and SOUND when the letter matches \(ctx.size) steps ago. Turn your sound on."
        case .complexSpan: return "Judge each sum as true or false, then remember the letter that follows. After each set, tap the letters in order. Keep the maths accurate — that's part of the challenge."
        case .sequences: return "Squares light up in order. Watch, then tap the same order. It adapts to you."
        case .faceName: return "Meet each person and make a picture of their name on their face (Hamza → a hamster in his eyebrows). Then pick each person's name."
        case .ancientRunes: return "Each symbol has a meaning. Link them with a quick image (a wavy rune = river). Then match symbol to meaning."
        case .stash: return "Things get hidden in the grid. Remember where each one is, then point to its spot."
        case .wordRecall: return "Benchmark: study 30 words for up to 5 minutes using any method you like — palace included. After a short pause, type all you remember. This shows how your memory is changing."
        case .digitSpan: return "Benchmark: digits appear one at a time. Type them back in order. The list grows until two misses in a row."
        }
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: 20) {
                MascotView(mood: .idle, size: 110).padding(.top, 48)
                Text(theme.copy.realmName(ctx.task))
                    .font(theme.display(32))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                SpeechBubble(text: instructions)
                ReadAloudButton(text: instructions)
                if needsPalace {
                    Text("This drill needs a memory palace first.").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    Button("Build a palace") { buildingPalace = true }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("I'm ready") {
                        Haptic.tap()
                        phase = .playing
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
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
        case .routeWalk:
            if let palace { RouteWalkGame(palace: palace, onFinish: finish) }
        case .wordSprint:
            WordSprintGame(ctx: ctx, palace: palace, retention: false, onFinish: finish)
        case .sprintRetention:
            WordSprintGame(ctx: ctx, palace: palace, retention: true, onFinish: finish)
        case .numberSprint:
            NumberSprintGame(ctx: ctx, onFinish: finish)
        case .dualNBack:
            DualNBackGame(ctx: ctx, blocks: profile.dailyMinutes >= 25 ? 3 : profile.dailyMinutes >= 15 ? 2 : 1,
                          showLetters: profile.showNBackLetters, onFinish: finish)
        case .complexSpan:
            ComplexSpanGame(ctx: ctx, onFinish: finish)
        case .sequences:
            SequencesGame(ctx: ctx, onFinish: finish)
        case .faceName:
            PairGame(items: PairBuilders.faceName(ctx), studyVerb: "Meet them — hook each name to a feature", testQuestion: "What's their name?",
                     seed: ctx.seed, difficulty: DifficultyStore.difficulty(ofLevel: ctx.level), onFinish: finish)
        case .ancientRunes:
            PairGame(items: PairBuilders.runes(ctx, color: theme.text), studyVerb: "Link each symbol to its meaning", testQuestion: "What does this mean?",
                     seed: ctx.seed, difficulty: DifficultyStore.difficulty(ofLevel: ctx.level), onFinish: finish)
        case .stash:
            StashGame(ctx: ctx, onFinish: finish)
        case .wordRecall:
            WordRecallBenchmark(ctx: ctx, onFinish: finish)
        case .digitSpan:
            DigitSpanGame(ctx: ctx, onFinish: finish)
        }
    }

    // MARK: Result

    private func result(_ outcome: GameOutcome, completed: Bool) -> some View {
        VStack(spacing: 18) {
            Spacer()
            MascotView(mood: .happy, size: 140)
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
            Spacer()
            Button(completed ? "Finish session ✨" : "Back") { onClose(completed) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private func resultLine(_ o: GameOutcome) -> String {
        switch ctx.task {
        case .wordSprint, .sprintRetention:
            let next = ctx.task == .wordSprint ? Course.nextWordLevel(current: ctx.size, accuracy: o.score) : ctx.size
            return "\(o.correct) of \(o.total) in the right place." + (next > ctx.size ? " Next sprint: \(next) words." : "")
        case .numberSprint: return "\(o.correct) of \(o.total) digits in the right place."
        case .dualNBack:
            return "Caught \(o.correct) of \(o.total) matches. " + (o.nextLevel.map { "Next time: \($0)-back." } ?? "")
        case .complexSpan: return "Recalled \(o.correct) of \(o.total) letters in perfect sets."
        case .wordRecall: return "\(o.correct) of 30 words. Compare with your next benchmark in Progress."
        case .digitSpan: return "Digit span: \(o.correct)."
        case .routeWalk: return o.correct == o.total ? "Flawless walk." : "\(o.correct) of \(o.total) stops first time."
        default: return "\(o.correct) of \(o.total) remembered."
        }
    }
}
