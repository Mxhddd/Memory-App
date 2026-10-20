import SwiftUI
import MemoryCore

// MARK: Dual n-back

/// Jaeggi-style dual n-back: a square on a 3×3 grid + a spoken letter every 3 s.
/// Tap POSITION when the square matches n steps back, SOUND when the letter does.
struct DualNBackGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let blocks: Int
    let showLetters: Bool
    let onFinish: (GameOutcome) -> Void

    @State private var n = 2
    @State private var block = 0
    @State private var trials: [NBackTrial] = []
    @State private var index = -1
    @State private var lit: Int?
    @State private var letter: String?
    @State private var responses: [NBackResponse] = []
    @State private var pressed = NBackResponse()
    @State private var between: String?
    @State private var hits = 0
    @State private var targets = 0
    @State private var maxN = 0
    @State private var runner: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "\(n)-back · block \(min(block + 1, blocks)) of \(blocks)", progress: (max(index, 0), trials.count))
            if let between {
                Spacer()
                Text(between).font(theme.display(28)).foregroundStyle(theme.text).multilineTextAlignment(.center)
                Spacer()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(0..<9, id: \.self) { cell in
                        theme.shape(step: 6, radius: 18)
                            .fill(lit == cell ? theme.primary : theme.surface)
                            .aspectRatio(1, contentMode: .fit)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: 320)
                Text(showLetters ? (letter ?? " ") : " ")
                    .font(theme.display(34)).foregroundStyle(theme.text)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button { pressed.position = true; Haptic.tap() } label: {
                        Label("Position", systemImage: "square.grid.3x3.fill").frame(maxWidth: .infinity, minHeight: 72)
                    }
                    .buttonStyle(ChoiceButtonStyle(state: pressed.position ? .selected : .idle))
                    Button { pressed.letter = true; Haptic.tap() } label: {
                        Label("Sound", systemImage: "speaker.wave.2.fill").frame(maxWidth: .infinity, minHeight: 72)
                    }
                    .buttonStyle(ChoiceButtonStyle(state: pressed.letter ? .selected : .idle))
                }
            }
        }
        .padding()
        .onAppear {
            n = max(1, ctx.size)
            runner = Task { await run() }
        }
        .onDisappear { runner?.cancel() }
    }

    private func run() async {
        for b in 0..<blocks {
            block = b
            between = "\(n)-back\nGet ready…"
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            between = nil
            trials = NBack.block(n: n, seed: "\(ctx.seed)-b\(b)")
            responses = []
            maxN = max(maxN, n)
            for (i, t) in trials.enumerated() {
                if Task.isCancelled { return }
                index = i
                pressed = NBackResponse()
                lit = t.position
                letter = t.letter
                Speech.shared.say(t.letter)
                try? await Task.sleep(nanoseconds: 500_000_000)
                lit = nil
                letter = nil
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                responses.append(pressed)
            }
            if Task.isCancelled { return }
            let score = NBack.score(trials, responses: responses)
            hits += score.hits
            targets += score.targets
            let next = NBack.nextLevel(current: n, score: score)
            between = "\(score.hits)/\(score.targets) caught\n" + (next > n ? "Level up → \(next)-back" : next < n ? "Easing to \(next)-back" : "Staying at \(n)-back")
            SFX.play(next > n ? .levelup : .correct)
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            n = next
        }
        if Task.isCancelled { return }
        onFinish(GameOutcome(correct: hits, total: max(targets, 1), meanRTms: 0,
                             score: targets > 0 ? Double(hits) / Double(targets) : 0, level: maxN, nextLevel: n))
    }
}

// MARK: Operation span

struct ComplexSpanGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private enum Phase: Equatable { case equation, letter, recall, done }
    @State private var sizes: [Int] = []
    @State private var sets: [[SpanItem]] = []
    @State private var setIndex = 0
    @State private var itemIndex = 0
    @State private var phase: Phase = .equation
    @State private var recalled: [[String]] = []
    @State private var picks: [String] = []
    @State private var processingCorrect = 0
    @State private var processingTotal = 0
    @State private var equationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Remember the letters · check the maths", progress: (setIndex, max(sets.count, 1)))
            if sets.indices.contains(setIndex) {
                let item = sets[setIndex][min(itemIndex, sets[setIndex].count - 1)]
                switch phase {
                case .equation:
                    Spacer()
                    Text(item.equation).font(theme.display(40).monospacedDigit()).foregroundStyle(theme.text)
                    Spacer()
                    HStack(spacing: 12) {
                        Button("False") { judge(false) }.buttonStyle(SecondaryButtonStyle())
                        Button("True") { judge(true) }.buttonStyle(PrimaryButtonStyle())
                    }
                case .letter:
                    Spacer()
                    Text(item.letter).font(theme.display(72)).foregroundStyle(theme.primary)
                    Spacer()
                case .recall:
                    Text("Tap the letters in order").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    Text(picks.isEmpty ? " " : picks.joined(separator: " "))
                        .font(theme.display(32)).foregroundStyle(theme.text)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(ComplexSpan.letters, id: \.self) { l in
                            Button(l) { if picks.count < sets[setIndex].count { picks.append(l); Haptic.tap() } }
                                .buttonStyle(ChoiceButtonStyle(state: picks.contains(l) ? .selected : .idle))
                        }
                    }
                    HStack {
                        Button("Clear") { picks = [] }.buttonStyle(SecondaryButtonStyle())
                        Button("Done") { finishSet() }.buttonStyle(PrimaryButtonStyle())
                    }
                case .done:
                    ProgressView()
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .onAppear {
            sizes = ComplexSpan.setSizes(minSize: 3, maxSize: 6, seed: ctx.seed)
            sets = sizes.enumerated().map { ComplexSpan.set(size: $0.element, seed: "\(ctx.seed)-\($0.offset)") }
            startEquation()
        }
        .onDisappear { equationTask?.cancel() }
    }

    private func startEquation() {
        phase = .equation
        equationTask?.cancel()
        equationTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000) // too slow counts as wrong
            if !Task.isCancelled && phase == .equation { judgeTimedOut() }
        }
    }

    private func judge(_ answer: Bool) {
        equationTask?.cancel()
        let item = sets[setIndex][itemIndex]
        processingTotal += 1
        if answer == item.equationIsTrue { processingCorrect += 1 }
        showLetter()
    }

    private func judgeTimedOut() {
        processingTotal += 1
        showLetter()
    }

    private func showLetter() {
        phase = .letter
        equationTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            itemIndex += 1
            if itemIndex >= sets[setIndex].count { phase = .recall; picks = [] } else { startEquation() }
        }
    }

    private func finishSet() {
        recalled.append(picks)
        setIndex += 1
        itemIndex = 0
        if setIndex >= sets.count {
            phase = .done
            let s = ComplexSpan.score(sets: sets, recalled: recalled, processingCorrect: processingCorrect, processingTotal: processingTotal)
            onFinish(GameOutcome(correct: s.absolute, total: sizes.reduce(0, +), meanRTms: 0,
                                 score: s.valid ? s.partialCredit : s.partialCredit * 0.5, level: s.absolute))
        } else {
            startEquation()
        }
    }
}
