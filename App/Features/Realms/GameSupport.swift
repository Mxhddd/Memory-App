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
