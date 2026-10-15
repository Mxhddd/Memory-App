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
            VStack(spacing: 18) {
                denShelf
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
            .padding(16)
        }
        .background(ThemedBackground())
        .navigationTitle("Progress")
        .onAppear { report = Insights.report() }
    }

    private var denShelf: some View {
        let stage = DenGrowth.stage(activeDaysLast28: report.activeDays28)
        let unlocked = min(profile.shinies / 5, 16)
        return VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                MascotView(mood: stage >= 3 ? .happy : .idle, size: 96)
                VStack(alignment: .leading, spacing: 6) {
                    shelf(Array(0..<min(unlocked, 8)))
                    shelf(Array(8..<max(8, unlocked)))
                }
            }
            Text("\(report.activeDays28) training days in the last 4 weeks · \(report.weeklyStreak)-week streak")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private func shelf(_ indices: [Int]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { slot in
                Group {
                    if slot < indices.count, let art = Sprites.trinkets[Sprites.trinketOrder[indices[slot] % Sprites.trinketOrder.count]] {
                        PixelSpriteView(art: art)
                    } else {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(theme.outline.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3]))
                    }
                }
                .frame(width: 26, height: 26)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(indices.count) treasures")
    }

    private var bestsCard: some View {
        HStack {
            stat("\(report.bestWordSprint)", "words in\na sprint")
            stat("\(report.bestDigitSprint)", "digits in\na sprint")
            stat(report.bestNBack > 0 ? "\(report.bestNBack)" : "–", "best\nn-back")
        }
        .themedCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(theme.display(30)).foregroundStyle(theme.text)
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
