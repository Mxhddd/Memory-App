import SwiftUI
import SwiftData
import MemoryCore

/// Countdown shown during encoding phases (soft limit: you can finish early). It runs on wall-clock
/// time, so it keeps counting if the phone locks or you switch apps, and the Live Activity and
/// Dynamic Island show the same countdown.
struct EncodeTimer: View {
    @Environment(\.theme) private var theme
    let seconds: Int
    var label: String = "Study time"
    let onTimeUp: () -> Void
    @State private var end: Date?
    @State private var fired = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let deadline = end ?? context.date.addingTimeInterval(Double(seconds))
            let remaining = max(0, Int(deadline.timeIntervalSince(context.date).rounded(.up)))
            Label(String(format: "%d:%02d", remaining / 60, remaining % 60), systemImage: "timer")
                .font(theme.bodyEmphasis.monospacedDigit())
                .foregroundStyle(remaining <= 10 ? theme.primary : theme.secondaryText)
                .accessibilityLabel("\(remaining) seconds left")
                .onChange(of: remaining) { _, left in
                    guard left == 0, !fired, end != nil else { return }
                    fired = true
                    LiveActivityService.clearCountdown()
                    onTimeUp()
                }
        }
        .onAppear {
            guard end == nil else { return }
            let deadline = Date().addingTimeInterval(Double(seconds))
            end = deadline
            LiveActivityService.showCountdown(until: deadline, label: label)
        }
        .onDisappear { LiveActivityService.clearCountdown() }
    }
}

/// One-at-a-time typed recall (memory-sports style): Enter moves to the next position.
struct SequentialRecall: View {
    @Environment(\.theme) private var theme
    let labels: [String]            // what each position is cued by ("Stop 3 · Sofa")
    let keyboard: UIKeyboardType
    var mapStops: [String]? = nil   // when set, answers appear on the palace map instead of a list
    let onDone: ([String]) -> Void

    @State private var answers: [String] = []
    @State private var current = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Walk your route and recall", progress: mapStops == nil ? (answers.count, labels.count) : nil)
            if let mapStops {
                PalaceMapView(stops: mapStops, current: min(answers.count, mapStops.count - 1),
                              marks: Dictionary(uniqueKeysWithValues: answers.enumerated().map { ($0.offset, $0.element.isEmpty ? PalaceMapView.Mark.missed : PalaceMapView.Mark.placed) }),
                              labels: Dictionary(uniqueKeysWithValues: answers.enumerated().map { ($0.offset, $0.element.isEmpty ? "—" : $0.element) }),
                              viewport: 200)
            }
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
                    .background(theme.shape(step: 6, radius: 18).fill(theme.surface))
                    .foregroundStyle(theme.text)
                HStack {
                    Button("Skip") { current = ""; next() }.buttonStyle(SecondaryButtonStyle())
                    Button("Next") { next() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            if !answers.isEmpty && mapStops == nil {
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
    @State private var predicted = false
    @State private var prediction: Int?
    @State private var studyStart = Date()
    @State private var secondsPerItem: Double?

    private var words: [String] { WordBank.sprint(count: ctx.size, seed: ctx.seed) }

    private func beginRecall() {
        guard !recalling else { return }
        secondsPerItem = Date().timeIntervalSince(studyStart) / Double(max(words.count, 1))
        recalling = true
    }

    /// The palace stops this sprint walks, or nil without a palace.
    private var mapStops: [String]? {
        guard let palace, palace.stops.count >= words.count else { return nil }
        return Array(palace.stops.prefix(words.count))
    }

    private func stopName(_ i: Int) -> String {
        if let palace, i < palace.stops.count { return "Stop \(i + 1) · \(palace.stops[i])" }
        return "Item \(i + 1)"
    }

    var body: some View {
        VStack(spacing: 18) {
            if (recalling || retention) && !predicted {
                PredictionStep(total: words.count, unit: "words",
                               question: retention ? "How many of these \(words.count) words are still there?" : "How many of the \(words.count) words will you get in place?") {
                    prediction = $0
                    predicted = true
                }
            } else if recalling || retention {
                SequentialRecall(labels: words.indices.map(stopName), keyboard: .default, mapStops: mapStops) { answers in
                    let s = Loci.scoreWords(recalled: answers, targets: words)
                    onFinish(GameOutcome(correct: s.inPlace, total: s.total, meanRTms: 0, score: s.accuracy, level: ctx.size,
                                         prediction: prediction, secondsPerItem: retention ? nil : secondsPerItem))
                }
            } else {
                HStack {
                    GameHeader(title: palace.map { "Place each word along \($0.name)" } ?? "Picture each word vividly", progress: (index + 1, words.count))
                    EncodeTimer(seconds: Course.encodingSeconds(kind: .wordSprint, size: words.count, pace: ctx.pace ?? EncodingPace.start(.wordSprint))) { beginRecall() }
                }
                if let mapStops {
                    PalaceMapView(stops: mapStops, current: index,
                                  marks: Dictionary(uniqueKeysWithValues: (0..<index).map { ($0, PalaceMapView.Mark.placed) }),
                                  labels: Dictionary(uniqueKeysWithValues: (0..<index).map { ($0, "•") }),
                                  viewport: 190)
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
                        if index + 1 < words.count { index += 1 } else { beginRecall() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding()
        .onAppear { studyStart = Date() }
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
    @State private var predicted = false
    @State private var prediction: Int?
    @State private var studyStart = Date()
    @State private var secondsPerItem: Double?
    @FocusState private var focused: Bool

    private var digits: String { MajorSystem.randomDigits(count: ctx.size, seed: ctx.seed) }

    private func beginRecall() {
        guard !recalling else { return }
        secondsPerItem = Date().timeIntervalSince(studyStart) / Double(max(ctx.size, 1))
        recalling = true
    }

    var body: some View {
        VStack(spacing: 18) {
            if !recalling {
                HStack {
                    GameHeader(title: "Turn each pair into a picture", progress: nil)
                    EncodeTimer(seconds: Course.encodingSeconds(kind: .numberSprint, size: ctx.size, pace: ctx.pace ?? EncodingPace.start(.numberSprint))) { beginRecall() }
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
                Button("Recall now") { beginRecall() }.buttonStyle(PrimaryButtonStyle())
            } else if !predicted {
                PredictionStep(total: ctx.size, unit: "digits", question: "How many of the \(ctx.size) digits will you get in place?") {
                    prediction = $0
                    predicted = true
                }
            } else {
                GameHeader(title: "Type the number", progress: nil)
                Text("\(ctx.size) digits").font(theme.caption).foregroundStyle(theme.secondaryText)
                TextField("Digits", text: $answer)
                    .keyboardType(.numberPad)
                    .font(theme.display(30).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(14)
                    .background(theme.shape(step: 6, radius: 18).fill(theme.surface))
                    .foregroundStyle(theme.text)
                Text(MajorSystem.chunks(answer.filter(\.isNumber)).joined(separator: " "))
                    .font(theme.bodyEmphasis.monospacedDigit()).foregroundStyle(theme.secondaryText)
                Spacer()
                Button("Done") {
                    let s = Loci.scoreDigits(recalled: answer, target: digits)
                    onFinish(GameOutcome(correct: s.inPlace, total: s.total, meanRTms: 0, score: s.accuracy, level: ctx.size,
                                         prediction: prediction, secondsPerItem: secondsPerItem))
                }
                .buttonStyle(PrimaryButtonStyle())
                .onAppear { focused = true }
            }
        }
        .padding()
        .onAppear { studyStart = Date() }
    }
}

// MARK: Route walk

struct RouteWalkGame: View {
    @Environment(\.theme) private var theme
    let palace: Palace
    let onFinish: (GameOutcome) -> Void

    /// Stops are tracked by position, so two stops with the same name never block the walk.
    @State private var order: [Int] = []
    @State private var placed: [Int] = []
    @State private var mistakes = 0
    @State private var wrongFlash: Int?

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Tap \(palace.name)'s stops in order", progress: nil)
            HStack {
                Text(placed.count < palace.stops.count ? "Which is stop \(placed.count + 1)?" : "Walked the whole route")
                    .font(theme.bodyEmphasis).foregroundStyle(theme.text)
                Spacer()
                Text(mistakes == 0 ? "No slips" : "\(mistakes) slip\(mistakes == 1 ? "" : "s")")
                    .font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
            }
            PalaceMapView(stops: palace.stops, current: min(placed.count, palace.stops.count - 1),
                          marks: Dictionary(uniqueKeysWithValues: placed.indices.map { ($0, PalaceMapView.Mark.correct) }),
                          hideAhead: true, viewport: 200)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(order.filter { !placed.contains($0) }, id: \.self) { index in
                        Button(palace.stops[index]) { tap(index) }
                            .buttonStyle(ChoiceButtonStyle(state: wrongFlash == index ? .wrong : .idle))
                    }
                }
            }
        }
        .padding()
        .onAppear { order = Array(palace.stops.indices).shuffled() }
    }

    private func tap(_ index: Int) {
        guard placed.count < palace.stops.count else { return }
        // A stop with the same name as the expected one counts too.
        if palace.stops[index] == palace.stops[placed.count] {
            placed.append(index)
            Haptic.tap()
            if placed.count == palace.stops.count {
                let correct = max(0, palace.stops.count - mistakes)
                onFinish(GameOutcome(correct: correct, total: palace.stops.count, meanRTms: 0,
                                     score: Double(correct) / Double(palace.stops.count), level: palace.stops.count))
            }
        } else {
            mistakes += 1
            wrongFlash = index
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
