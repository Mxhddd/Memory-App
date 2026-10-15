import SwiftUI
import SwiftData
import MemoryCore

/// Everything trainable, outside today's session: the course map, palaces, gym and arcade.
struct TrainView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var playing: GameContext?
    @State private var lesson: Lesson?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Memory Palace course").font(theme.display(26)).foregroundStyle(theme.text)
                    Text("Six weeks of the method memory champions use. In a 2017 study, people trained this way for 40 days roughly doubled how many words they could remember, and their brain networks shifted toward champions' patterns.")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                    CourseMap(day: profile.courseDay)
                }
                .padding(.vertical, 6)
                NavigationLink { PalaceListView() } label: { Label("My palaces", systemImage: "building.columns.fill") }
                NavigationLink { LessonList(profile: profile) } label: { Label("Lessons", systemImage: "book.fill") }
            }
            .listRowBackground(theme.surface)

            Section {
                drill(.wordSprint, size: profile.wordLevel, detail: "\(profile.wordLevel) words")
                drill(.numberSprint, size: profile.digitLevel, detail: "\(profile.digitLevel) digits")
                drill(.routeWalk, size: 0, detail: "Rehearse a palace")
            } header: {
                Text("Palace drills")
            }
            .listRowBackground(theme.surface)

            Section {
                drill(.dualNBack, size: profile.nBackLevel, detail: "Level \(profile.nBackLevel)")
                drill(.complexSpan, size: 0, detail: "Letters + sums")
                drill(.sequences, size: 0, detail: "Spatial span")
            } header: {
                Text("Working-memory gym")
            } footer: {
                Text("These reliably train working memory itself. Whether that spreads to everyday memory is debated, so the palace course is the core and the gym is the supplement.")
            }
            .listRowBackground(theme.surface)

            Section("Arcade") {
                drill(.faceName, size: 0, detail: "Names & faces")
                drill(.ancientRunes, size: 0, detail: "Symbol–meaning pairs")
                drill(.stash, size: 0, detail: "Object locations")
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Train")
        .fullScreenCover(item: Binding(get: { playing.map(GameItem.init) }, set: { if $0 == nil { playing = nil } })) { item in
            GameHost(ctx: item.ctx, profile: profile) { _ in playing = nil }
                .environment(\.theme, theme)
        }
    }

    private func drill(_ task: RealmTask, size: Int, detail: String) -> some View {
        Button {
            var ctx = Quest.context(for: task, size: size, profile: profile)
            ctx.seed += "-free\(Int(Date().timeIntervalSince1970))" // free practice gets fresh material
            if task == .routeWalk { ctx.size = Quest.palaces().first?.stops.count ?? 0 }
            playing = ctx
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.copy.realmName(task)).font(theme.bodyEmphasis).foregroundStyle(theme.text)
                    Text(detail).font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(theme.primary)
            }
            .frame(minHeight: theme.minTouch)
        }
    }
}

/// 42 dots, one per course day.
struct CourseMap: View {
    @Environment(\.theme) private var theme
    let day: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(1...Course.length, id: \.self) { d in
                RoundedRectangle(cornerRadius: theme.pixelBorders ? 1 : 4)
                    .fill(d < day ? theme.primary : d == day ? theme.ornament : theme.raised)
                    .frame(height: 14)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Course day \(day) of \(Course.length)")
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
