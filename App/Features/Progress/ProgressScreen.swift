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
                if !report.champion.isEmpty { championCard }
                if report.whatSticks.count >= 2 { whatSticksCard }
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
            Text("\(atelier ? "Your gallery" : "Your den") grows as you train: \(report.activeDays28) of 21 days in the last 4 weeks. "
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
            if let p = trend.personal {
                Text("Baseline " + p.baseline.formatted(.number.precision(.fractionLength(0...1)))
                     + (trend.points.count > BenchmarkPlanner.baselineSessions ? " → now \(Int(trend.latest ?? 0))" : "") + " \(trend.unit)")
                    .font(theme.display(24)).foregroundStyle(theme.text)
            } else if let l = trend.latest {
                Text("\(Int(l)) \(trend.unit)").font(theme.display(24)).foregroundStyle(theme.text)
            }
            if trend.points.count >= 2 {
                Chart {
                    if let band = trend.band {
                        RectangleMark(xStart: .value("Start", trend.points.first!.date), xEnd: .value("End", trend.points.last!.date),
                                      yStart: .value("Low", band.lowerBound), yEnd: .value("High", band.upperBound))
                            .foregroundStyle(theme.accent.opacity(0.18))
                    }
                    ForEach(trend.points) { p in
                        LineMark(x: .value("Date", p.date), y: .value(trend.title, p.value)).foregroundStyle(theme.primary)
                        PointMark(x: .value("Date", p.date), y: .value(trend.title, p.value)).foregroundStyle(theme.primary)
                    }
                }
                .frame(height: 140)
                .accessibilityLabel("\(trend.title): " + trend.points.map { "\(Int($0.value))" }.joined(separator: ", "))
            }
            Text(note(for: trend)).font(.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private func note(for trend: BenchmarkTrend) -> String {
        if trend.points.isEmpty { return "Three baseline days come first, one a day, so the app learns your normal day-to-day spread." }
        if trend.baselineLeft > 0 { return "Baseline \(BenchmarkPlanner.baselineSessions - trend.baselineLeft) of 3 done. After the third, a shaded band shows your normal range." }
        if trend.reliablyImproved { return "This gain is bigger than your own day-to-day noise and normal practice effects." }
        let needed = Int((trend.personal?.threshold ?? 0).rounded(.up))
        return "The shaded band is your normal range. “Reliably improved” appears above it — about \(needed) \(needed == 1 ? trend.unitSingular : trend.unitPlural) over your baseline."
    }

    private var championCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Champion test · 72 words").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
            ForEach(report.champion) { c in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(c.date, format: .dateTime.day().month(.abbreviated)).font(theme.caption).foregroundStyle(theme.secondaryText)
                        .frame(width: 70, alignment: .leading)
                    Text("\(c.immediate)").font(theme.display(26)).foregroundStyle(theme.ornament)
                    Text("now · next day \(c.nextDay.map(String.init) ?? "—")").font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
            Text("In Dresler et al. (2017), beginners who trained the palace method for six weeks went from about 26 to 62 of these 72 words. The next-day score shows how much of it lasts.")
                .font(.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private var whatSticksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("What sticks").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("% of a sprint list recalled").font(.caption).foregroundStyle(theme.secondaryText)
            }
            Chart(report.whatSticks) { p in
                BarMark(x: .value("Delay", p.offset == 0 ? "same day" : "\(p.offset) day\(p.offset == 1 ? "" : "s")"),
                        y: .value("Recalled", p.mean * 100))
                    .foregroundStyle(p.offset == 0 ? theme.primary : theme.accent)
                    .annotation(position: .top) { Text("\(Int((p.mean * 100).rounded()))%").font(.caption.weight(.bold)).foregroundStyle(theme.text) }
            }
            .chartYScale(domain: 0...110)
            .chartYAxis(.hidden)
            .frame(height: 150)
            Text("Each sprint list comes back after 1, 3, 7 and 21 days. The drop between bars is your forgetting curve — revisiting is what flattens it.")
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
