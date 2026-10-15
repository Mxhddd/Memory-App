import SwiftUI
import MemoryCore

// MARK: Firefly Sequences / Constellations (working memory, adaptive span)

struct SequencesGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private var side: Int { ctx.gentle ? 3 : 4 }
    private var trialsTotal: Int { ctx.gentle ? 5 : 6 }

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
                            .overlay(Text(lit == cell ? (theme.id == .midnightRaccoon ? "✨" : "★") : "").font(.system(size: 30)))
                            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).strokeBorder(theme.outline.opacity(0.7), lineWidth: theme.pixelBorders ? 3 : 1))
                    }
                    .disabled(showing)
                    .accessibilityLabel("Cell \(cell + 1)")
                }
            }
            .padding(.horizontal, ctx.gentle ? 8 : 0)
            Spacer(minLength: 0)
        }
        .padding()
        .task {
            rng = SeededRandom(ctx.seed)
            span = ctx.isMeasurement ? 3 : 2 + ctx.level
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
        let step: UInt64 = ctx.gentle ? 900_000_000 : 700_000_000
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
                                     score: Double(maxSpan) / 9, trials: trials))
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

    private var side: Int { ctx.gentle ? 3 : 4 }
    private var itemCount: Int {
        let base = [3, 4, 5, 6, 7][min(max(ctx.level, 0), 4)]
        return min(ctx.gentle ? base - 1 : base, side * side - 2)
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
                Text(p.emoji).font(.system(size: 64)).accessibilityLabel(p.name)
            }
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: side), spacing: 8) {
                ForEach(0..<(side * side), id: \.self) { cell in
                    Button { choose(cell) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: theme.cornerRadius).fill(fill(cell))
                            if studying, let p = placements.first(where: { $0.cell == cell }) {
                                Text(p.emoji).font(.system(size: 34))
                            }
                            if !studying, picked != nil, t < order.count, placements[order[t]].cell == cell {
                                Text(placements[order[t]].emoji).font(.system(size: 34))
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

// MARK: Rune Sort / Seal Matching (processing speed — digit–symbol style)

struct RuneSortGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private var keySize: Int { ctx.isMeasurement ? 6 : [4, 5, 6, 7, 8][min(max(ctx.level, 0), 4)] }
    private var duration: Double { ctx.gentle ? 60 : 45 }

    @State private var runes: [[[Bool]]] = []
    @State private var current = 0
    @State private var correct = 0
    @State private var attempts = 0
    @State private var rts: [Double] = []
    @State private var timer = ResponseTimer()
    @State private var remaining: Double = 45
    @State private var flash: Bool?
    @State private var rng = SeededRandom("r")
    @State private var finished = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Match the rune to its number").font(theme.bodyEmphasis).foregroundStyle(theme.secondaryText)
                Spacer()
                Text("\(Int(remaining.rounded(.up)))s").font(theme.bodyEmphasis.monospacedDigit()).foregroundStyle(theme.text)
            }
            // Key
            HStack(spacing: 6) {
                ForEach(runes.indices, id: \.self) { i in
                    VStack(spacing: 2) {
                        RuneView(rune: runes[i], color: theme.text).frame(width: 34, height: 34)
                        Text("\(i + 1)").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .themedCard(raised: true)
            Spacer(minLength: 0)
            if !runes.isEmpty {
                RuneView(rune: runes[current], color: flash == nil ? theme.text : (flash! ? theme.success : theme.primary))
                    .frame(width: 140, height: 140)
                    .themedCard()
                    .frame(width: 180)
            }
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: min(keySize, 4)), spacing: 10) {
                ForEach(0..<runes.count, id: \.self) { i in
                    Button("\(i + 1)") { answer(i) }
                        .buttonStyle(ChoiceButtonStyle())
                        .disabled(finished)
                }
            }
        }
        .padding()
        .task {
            rng = SeededRandom(ctx.seed)
            runes = Stimuli.runeSet(count: keySize, seed: ctx.seed)
            remaining = duration
            next()
            let start = Date()
            while !finished {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                remaining = max(0, duration - Date().timeIntervalSince(start))
                if remaining <= 0 { end() }
            }
        }
    }

    private func next() {
        var n = Int.random(in: 0..<max(runes.count, 1), using: &rng)
        if n == current && runes.count > 1 { n = (n + 1) % runes.count }
        current = n
        timer.reset()
    }

    private func answer(_ i: Int) {
        guard !finished else { return }
        attempts += 1
        rts.append(timer.elapsedMs)
        let ok = i == current
        if ok { correct += 1; Haptic.tap() } else { Haptic.soft() }
        flash = ok
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            flash = nil
        }
        next()
    }

    private func end() {
        guard !finished else { return }
        finished = true
        let perMinute = Double(correct) / (duration / 60)
        let mean = rts.isEmpty ? 0 : rts.reduce(0, +) / Double(rts.count)
        let d = DifficultyStore.difficulty(ofLevel: ctx.level)
        // ~60 correct/min is excellent on a phone; scale to roughly 0…1.
        onFinish(GameOutcome(correct: correct, total: max(attempts, 1), meanRTms: mean, score: min(perMinute / 60, 1),
                             trials: [(d, attempts > 0 && Double(correct) / Double(attempts) >= 0.9 && perMinute >= 25)]))
    }
}
