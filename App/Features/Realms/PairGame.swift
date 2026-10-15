import SwiftUI
import MemoryCore

/// Study-then-test associative learning, shared by Face–Name, Ancient Runes and Snack Prices.
/// Study is self-paced (no time pressure); the test is 3–4-choice recognition with gentle feedback.
struct PairItem: Identifiable {
    let id: Int
    let cue: AnyView
    let cueLabel: String      // accessibility / read-aloud
    let answer: String
    let options: [String]     // includes `answer`
}

struct PairGame: View {
    @Environment(\.theme) private var theme
    let items: [PairItem]
    let studyVerb: String
    let testQuestion: String
    let seed: String
    let difficulty: Double
    let onFinish: (GameOutcome) -> Void

    private enum Phase { case study(Int), test(Int), done }
    @State private var phase: Phase = .study(0)
    @State private var testOrder: [Int] = []
    @State private var picked: String?
    @State private var correct = 0
    @State private var rts: [Double] = []
    @State private var trials: [(Double, Bool)] = []
    @State private var timer = ResponseTimer()

    var body: some View {
        VStack(spacing: 20) {
            switch phase {
            case .study(let i):
                GameHeader(title: studyVerb, progress: (i + 1, items.count))
                Spacer(minLength: 0)
                items[i].cue
                    .frame(maxWidth: 240, maxHeight: 240)
                    .accessibilityLabel(items[i].cueLabel)
                Text(items[i].answer)
                    .font(theme.display(34))
                    .foregroundStyle(theme.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(i + 1 < items.count ? "Next" : "I'm ready") {
                    Haptic.tap()
                    if i + 1 < items.count {
                        phase = .study(i + 1)
                    } else {
                        testOrder = Array(items.indices).shuffledSeeded(seed + "-order")
                        timer.reset()
                        phase = .test(0)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

            case .test(let t):
                let item = items[testOrder[t]]
                GameHeader(title: testQuestion, progress: (t, items.count))
                Spacer(minLength: 0)
                item.cue
                    .frame(maxWidth: 200, maxHeight: 200)
                    .accessibilityLabel(item.cueLabel)
                Spacer(minLength: 0)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(item.options, id: \.self) { option in
                        Button(option) { choose(option, for: item, at: t) }
                            .buttonStyle(ChoiceButtonStyle(state: state(for: option, item: item)))
                            .disabled(picked != nil)
                    }
                }

            case .done:
                ProgressView()
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: picked)
    }

    private func state(for option: String, item: PairItem) -> ChoiceButtonStyle.ChoiceState {
        guard let picked else { return .idle }
        if option == item.answer { return .correct }
        if option == picked { return .wrong }
        return .idle
    }

    private func choose(_ option: String, for item: PairItem, at t: Int) {
        let ok = option == item.answer
        picked = option
        rts.append(timer.elapsedMs)
        trials.append((difficulty, ok))
        if ok { correct += 1; SFX.play(.correct); Haptic.soft() } else { SFX.play(.gentle) }
        Task {
            try? await Task.sleep(nanoseconds: ok ? 600_000_000 : 1_400_000_000) // show the right answer on a miss
            picked = nil
            timer.reset()
            if t + 1 < items.count {
                phase = .test(t + 1)
            } else {
                phase = .done
                let mean = rts.isEmpty ? 0 : rts.reduce(0, +) / Double(rts.count)
                onFinish(GameOutcome(correct: correct, total: items.count, meanRTms: mean,
                                     score: Double(correct) / Double(max(items.count, 1)), trials: trials))
            }
        }
    }
}

// MARK: Builders for the three pair tasks

enum PairBuilders {
    /// Course drills ask for a size; arcade drills adapt through the Rasch level.
    static func pairCount(_ ctx: GameContext) -> Int {
        if ctx.size > 0 { return ctx.size }
        return [4, 5, 6, 7, 8][min(max(ctx.level, 0), 4)]
    }

    static func distractors(answer: String, pool: [String], count: Int, seed: String) -> [String] {
        let others = pool.filter { $0 != answer }.shuffledSeeded(seed + answer)
        return ([answer] + others.prefix(count)).shuffledSeeded(seed + "opts" + answer)
    }

    static func faceName(_ ctx: GameContext) -> [PairItem] {
        let villagers = Stimuli.villagers(count: pairCount(ctx), seed: ctx.seed)
        let names = villagers.map(\.name)
        return villagers.enumerated().map { i, v in
            PairItem(id: i, cue: AnyView(PixelSpriteView(art: v.art).clipShape(RoundedRectangle(cornerRadius: 8))),
                     cueLabel: "Portrait \(i + 1)", answer: v.name,
                     options: distractors(answer: v.name, pool: names, count: 3, seed: ctx.seed))
        }
    }

    static func runes(_ ctx: GameContext, color: Color) -> [PairItem] {
        let n = pairCount(ctx) + 1
        let runes = Stimuli.runeSet(count: n, seed: ctx.seed)
        let meanings = Array(Stimuli.runeMeanings.shuffledSeeded(ctx.seed + "-m").prefix(n))
        return runes.enumerated().map { i, r in
            PairItem(id: i, cue: AnyView(RuneView(rune: r, color: color)), cueLabel: "Rune \(i + 1)",
                     answer: meanings[i], options: distractors(answer: meanings[i], pool: meanings, count: 3, seed: ctx.seed))
        }
    }
}
