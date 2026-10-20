import SwiftUI
import SwiftData
import MemoryCore

/// "The grounds": the 42-day course as a winding trail, then free practice as medallions —
/// the palace wing, the working-memory gym and the arcade. No stacked list boxes.
struct TrainView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var playing: GameContext?
    @State private var palaceCount = 0
    @State private var why: WhyTopic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Train").font(.caption.weight(.heavy)).tracking(1.2).foregroundStyle(theme.ornament)
                    Text("The grounds").font(theme.display(34)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                    Text(profile.courseDay > Course.length ? "Course complete — keep the skills warm" : "Course day \(profile.courseDay) of \(Course.length)")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Palace wing").font(theme.display(26)).foregroundStyle(theme.text)
                        Spacer()
                        Text("Week \(min((profile.courseDay - 1) / 7 + 1, 6)) of 6")
                            .font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(theme.pill.fill(theme.ornament.opacity(0.14)))
                    }
                    CourseTrail(day: profile.courseDay)
                    HStack(spacing: 10) {
                        NavigationLink { PalaceListView() } label: {
                            Label(palaceCount == 0 ? "Palaces" : "\(palaceCount) palace\(palaceCount == 1 ? "" : "s")", systemImage: "building.columns.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        NavigationLink { LessonList(profile: profile) } label: {
                            Label("Lessons \(profile.lessonsRead.count)/\(Course.lessons.count)", systemImage: "book.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                medallions("Palace drills", sub: "Free practice — the course sets your daily drills", topic: .palace, [
                    (.wordSprint, profile.wordLevel, "\(profile.wordLevel) words"),
                    (.numberSprint, profile.digitLevel, "\(profile.digitLevel) digits"),
                    (.routeWalk, 0, palaceCount == 0 ? "No palace yet" : "Walk a palace"),
                ])
                medallions("Working-memory gym", sub: "Holding and juggling information", topic: .gym, [
                    (.dualNBack, profile.nBackLevel, "\(profile.nBackLevel)-back"),
                    (.complexSpan, 0, "Letters + sums"),
                    (.sequences, 0, "Span \(profile.sequenceSpan)"),
                ])
                medallions("Arcade", sub: "Binding things together", topic: .arcade, [
                    (.faceName, 0, "Names"),
                    (.ancientRunes, 0, "Symbols"),
                    (.stash, 0, "Places"),
                ])
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ThemedBackground())
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { palaceCount = Quest.palaces().count }
        .sheet(item: $why) { topic in WhySheet(topic: topic).environment(\.theme, theme) }
        .fullScreenCover(item: Binding(get: { playing.map(GameItem.init) }, set: { if $0 == nil { playing = nil } })) { item in
            GameHost(ctx: item.ctx, profile: profile) { _ in playing = nil }
                .environment(\.theme, theme)
        }
    }

    private func medallions(_ title: String, sub: String, topic: WhyTopic, _ drills: [(RealmTask, Int, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(theme.display(24)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                    Text(sub).font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Button { why = topic } label: {
                    Image(systemName: "info.circle").font(.title3).foregroundStyle(theme.ornament)
                        .frame(width: theme.minTouch, height: theme.minTouch)
                }
                .accessibilityLabel("Why \(title.lowercased()) works")
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(drills, id: \.0) { drill in
                    Button { start(drill.0, size: drill.1) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: StepText.symbol(QuestStep(kind: .task(drill.0, size: drill.1), done: false)))
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(theme.pixelBorders ? theme.accent : theme.primary)
                                .frame(width: 72, height: 72)
                                .background(theme.shape(step: 8, radius: 36).fill(theme.pixelBorders ? theme.raised : theme.surface))
                                .shadow(color: theme.pixelBorders ? .clear : Color(hex: 0x1E2A44).opacity(0.1), radius: 11, y: 10)
                            Text(theme.copy.realmName(drill.0))
                                .font(.subheadline.weight(.bold)).foregroundStyle(theme.text)
                                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                            Text(drill.2)
                                .font(.caption.weight(.bold)).foregroundStyle(theme.ornament)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(theme.pill.fill(theme.ornament.opacity(0.14)))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.copy.realmName(drill.0)), \(drill.2)")
                }
            }
        }
    }

    private func start(_ task: RealmTask, size: Int) {
        Haptic.tap()
        var ctx = Quest.context(for: task, size: size, profile: profile)
        ctx.seed += "-free\(Int(Date().timeIntervalSince1970))" // free practice gets fresh material
        ctx.isFreePlay = true
        if task == .routeWalk { ctx.size = Quest.palaces().first(where: { $0.id == ctx.palaceID })?.stops.count ?? 0 }
        playing = ctx
    }
}

/// The 42-day course as a winding trail: a row per week, snaking left and right, with the
/// mascot standing on today's stone.
struct CourseTrail: View {
    @Environment(\.theme) private var theme
    let day: Int

    private let cols = 7

    var body: some View {
        GeometryReader { geo in
            let gap = (geo.size.width - 44) / CGFloat(cols - 1)
            let pts = (0..<Course.length).map { point($0, gap: gap) }
            let current = min(max(day, 1), Course.length) - 1
            ZStack(alignment: .topLeading) {
                path(pts).stroke(theme.hairline, style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 2, lineCap: .round, dash: theme.pixelBorders ? [5, 5] : [2, 6]))
                path(Array(pts.prefix(current + 1))).stroke(theme.primary, style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 2, lineCap: .round, dash: theme.pixelBorders ? [5, 5] : [2, 6]))
                ForEach(0..<6, id: \.self) { week in
                    Text("W\(week + 1)").font(.caption2.weight(.bold)).foregroundStyle(theme.secondaryText.opacity(0.8))
                        .position(x: geo.size.width - 8, y: pts[week * cols].y - 14)
                }
                ForEach(0..<Course.length, id: \.self) { i in
                    stone(i < current ? .done : i == current ? .today : .ahead)
                        .position(pts[i])
                }
                Text("\(current + 1)").font(.system(size: 10, weight: .heavy)).foregroundStyle(theme.onPrimary)
                    .position(pts[current])
                MascotView(mood: .idle, size: 30).position(x: pts[current].x, y: pts[current].y - 28)
            }
        }
        .frame(height: 6 * 44 + 30)
        .accessibilityElement()
        .accessibilityLabel("Course map: day \(day) of \(Course.length)")
    }

    private enum Kind { case done, today, ahead }

    private func point(_ i: Int, gap: CGFloat) -> CGPoint {
        let row = i / cols, k = i % cols
        let col = row % 2 == 0 ? k : cols - 1 - k
        return CGPoint(x: 16 + CGFloat(col) * gap, y: 36 + CGFloat(row) * 44)
    }

    private func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        return p
    }

    @ViewBuilder private func stone(_ kind: Kind) -> some View {
        let size: CGFloat = kind == .today ? 22 : 16
        let fill: Color = kind == .done ? theme.primary : kind == .today ? theme.ornament : (theme.pixelBorders ? theme.raised : Color(hex: 0xE3D5B6))
        if theme.pixelBorders {
            Rectangle().fill(fill).frame(width: size * 0.75, height: size * 0.75).rotationEffect(.degrees(45))
                .shadow(color: kind == .today ? theme.ornament.opacity(0.6) : .clear, radius: 6)
        } else {
            Circle().fill(fill).frame(width: size, height: size)
                .shadow(color: kind == .today ? theme.ornament.opacity(0.35) : .clear, radius: 6)
        }
    }
}

/// The evidence behind each kind of drill, with its honest limits.
enum WhyTopic: String, Identifiable {
    case palace, gym, arcade
    var id: String { rawValue }

    var title: String {
        switch self {
        case .palace: return "Why the palace works"
        case .gym: return "Why the gym works — and its limits"
        case .arcade: return "Why the arcade works"
        }
    }

    var points: [(String, String)] {
        switch self {
        case .palace: return [
            ("What it does", "You pin each item to a place you know well, then walk the route to read it back. Places give every item a fixed slot and a cue, which is why order comes back too."),
            ("The evidence", "In a 2017 study (Dresler et al., Neuron), beginners who trained the method of loci for six weeks went from about 26 to 62 of 72 words, stayed well above their starting point four months later, and their brain networks shifted toward those of memory champions. The method is among the best-supported memory techniques in the lab."),
            ("The limits", "It is a skill for lists, names, numbers and speeches. It won't make you forget less in general, and it takes practice to become fast — which is what the course is for."),
        ]
        case .gym: return [
            ("What it does", "N-back, letters + sums and sequences make you hold and update information while doing something else. That is working memory: your mental notepad."),
            ("The evidence", "Training reliably improves the trained tasks and closely related ones (near transfer; meta-analyses such as Soveri et al., 2017)."),
            ("The limits", "Whether it spreads to everyday memory or intelligence is debated; large reviews (Melby-Lervåg et al., 2016) found little far transfer. So the palace course is the core here, and the gym is a supplement you can enjoy."),
        ]
        case .arcade: return [
            ("What it does", "Names with faces, symbols, and where you left things: each drill trains binding — tying two things together so one brings back the other."),
            ("The evidence", "Making a vivid link between a name and a face feature is a long-studied mnemonic that improves name recall in older adults, and spacing practice over days makes it last (the spacing effect)."),
            ("The limits", "Gains are specific to what you practise. The benchmarks in Progress check honestly whether anything carries over."),
        ]
        }
    }
}

struct WhySheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let topic: WhyTopic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(topic.points, id: \.0) { point in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(point.0).font(theme.display(22)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                            Text(point.1).font(theme.body).foregroundStyle(theme.text)
                        }
                    }
                }
                .padding(20)
            }
            .background(ThemedBackground())
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct LessonList: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var open: Lesson?

    var body: some View {
        List(Course.lessons) { lesson in
            Button { open = lesson } label: {
                HStack {
                    Image(systemName: profile.lessonsRead.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(theme.primary)
                    Text(lesson.title).foregroundStyle(theme.text)
                }
                .frame(minHeight: theme.minTouch)
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Lessons")
        .sheet(item: $open) { l in
            LessonView(lesson: l) { _ = Quest.markLessonRead(l.id, profile: profile) }.environment(\.theme, theme)
        }
    }
}
