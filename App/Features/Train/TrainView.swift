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

                medallions("Palace drills", sub: "Free practice — the course sets your daily drills", [
                    (.wordSprint, profile.wordLevel, "\(profile.wordLevel) words"),
                    (.numberSprint, profile.digitLevel, "\(profile.digitLevel) digits"),
                    (.routeWalk, 0, palaceCount == 0 ? "No palace yet" : "Walk a palace"),
                ])
                medallions("Working-memory gym", sub: "Holding and juggling information", [
                    (.dualNBack, profile.nBackLevel, "\(profile.nBackLevel)-back"),
                    (.complexSpan, 0, "Letters + sums"),
                    (.sequences, 0, "Span \(profile.sequenceSpan)"),
                ], note: "These reliably train working memory itself. Whether that spreads to everyday memory is debated, so the palace course is the core and the gym is the supplement.")
                medallions("Arcade", sub: "Binding things together", [
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
        .fullScreenCover(item: Binding(get: { playing.map(GameItem.init) }, set: { if $0 == nil { playing = nil } })) { item in
            GameHost(ctx: item.ctx, profile: profile) { _ in playing = nil }
                .environment(\.theme, theme)
        }
    }

    private func medallions(_ title: String, sub: String, _ drills: [(RealmTask, Int, String)], note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(theme.display(24)).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                Text(sub).font(theme.caption).foregroundStyle(theme.secondaryText)
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
            if let note {
                Text(note).font(.caption).foregroundStyle(theme.secondaryText)
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
