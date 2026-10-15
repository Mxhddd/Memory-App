import SwiftUI
import MemoryCore

/// Result of one game. `score` is task-specific but roughly 0…1 so trends are comparable over time.
struct GameOutcome {
    var correct: Int
    var total: Int
    var meanRTms: Double
    var score: Double
    /// Rasch trials (difficulty, correct) for adaptive training days.
    var trials: [(Double, Bool)] = []
}

/// Everything a game needs to know about this run.
struct GameContext {
    var task: RealmTask
    var seed: String
    var burst: (burst: Int, day: Int)?
    var level: Int           // 0…4 difficulty (fixed at 2 on burst days so measurement is constant)
    var gentle: Bool         // errorless-friendly pacing & sizes (Mom's default)
    var moonBell: Bool       // embed the prospective-memory cue
    var wordForm: Int = 0
    var delayedRecall: Bool = false

    var isMeasurement: Bool { burst != nil }
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

    static func level(for task: RealmTask, gentle: Bool) -> Int {
        var a = ability(for: task)
        a.target = gentle ? 0.9 : 0.75
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

// MARK: Prospective cue (Moon Bell)

/// Overlays a moon (or brass bell) that appears once, briefly, during another task.
/// The person was told at the start to tap it when it shows — a time/event-based intention.
struct MoonBellOverlay: ViewModifier {
    @Environment(\.theme) private var theme
    let active: Bool
    let gentle: Bool
    let onResult: (Bool) -> Void

    @State private var visible = false
    @State private var resolved = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if visible {
                    Button {
                        resolve(hit: true)
                    } label: {
                        Text(theme.id == .midnightRaccoon ? "🌙" : "🔔")
                            .font(.system(size: 44))
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(theme.raised))
                            .overlay(Circle().strokeBorder(theme.ornament, lineWidth: 3))
                    }
                    .accessibilityLabel(theme.id == .midnightRaccoon ? "Moon" : "Bell")
                    .padding(.top, 4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .task {
                guard active else { return }
                let delay = UInt64(Double.random(in: 12...28) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard !resolved else { return }
                withAnimation(.spring) { visible = true }
                SFX.play(.bell)
                try? await Task.sleep(nanoseconds: UInt64((gentle ? 9.0 : 6.0) * 1_000_000_000))
                if !resolved { resolve(hit: false) }
            }
    }

    private func resolve(hit: Bool) {
        guard !resolved else { return }
        resolved = true
        if hit { SFX.play(.shiny); Haptic.success() }
        withAnimation { visible = false }
        onResult(hit)
    }
}

extension View {
    func moonBell(active: Bool, gentle: Bool, onResult: @escaping (Bool) -> Void) -> some View {
        modifier(MoonBellOverlay(active: active, gentle: gentle, onResult: onResult))
    }
}
