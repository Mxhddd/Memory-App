import SwiftUI
import MemoryCore

// MARK: Firefly Sequences / Constellations (working memory, adaptive span)

struct SequencesGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private let side = 4
    private let trialsTotal = 6

    @State private var span = 3
    @State private var maxSpan = 0
    @State private var trial = 0
    @State private var correctTrials = 0
    @State private var sequence: [Int] = []
    @State private var lit: Int?
    @State private var input: [Int] = []
    @State private var showing = true
    @State private var feedback: Bool?
    @State private var rng = SeededRandom("x")
    @State private var trials: [(Double, Bool)] = []

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: showing ? "Watch the order…" : "Now tap them in the same order", progress: (trial, trialsTotal))
            Text("Length \(span)")
                .font(theme.caption)
                .foregroundStyle(theme.secondaryText)
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: side), spacing: 10) {
                ForEach(0..<(side * side), id: \.self) { cell in
                    Button {
                        tap(cell)
                    } label: {
                        RoundedRectangle(cornerRadius: theme.cornerRadius)
                            .fill(cellColor(cell))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if lit == cell {
                                    Image(systemName: theme.id == .midnightRaccoon ? "sparkle" : "star.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(theme.id == .midnightRaccoon ? Color(hex: 0x17121F) : theme.onPrimary)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).strokeBorder(theme.outline.opacity(0.7), lineWidth: theme.pixelBorders ? 3 : 1))
                    }
                    .disabled(showing)
                    .accessibilityLabel("Cell \(cell + 1)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .task {
            rng = SeededRandom(ctx.seed)
            span = ctx.size > 1 ? ctx.size : 2 + ctx.level // resume from the last session's span
            await play()
        }
    }

    private func cellColor(_ cell: Int) -> Color {
        if lit == cell { return theme.ornament }
        if let feedback, !showing { return feedback ? theme.success.opacity(0.35) : theme.primary.opacity(0.25) }
        return input.contains(cell) ? theme.accent.opacity(0.5) : theme.surface
    }

    private func play() async {
        showing = true
        input = []
        feedback = nil
        sequence = Stimuli.sequence(length: span, gridCells: side * side, rng: &rng)
        try? await Task.sleep(nanoseconds: 600_000_000)
        let step: UInt64 = 700_000_000
        for c in sequence {
            lit = c
            SFX.play(.shiny)
            try? await Task.sleep(nanoseconds: step)
            lit = nil
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        showing = false
    }

    private func tap(_ cell: Int) {
        guard !showing, feedback == nil else { return }
        Haptic.tap()
        input.append(cell)
        let i = input.count - 1
        if input[i] != sequence[i] {
            finishTrial(ok: false)
        } else if input.count == sequence.count {
            finishTrial(ok: true)
        }
    }

    private func finishTrial(ok: Bool) {
        feedback = ok
        trials.append((DifficultyStore.difficulty(ofLevel: min(max(span - 2, 0), 4)), ok))
        if ok { correctTrials += 1; maxSpan = max(maxSpan, span); SFX.play(.correct) } else { SFX.play(.gentle) }
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            trial += 1
            span = ok ? min(span + 1, side * side) : max(2, span - 1)
            if trial >= trialsTotal {
                onFinish(GameOutcome(correct: correctTrials, total: trialsTotal, meanRTms: 0,
                                     score: Double(maxSpan) / 9, trials: trials, level: maxSpan, nextLevel: span))
            } else {
                await play()
            }
        }
    }
}

// MARK: Mochi's Stash / Cabinet of Curiosities (object–location)

struct StashGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private let side = 4
    private var itemCount: Int {
        min([4, 5, 6, 7, 8][min(max(ctx.level, 0), 4)], side * side - 2)
    }

    @State private var placements: [Stimuli.Placement] = []
    @State private var order: [Int] = []
    @State private var studying = true
    @State private var t = 0
    @State private var picked: Int?
    @State private var correct = 0
    @State private var timer = ResponseTimer()
    @State private var rts: [Double] = []

    var body: some View {
        VStack(spacing: 16) {
            if studying {
                GameHeader(title: theme.id == .midnightRaccoon ? "Mochi is hiding things… remember where!" : "Note where each treasure is placed", progress: nil)
            } else if t < order.count {
                let p = placements[order[t]]
                GameHeader(title: "Where is the \(p.name)?", progress: (t, order.count))
                StashItemView(placement: p, size: 72).accessibilityLabel(p.name)
            }
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: side), spacing: 8) {
                ForEach(0..<(side * side), id: \.self) { cell in
                    Button { choose(cell) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: theme.cornerRadius).fill(fill(cell))
                            if studying, let p = placements.first(where: { $0.cell == cell }) {
                                StashItemView(placement: p, size: 44)
                            }
                            if !studying, picked != nil, t < order.count, placements[order[t]].cell == cell {
                                StashItemView(placement: placements[order[t]], size: 44)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).strokeBorder(theme.outline.opacity(0.7), lineWidth: theme.pixelBorders ? 3 : 1))
                    }
                    .disabled(studying || picked != nil)
                    .accessibilityLabel("Spot \(cell + 1)")
                }
            }
            Spacer(minLength: 0)
            if studying {
                Button("Got it") { startTest() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .onAppear {
            placements = Stimuli.stash(count: itemCount, gridCells: side * side, seed: ctx.seed)
            order = Array(placements.indices).shuffledSeeded(ctx.seed + "-ask")
        }
    }

    private func fill(_ cell: Int) -> Color {
        guard let picked, t < order.count else { return theme.surface }
        if placements[order[t]].cell == cell { return theme.success.opacity(0.45) }
        if picked == cell { return theme.primary.opacity(0.3) }
        return theme.surface
    }

    private func startTest() {
        Haptic.tap()
        studying = false
        timer.reset()
    }

    private func choose(_ cell: Int) {
        guard !studying, picked == nil, t < order.count else { return }
        let ok = placements[order[t]].cell == cell
        picked = cell
        rts.append(timer.elapsedMs)
        if ok { correct += 1; SFX.play(.correct) } else { SFX.play(.gentle) }
        Task {
            try? await Task.sleep(nanoseconds: ok ? 600_000_000 : 1_300_000_000)
            picked = nil
            t += 1
            timer.reset()
            if t >= order.count {
                let mean = rts.isEmpty ? 0 : rts.reduce(0, +) / Double(rts.count)
                let d = DifficultyStore.difficulty(ofLevel: ctx.level)
                onFinish(GameOutcome(correct: correct, total: order.count, meanRTms: mean,
                                     score: Double(correct) / Double(max(order.count, 1)),
                                     trials: Array(repeating: (d, true), count: correct) + Array(repeating: (d, false), count: order.count - correct)))
            }
        }
    }
}

/// Pixel sprite for a stash object (falls back to the emoji if a sprite is missing).
struct StashItemView: View {
    let placement: Stimuli.Placement
    var size: CGFloat = 44

    var body: some View {
        if let art = Sprites.stashItems[placement.name] {
            PixelSpriteView(art: art).frame(width: size, height: size)
        } else {
            Text(placement.emoji).font(.system(size: size * 0.75))
        }
    }
}
