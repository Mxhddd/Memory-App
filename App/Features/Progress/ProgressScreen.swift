import SwiftUI
import Charts
import MemoryCore

/// Your own progress: benchmarks (transfer), personal bests (skill), the den (consistency).
/// Compared only with your own starting point — never with other people.
struct ProgressScreen: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var report = InsightsReport()
    @State private var explaining: BenchmarkTrend?

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
                if !report.calibration.isEmpty { calibrationCard }
                if report.wordPace.count >= 2 { paceCard }
                if let vault = report.vaultRetention, vault.reviews >= 10 { vaultCard(vault) }
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
        .sheet(item: Binding(get: { explaining.map(ExplainItem.init) }, set: { if $0 == nil { explaining = nil } })) { item in
            HowSureSheet(trend: item.trend).environment(\.theme, theme)
        }
    }

    private struct ExplainItem: Identifiable {
        let trend: BenchmarkTrend
        var id: String { trend.title }
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
            if trend.personal != nil {
                Button { explaining = trend } label: {
                    Label("How sure is this?", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.bold)).foregroundStyle(theme.primary)
                }
                .frame(minHeight: theme.minTouch)
            }
        }
        .themedCard()
    }

    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Knowing what you know").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
            Chart {
                LineMark(x: .value("Guessed", 0), y: .value("Got", 0)).foregroundStyle(theme.hairline)
                LineMark(x: .value("Guessed", 100), y: .value("Got", 100)).foregroundStyle(theme.hairline)
                ForEach(report.calibration) { p in
                    PointMark(x: .value("Guessed", p.predicted * 100), y: .value("Got", p.actual * 100))
                        .foregroundStyle(theme.primary)
                }
            }
            .chartXScale(domain: 0...100)
            .chartYScale(domain: 0...100)
            .chartXAxisLabel("You guessed (%)")
            .chartYAxisLabel("You got (%)")
            .frame(height: 170)
            .accessibilityLabel(calibrationText)
            Text(calibrationText).font(theme.caption).foregroundStyle(theme.text)
            Text("Before each recall you guess your score. Dots on the line mean you judged yourself exactly. Knowing what you know helps you decide what needs another look.")
                .font(.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private var calibrationText: String {
        guard let c = report.calibrationSummary else {
            return "\(report.calibration.count) of \(Calibration.minimumPoints) guesses so far. The verdict appears after three."
        }
        let off = Int((abs(c.bias) * 100).rounded())
        switch c.verdict {
        case .calibrated: return "Well judged: your guesses land within \(Int((c.error * 100).rounded())) points of your scores on average."
        case .overconfident: return "You tend to expect about \(off) points more than you recall. Common — and it shrinks with practice."
        case .underconfident: return "You remember about \(off) points more than you expect. Your memory is better than you think."
        }
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Study speed").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("seconds per word").font(.caption).foregroundStyle(theme.secondaryText)
            }
            Chart(report.wordPace) { p in
                LineMark(x: .value("Date", p.date), y: .value("Seconds", p.value)).foregroundStyle(theme.primary)
                PointMark(x: .value("Date", p.date), y: .value("Seconds", p.value)).foregroundStyle(theme.primary)
            }
            .frame(height: 140)
            .accessibilityLabel("Seconds per word: " + report.wordPace.map { $0.value.formatted(.number.precision(.fractionLength(1))) }.joined(separator: ", "))
            Text("Next sprint: \(report.wordPaceBudget.formatted(.number.precision(.fractionLength(1)))) seconds a word. The clock tightens after a sprint at 90 % or better and eases after a rough one — speed only once accuracy holds, as memory athletes train.")
                .font(.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private func vaultCard(_ v: FSRSPersonal.TrueRetention) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Vault memory").font(theme.bodyEmphasis).foregroundStyle(theme.text).accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                stat("\(Int((v.rate * 100).rounded()))%", "remembered when\ncards came back")
                stat("\(Int((v.predicted * 100).rounded()))%", "forecast")
                stat("\(v.reviews)", "reviews")
            }
            Text(report.personalFSRS
                 ? "The schedule is fitted to how you forget, from your own reviews."
                 : "After \(FSRSPersonal.minimumReviews) reviews the schedule fits itself to how you forget.")
                .font(theme.caption).foregroundStyle(theme.text)
            if let advice = report.retentionAdvice {
                let current = (profile.desiredRetention * 100).rounded() / 100
                if abs(advice.suggested - current) >= 0.01 {
                    Button {
                        profile.desiredRetention = advice.suggested
                        Haptic.success()
                    } label: {
                        Label("Use \(Int((advice.suggested * 100).rounded()))% — the least reviewing for what you keep", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Label("Your target (\(Int((current * 100).rounded()))%) is already the most efficient.", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(theme.success)
                }
            }
            Text("Aiming higher means more reviews; lower means more forgetting. The suggestion simulates a year of reviews at each target from 85 to 95 % (FSRS).")
                .font(.caption).foregroundStyle(theme.secondaryText)
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

/// "How sure is this?": the numbers behind a benchmark verdict, in plain words.
struct HowSureSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let trend: BenchmarkTrend

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let p = trend.personal {
                        row("Sessions", "\(trend.points.count) (\(p.sessions) baseline)")
                        row("Your baseline", p.baseline.formatted(.number.precision(.fractionLength(0...1))) + " \(trend.unitPlural)")
                        row("Your day-to-day noise", "± " + p.sem.formatted(.number.precision(.fractionLength(1))) + " \(trend.unitPlural)")
                        row("Expected from retesting alone", "+" + p.expectedGain.formatted(.number.precision(.fractionLength(0...1))))
                        row("Needed for “reliably improved”", "+" + p.threshold.formatted(.number.precision(.fractionLength(1))))
                        if let latest = trend.latest, trend.points.count > p.sessions {
                            let change = latest - p.baseline
                            row("Latest change", (change >= 0 ? "+" : "") + change.formatted(.number.precision(.fractionLength(0...1))))
                            Text(change >= p.threshold
                                 ? "That's beyond your noise and practice effects: a jump this big would come from a lucky day less than 1 time in 20."
                                 : "Not yet beyond your normal spread. A single good day can land here by chance, so the app waits for more.")
                                .font(theme.body).foregroundStyle(theme.text)
                        }
                    }
                    Text("How it's worked out").font(theme.display(22)).foregroundStyle(theme.text)
                    Text("Your first three sessions set your baseline and show how much you vary from day to day. That spread is pooled with published test–retest figures so three sessions aren't over-trusted. A result counts as reliably improved only when it beats the baseline by more than that noise plus the small gain everyone gets from simply taking a test again (a reliable change index, Jacobson & Truax 1991). Each session uses a different, equally hard word list, so you never relearn the same words.")
                        .font(theme.caption).foregroundStyle(theme.secondaryText)
                }
                .padding(20)
            }
            .background(ThemedBackground())
            .navigationTitle("How sure is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(theme.caption).foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value).font(theme.bodyEmphasis).foregroundStyle(theme.text)
        }
        .accessibilityElement(children: .combine)
    }
}
