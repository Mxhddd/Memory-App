import SwiftUI
import Charts
import MemoryCore

/// Your own progress: benchmarks (transfer), personal bests (skill), the den (consistency).
/// Compared only with your own starting point — never with other people.
struct ProgressScreen: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var report = InsightsReport()

    var body: some View {
        ScrollView {
            RoomSceneView(stage: stage, mood: stage >= 3 ? .happy : .idle)
            VStack(spacing: 22) {
                treasures
                bestsCard
                benchmarkCard(report.wordRecall)
                benchmarkCard(report.digitSpan)
                if report.nBackLevels.count >= 2 { levelChart("n-back level", report.nBackLevels) }
                if report.sprintWords.count >= 2 { levelChart("Words recalled in a sprint", report.sprintWords) }
                NavigationLink { CircleView(profile: profile) } label: {
                    HStack {
                        Image(systemName: "person.2.wave.2.fill")
                        VStack(alignment: .leading) {
                            Text("Your circle").font(theme.bodyEmphasis)
                            Text("Who gets a ping when you train").font(theme.caption).foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(theme.text)
                    .themedCard()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .background(ThemedBackground())
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { report = Insights.report() }
    }

    private var stage: Int { DenGrowth.stage(activeDaysLast28: report.activeDays28) }

    private var treasures: some View {
        let unlocked = min(profile.shinies / 5, 16)
        let atelier = theme.id == .gildedAtelier
        let next = RoomScene.next(atelier: atelier, stage: stage)
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(atelier ? "Your gallery" : "Your den") grows as you train: \(report.activeDays28) of 16 days in the last 4 weeks. "
                 + (next.map { "Next to arrive: \($0)." } ?? "Fully furnished — keep it that way."))
                .font(theme.body).foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text("Treasures").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(unlocked) of 16 · next at \(min(unlocked + 1, 16) * 5) \(theme.copy.shinyName)")
                    .font(.caption).foregroundStyle(theme.secondaryText)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(0..<16, id: \.self) { k in
                    if k < unlocked, let art = Sprites.trinkets[Sprites.trinketOrder[k % Sprites.trinketOrder.count]] {
                        PixelSpriteView(art: art).aspectRatio(1, contentMode: .fit)
                    } else {
                        Group {
                            if theme.pixelBorders { PixelCornerShape(step: 3).fill(theme.raised) }
                            else { Circle().fill(theme.raised).padding(10) }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(unlocked) of 16 treasures")
            Text(report.weeklyStreak > 0 ? "\(report.weeklyStreak)-week streak · \(profile.shinies) \(theme.copy.shinyName) earned"
                                         : "Weekly goal: 4 days · \(profile.shinies) \(theme.copy.shinyName) earned")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 4)
    }

    private var bestsCard: some View {
        HStack {
            stat(report.bestWordSprint > 0 ? "\(report.bestWordSprint)" : "–", "words in\na sprint")
            Rectangle().fill(theme.hairline).frame(width: 1, height: 48)
            stat(report.bestDigitSprint > 0 ? "\(report.bestDigitSprint)" : "–", "digits in\na sprint")
            Rectangle().fill(theme.hairline).frame(width: 1, height: 48)
            stat(report.bestNBack > 0 ? "\(report.bestNBack)-back" : "–", "best\nn-back")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(theme.display(30)).foregroundStyle(theme.ornament)
            Text(label).font(.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func benchmarkCard(_ trend: BenchmarkTrend) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Benchmark · \(trend.title)").font(theme.bodyEmphasis).foregroundStyle(theme.text)
                Spacer()
                if trend.reliablyImproved {
                    Label("Reliably improved", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(theme.success)
                }
            }
            if let b = trend.baseline, let l = trend.latest {
                Text("Start \(Int(b)) → now \(Int(l)) \(trend.unit)").font(theme.display(24)).foregroundStyle(theme.text)
            } else {
                Text("Your first benchmark sets the starting line.").font(theme.caption).foregroundStyle(theme.secondaryText)
            }
            if trend.points.count >= 2 {
                Chart(trend.points) { p in
                    LineMark(x: .value("Date", p.date), y: .value(trend.title, p.value)).foregroundStyle(theme.primary)
                    PointMark(x: .value("Date", p.date), y: .value(trend.title, p.value)).foregroundStyle(theme.primary)
                }
                .frame(height: 140)
            }
            Text(trend.reliablyImproved
                 ? "This gain is bigger than test-to-test noise and normal practice effects."
                 : "“Reliably improved” appears only when a gain beats measurement noise — no false praise.")
                .font(.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private func levelChart(_ title: String, _ points: [TrendPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(theme.bodyEmphasis).foregroundStyle(theme.text)
            Chart(points) { p in
                LineMark(x: .value("Date", p.date), y: .value(title, p.value))
                    .foregroundStyle(theme.primary)
                    .interpolationMethod(.stepEnd)
            }
            .frame(height: 140)
        }
        .themedCard()
    }
}
