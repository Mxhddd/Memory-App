import SwiftUI
import SwiftData
import MemoryCore

/// Countdown shown during encoding phases (soft limit: you can finish early).
struct EncodeTimer: View {
    @Environment(\.theme) private var theme
    let seconds: Int
    let onTimeUp: () -> Void
    @State private var remaining = 0

    var body: some View {
        Label(String(format: "%d:%02d", remaining / 60, remaining % 60), systemImage: "timer")
            .font(theme.bodyEmphasis.monospacedDigit())
            .foregroundStyle(remaining <= 10 ? theme.primary : theme.secondaryText)
            .task {
                remaining = seconds
                while remaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { return }
                    remaining -= 1
                }
                onTimeUp()
            }
            .accessibilityLabel("\(remaining) seconds left")
    }
}

/// One-at-a-time typed recall (memory-sports style): Enter moves to the next position.
struct SequentialRecall: View {
    @Environment(\.theme) private var theme
    let labels: [String]            // what each position is cued by ("Stop 3 · Sofa")
    let keyboard: UIKeyboardType
    let onDone: ([String]) -> Void

    @State private var answers: [String] = []
    @State private var current = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Walk your route and recall", progress: (answers.count, labels.count))
            if answers.count < labels.count {
                Text(labels[answers.count])
                    .font(theme.display(28))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                TextField("What was here?", text: $current)
                    .font(theme.display(28))
                    .multilineTextAlignment(.center)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.next)
                    .onSubmit(next)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                    .foregroundStyle(theme.text)
                HStack {
                    Button("Skip") { current = ""; next() }.buttonStyle(SecondaryButtonStyle())
                    Button("Next") { next() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            if !answers.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(answers.enumerated()), id: \.offset) { i, a in
                            Text("\(i + 1). \(a.isEmpty ? "—" : a)").font(theme.caption).foregroundStyle(theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
            Spacer(minLength: 0)
        }
        .onAppear { focused = true }
    }

    private func next() {
        answers.append(current.trimmingCharacters(in: .whitespaces))
        current = ""
        if answers.count >= labels.count { onDone(answers) } else { focused = true }
    }
}

// MARK: Word Sprint (and next-day retention)

struct WordSprintGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let palace: Palace?
    let retention: Bool
    let onFinish: (GameOutcome) -> Void

    @State private var index = 0
    @State private var recalling = false

    private var words: [String] { WordBank.sprint(count: ctx.size, seed: ctx.seed) }

    private func stopName(_ i: Int) -> String {
        if let palace, i < palace.stops.count { return "Stop \(i + 1) · \(palace.stops[i])" }
        return "Item \(i + 1)"
    }

    var body: some View {
        VStack(spacing: 18) {
            if recalling || retention {
                SequentialRecall(labels: words.indices.map(stopName), keyboard: .default) { answers in
                    let s = Loci.scoreWords(recalled: answers, targets: words)
                    onFinish(GameOutcome(correct: s.inPlace, total: s.total, meanRTms: 0, score: s.accuracy, level: ctx.size))
                }
            } else {
                HStack {
                    GameHeader(title: palace.map { "Place each word along \($0.name)" } ?? "Picture each word vividly", progress: (index + 1, words.count))
                    EncodeTimer(seconds: Course.encodingSeconds(kind: .wordSprint, size: words.count)) { recalling = true }
                }
                Spacer()
                Text(stopName(index)).font(theme.bodyEmphasis).foregroundStyle(theme.secondaryText)
                Text(words[index])
                    .font(theme.display(44))
                    .foregroundStyle(theme.text)
                    .id(index)
                Text("Make it big, moving and strange — interacting with the stop.")
                    .font(theme.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
                Spacer()
                HStack {
                    Button("Back") { index = max(0, index - 1) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(index == 0)
                    Button(index + 1 < words.count ? "Next" : "Recall now") {
                        Haptic.tap()
                        if index + 1 < words.count { index += 1 } else { recalling = true }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding()
    }
}

// MARK: Number Sprint (Major system)

struct NumberSprintGame: View {
    @Environment(\.theme) private var theme
    let ctx: GameContext
    let onFinish: (GameOutcome) -> Void

    @State private var recalling = false
    @State private var showPegs = false
    @State private var answer = ""
    @FocusState private var focused: Bool

    private var digits: String { MajorSystem.randomDigits(count: ctx.size, seed: ctx.seed) }

    var body: some View {
        VStack(spacing: 18) {
            if !recalling {
                HStack {
                    GameHeader(title: "Turn each pair into a picture", progress: nil)
                    EncodeTimer(seconds: Course.encodingSeconds(kind: .numberSprint, size: ctx.size)) { recalling = true }
                }
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(Array(MajorSystem.chunks(digits).enumerated()), id: \.offset) { _, chunk in
                            VStack(spacing: 4) {
                                Text(chunk).font(theme.display(30).monospacedDigit()).foregroundStyle(theme.text)
                                if showPegs, chunk.count == 2, let n = Int(chunk) {
                                    Text(MajorSystem.peg(n)).font(.caption).foregroundStyle(theme.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                        }
                    }
                }
                Toggle("Show peg words (training wheels)", isOn: $showPegs).tint(theme.primary).foregroundStyle(theme.text)
                Button("Recall now") { recalling = true }.buttonStyle(PrimaryButtonStyle())
            } else {
                GameHeader(title: "Type the number", progress: nil)
                Text("\(ctx.size) digits").font(theme.caption).foregroundStyle(theme.secondaryText)
                TextField("Digits", text: $answer)
                    .keyboardType(.numberPad)
                    .font(theme.display(30).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surface))
                    .foregroundStyle(theme.text)
                Text(MajorSystem.chunks(answer.filter(\.isNumber)).joined(separator: " "))
                    .font(theme.bodyEmphasis.monospacedDigit()).foregroundStyle(theme.secondaryText)
                Spacer()
                Button("Done") {
                    let s = Loci.scoreDigits(recalled: answer, target: digits)
                    onFinish(GameOutcome(correct: s.inPlace, total: s.total, meanRTms: 0, score: s.accuracy, level: ctx.size))
                }
                .buttonStyle(PrimaryButtonStyle())
                .onAppear { focused = true }
            }
        }
        .padding()
    }
}

// MARK: Route walk

struct RouteWalkGame: View {
    @Environment(\.theme) private var theme
    let palace: Palace
    let onFinish: (GameOutcome) -> Void

    @State private var order: [String] = []
    @State private var placed: [String] = []
    @State private var mistakes = 0
    @State private var wrongFlash: String?

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Tap \(palace.name)'s stops in order", progress: (placed.count, palace.stops.count))
            if let next = placed.last {
                Text("Last: \(next)").font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(order.filter { !placed.contains($0) }, id: \.self) { stop in
                        Button(stop) { tap(stop) }
                            .buttonStyle(ChoiceButtonStyle(state: wrongFlash == stop ? .wrong : .idle))
                    }
                }
            }
        }
        .padding()
        .onAppear { order = palace.stops.shuffled() }
    }

    private func tap(_ stop: String) {
        let expected = palace.stops[placed.count]
        if stop == expected {
            placed.append(stop)
            Haptic.tap()
            if placed.count == palace.stops.count {
                let correct = max(0, palace.stops.count - mistakes)
                onFinish(GameOutcome(correct: correct, total: palace.stops.count, meanRTms: 0,
                                     score: Double(correct) / Double(palace.stops.count), level: palace.stops.count))
            }
        } else {
            mistakes += 1
            wrongFlash = stop
            SFX.play(.gentle)
            Task { try? await Task.sleep(nanoseconds: 500_000_000); wrongFlash = nil }
        }
    }
}

// MARK: Lessons

struct LessonView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    let onDone: () -> Void
    @State private var page = 0
    @State private var buildingPalace = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TabView(selection: $page) {
                    ForEach(Array(lesson.pages.enumerated()), id: \.offset) { i, text in
                        ScrollView {
                            Text(text).font(theme.body).foregroundStyle(theme.text).padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tag(i)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Try it", systemImage: "sparkles").font(theme.bodyEmphasis).foregroundStyle(theme.ornament)
                        Text(lesson.exercise).font(theme.body).foregroundStyle(theme.text)
                        if lesson.id == "palace" || lesson.id == "second" {
                            Button("Build a palace now") { buildingPalace = true }.buttonStyle(SecondaryButtonStyle())
                        }
                        Spacer()
                    }
                    .tag(lesson.pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                ReadAloudButton(text: (lesson.pages + [lesson.exercise]).joined(separator: " "))
                Button(page < lesson.pages.count ? "Next" : "Got it") {
                    if page < lesson.pages.count { withAnimation { page += 1 } } else { onDone(); dismiss() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(ThemedBackground())
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $buildingPalace) { NavigationStack { PalaceEditor(palace: nil) }.environment(\.theme, theme) }
        }
    }
}
