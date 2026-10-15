import SwiftUI
import MemoryCore

/// 12-word list: paced study, then tap-to-select recognition (12 targets + 12 foils).
/// A 20-minute delayed recall is scheduled afterwards (`DelayedRecall`).
struct WordListGame: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private enum Phase: Equatable { case study(Int), test, done }
    @State private var phase: Phase = .study(0)
    @State private var selected: Set<String> = []
    @State private var studyTask: Task<Void, Never>?

    private var targets: [String] { Stimuli.wordList(form: ctx.wordForm) }
    private var board: [String] {
        Stimuli.recognitionBoard(targets: targets, seed: ctx.seed + (ctx.delayedRecall ? "-delayed" : "-immediate"))
    }

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .study(let i):
                GameHeader(title: "Remember these words", progress: (i + 1, targets.count))
                Spacer()
                Text(targets[i])
                    .font(theme.display(44))
                    .foregroundStyle(theme.text)
                    .id(i)
                    .transition(reduceMotion ? .identity : .opacity)
                Spacer()
                Text("Tip: picture each one in a silly scene.")
                    .font(theme.caption)
                    .foregroundStyle(theme.secondaryText)

            case .test:
                GameHeader(title: ctx.delayedRecall ? "Which words were on the list earlier?" : "Tap every word that was on the list", progress: nil)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(board, id: \.self) { word in
                            Button(word) {
                                Haptic.tap()
                                if selected.contains(word) { selected.remove(word) } else { selected.insert(word) }
                            }
                            .buttonStyle(ChoiceButtonStyle(state: selected.contains(word) ? .selected : .idle))
                            .accessibilityAddTraits(selected.contains(word) ? .isSelected : [])
                        }
                    }
                }
                Button("Done (\(selected.count) picked)") { finish() }
                    .buttonStyle(PrimaryButtonStyle())

            case .done:
                ProgressView()
            }
        }
        .padding()
        .onAppear { if ctx.delayedRecall { phase = .test } else { runStudy() } }
        .onDisappear { studyTask?.cancel() }
    }

    private func runStudy() {
        let perWord: UInt64 = ctx.gentle ? 3_000_000_000 : 2_200_000_000
        studyTask = Task {
            for i in 0..<targets.count {
                withAnimation(.easeInOut(duration: 0.25)) { phase = .study(i) }
                if ctx.gentle { Speech.shared.say(targets[i]) }
                try? await Task.sleep(nanoseconds: perWord)
                if Task.isCancelled { return }
            }
            phase = .test
        }
    }

    private func finish() {
        let targetSet = Set(targets)
        let hits = selected.intersection(targetSet).count
        let falseAlarms = selected.subtracting(targetSet).count
        phase = .done
        // Corrected recognition: hits − false alarms, scaled to 0…1.
        let score = max(0, Double(hits - falseAlarms)) / Double(targets.count)
        onFinish(GameOutcome(correct: hits, total: targets.count, meanRTms: 0, score: score))
    }
}

/// Pending 20-minute delayed recall, remembered across app launches.
enum DelayedRecall {
    struct Pending: Codable {
        var form: Int
        var seed: String
        var studiedAt: Date
        var burst: Int
        var burstDay: Int
    }

    private static let key = "delayedRecall.pending"
    static let delay: TimeInterval = 20 * 60
    static let window: TimeInterval = 3 * 60 * 60

    static var pending: Pending? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(Pending.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// Ready between 20 minutes and 3 hours after study; expires silently after that.
    static func ready(now: Date = Date()) -> Pending? {
        guard let p = pending else { return nil }
        let age = now.timeIntervalSince(p.studiedAt)
        if age > window { pending = nil; return nil }
        return age >= delay ? p : nil
    }
}
