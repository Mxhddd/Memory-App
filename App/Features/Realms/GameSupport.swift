import SwiftUI
import MemoryCore

/// Result of one game. `score` is task-specific but roughly 0…1 so trends are comparable over time.
struct GameOutcome {
    var correct: Int
    var total: Int
    var meanRTms: Double
    var score: Double
    /// Rasch trials (difficulty, correct) for adaptive arcade drills.
    var trials: [(Double, Bool)] = []
    /// The level actually played (n-back n, span reached…), if different from the requested size.
    var level: Int? = nil
    /// Where an adaptive drill should start next time (n-back staircase).
    var nextLevel: Int? = nil
    /// The player's own prediction before recall, if asked.
    var prediction: Int? = nil
    /// Average seconds spent studying each item (sprints).
    var secondsPerItem: Double? = nil
}

/// Everything a game needs to know about this run.
struct GameContext {
    var task: RealmTask
    var seed: String
    var size: Int            // words, digits, stops, n-back level…
    var level: Int           // 0…4 adaptive difficulty for arcade drills
    var courseDay: Int
    var palaceID: UUID?
    var benchmarkForm: Int = 0
    var championForm: Int = 0
    var reviewOffset: Int = 0
    var isBenchmark: Bool = false
    /// The day this game belongs to (it was started then, even if it ends after midnight).
    var startedAt: Date = Date()
    /// Started from the Train tab rather than the day's plan.
    var isFreePlay: Bool = false
    /// Seconds of study per item from the encoding speed ladder (sprints).
    var pace: Double? = nil
}

/// Adaptive difficulty for training days: one Rasch ability per task, persisted locally.
enum DifficultyStore {
    static let levels = 0...4

    static func difficulty(ofLevel level: Int) -> Double { Double(level - 2) }

    static func ability(for task: RealmTask) -> RaschAbility {
        guard let data = UserDefaults.standard.data(forKey: "rasch.\(task.rawValue)"),
              let a = try? JSONDecoder().decode(RaschAbility.self, from: data) else { return RaschAbility(target: 0.75) }
        return a
    }

    static func save(_ ability: RaschAbility, for task: RealmTask) {
        if let data = try? JSONEncoder().encode(ability) { UserDefaults.standard.set(data, forKey: "rasch.\(task.rawValue)") }
    }

    static func level(for task: RealmTask) -> Int {
        var a = ability(for: task)
        a.target = 0.75
        return a.choose(from: Array(levels)) { difficulty(ofLevel: $0) } ?? 2
    }

    static func record(_ trials: [(Double, Bool)], for task: RealmTask) {
        var a = ability(for: task)
        for t in trials { a.record(difficulty: t.0, correct: t.1) }
        save(a, for: task)
    }
}

/// Times a single response.
struct ResponseTimer {
    private var start = Date()
    mutating func reset() { start = Date() }
    var elapsedMs: Double { Date().timeIntervalSince(start) * 1000 }
}

/// Simple header used inside games.
struct GameHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let progress: (Int, Int)?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(theme.bodyEmphasis)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let p = progress { ProgressPips(done: p.0, total: p.1) }
        }
    }
}

extension Array {
    func shuffledSeeded(_ seed: String) -> [Element] {
        var rng = SeededRandom(seed)
        return shuffled(using: &rng)
    }
}

/// Before recall: "how many do you think you'll get?" Guessing first, then seeing the real
/// score, trains metamemory — knowing what you know — and Progress charts how close you get.
struct PredictionStep: View {
    @Environment(\.theme) private var theme
    let total: Int
    let unit: String
    let question: String
    let onDone: (Int?) -> Void
    @State private var guess: Double = -1

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MascotView(mood: .studying, size: 84)
            Text("Before you recall").font(.caption.weight(.heavy)).tracking(1.1).foregroundStyle(theme.ornament)
            Text(question).font(theme.display(26)).foregroundStyle(theme.text).multilineTextAlignment(.center)
            Text("\(Int(max(guess, 0)))")
                .font(theme.display(64).monospacedDigit()).foregroundStyle(theme.primary)
                .contentTransition(.numericText())
                .accessibilityHidden(true)
            Slider(value: $guess, in: 0...Double(max(total, 1)), step: 1)
                .tint(theme.primary)
                .accessibilityLabel("Your guess")
                .accessibilityValue("\(Int(max(guess, 0))) of \(total) \(unit)")
            Text("of \(total) \(unit)").font(theme.caption).foregroundStyle(theme.secondaryText)
            Spacer()
            Button("That's my guess") { Haptic.tap(); onDone(Int(max(guess, 0))) }.buttonStyle(PrimaryButtonStyle())
            Button("Skip") { onDone(nil) }.font(theme.bodyEmphasis).foregroundStyle(theme.secondaryText)
                .frame(minHeight: theme.minTouch)
        }
        .padding()
        .onAppear { if guess < 0 { guess = (Double(total) * 0.5).rounded() } }
    }
}
