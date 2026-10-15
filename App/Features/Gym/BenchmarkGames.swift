import SwiftUI
import MemoryCore

/// Benchmark 1 — 30-word free recall (technique-free transfer test, alternate forms).
/// 5 minutes to study, 30 seconds of counting backwards, then recall in any order.
struct WordRecallBenchmark: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    private enum Phase { case study, distract, recall }
    @State private var phase: Phase = .study
    @State private var recalled: [String] = []
    @State private var entry = ""
    @FocusState private var focused: Bool

    private var words: [String] { WordBank.benchmarkForm(ctx.benchmarkForm) }

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .study:
                HStack {
                    GameHeader(title: "Study these 30 words any way you like", progress: nil)
                    EncodeTimer(seconds: 300) { phase = .distract }
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(words, id: \.self) { w in
                            Text(w).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                        }
                    }
                }
                Button("I'm done studying") { phase = .distract }.buttonStyle(PrimaryButtonStyle())
            case .distract:
                Spacer()
                Text("Count backwards from 100 in sevens, in your head.").font(theme.display(26)).foregroundStyle(theme.text).multilineTextAlignment(.center)
                EncodeTimer(seconds: 30) { phase = .recall }
                Spacer()
            case .recall:
                GameHeader(title: "Type every word you remember — any order", progress: nil)
                HStack {
                    TextField("Word", text: $entry)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.next)
                        .onSubmit(add)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                        .foregroundStyle(theme.text)
                    Button("Add", action: add).buttonStyle(.borderedProminent).tint(theme.primary)
                }
                Text("\(recalled.count) so far").font(theme.caption).foregroundStyle(theme.secondaryText)
                ScrollView {
                    FlowWords(words: recalled) { word in recalled.removeAll { $0 == word } }
                }
                Button("Finish") {
                    let s = Loci.scoreWords(recalled: recalled, targets: words)
                    onFinish(GameOutcome(correct: s.anyPlace, total: words.count, meanRTms: 0,
                                         score: Double(s.anyPlace) / Double(words.count), level: s.anyPlace))
                }
                .buttonStyle(PrimaryButtonStyle())
                .onAppear { focused = true }
            }
        }
        .padding()
    }

    private func add() {
        let w = entry.trimmingCharacters(in: .whitespaces)
        if !w.isEmpty && !recalled.contains(where: { AnswerMatch.normalize($0) == AnswerMatch.normalize(w) }) { recalled.append(w) }
        entry = ""
        focused = true
    }
}

/// Simple wrapping chip list.
struct FlowWords: View {
    @Environment(\.theme) private var theme
    let words: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(words, id: \.self) { w in
                Button { onRemove(w) } label: {
                    Label(w, systemImage: "xmark").font(theme.caption).labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .tint(theme.accent)
                .accessibilityLabel("Remove \(w)")
            }
        }
    }
}

/// Benchmark 2 — forward digit span: one digit per second, two trials per length.
struct DigitSpanGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    @State private var length = 3
    @State private var trial = 0
    @State private var showing: Int?
    @State private var entering = false
    @State private var answer = ""
    @State private var results: [(length: Int, correct: Bool)] = []
    @FocusState private var focused: Bool

    private var current: [Int] { DigitSpan.digits(length: length, seed: "\(ctx.seed)-t\(trial)") }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "Remember the digits in order · length \(length)", progress: nil)
            Spacer()
            if entering {
                TextField("Digits", text: $answer)
                    .keyboardType(.numberPad)
                    .font(theme.display(36).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                    .foregroundStyle(theme.text)
                    .onAppear { focused = true }
                Button("Done") { submit() }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text(showing.map(String.init) ?? " ").font(theme.display(80).monospacedDigit()).foregroundStyle(theme.text)
            }
            Spacer()
        }
        .padding()
        .task(id: "\(length)-\(trial)") { await present() }
    }

    private func present() async {
        entering = false
        answer = ""
        try? await Task.sleep(nanoseconds: 800_000_000)
        for d in current {
            if Task.isCancelled { return }
            showing = d
            try? await Task.sleep(nanoseconds: 800_000_000)
            showing = nil
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        entering = true
    }

    private func submit() {
        let ok = answer.filter(\.isNumber) == current.map(String.init).joined()
        results.append((length, ok))
        SFX.play(ok ? .correct : .gentle)
        if DigitSpan.shouldStop(results) || length >= 14 {
            let span = DigitSpan.span(results)
            onFinish(GameOutcome(correct: span, total: 14, meanRTms: 0, score: Double(span) / 14, level: span))
            return
        }
        let atLength = results.filter { $0.length == length }
        if atLength.count >= 2 { length += 1 }
        trial += 1
    }
}
