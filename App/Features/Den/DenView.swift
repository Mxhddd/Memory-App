import SwiftUI
import Charts
import MemoryCore

/// Insights as a cozy den: shinies decorate the shelves; gentle charts show *your own* learning.
/// No percentiles, no comparisons with other people, no diagnostic language.
struct DenView: View {
    @Bindable var profile: Profile
    @Environment(\.theme) private var theme
    @State private var report = InsightsReport()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                denScene
                if report.showDoctorCard { doctorCard }
                engagementCard
                if !report.curves.isEmpty { learningCard }
                if report.compositeTrend.count >= 3 { trendCard }
                NavigationLink { CircleView(profile: profile) } label: {
                    HStack {
                        Image(systemName: "person.2.wave.2.fill")
                        VStack(alignment: .leading) {
                            Text("Your circle").font(theme.bodyEmphasis)
                            Text("Who gets a little ping when you practise").font(theme.caption).foregroundStyle(theme.secondaryText)
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
        .navigationTitle(theme.copy.denTitle)
        .onAppear { report = Insights.report() }
    }

    // MARK: Den scene

    private var denScene: some View {
        let stage = GardenIndex.growthStage(activeDaysLast28: report.activeDays28)
        let unlocked = min(profile.shinies / 5, Sprites.trinketOrder.count * 2)
        return VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(LinearGradient(colors: [theme.raised, theme.surface], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 6) {
                    shelf(Array(0..<min(unlocked, 8)))
                    shelf(Array(8..<max(8, min(unlocked, 16))))
                    MascotView(mood: stage >= 3 ? .happy : .idle, size: 110)
                }
                .padding(12)
            }
            .frame(height: 260)
            Text(stageLine(stage)).font(theme.body).foregroundStyle(theme.text).multilineTextAlignment(.center)
            Text("\(profile.shinies) \(theme.copy.shinyName) · a new treasure every 5").font(theme.caption).foregroundStyle(theme.secondaryText)
        }
        .themedCard()
    }

    private func shelf(_ indices: [Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { slot in
                let filled = slot < indices.count
                Group {
                    if filled, let art = Sprites.trinkets[Sprites.trinketOrder[indices[slot] % Sprites.trinketOrder.count]] {
                        PixelSpriteView(art: art)
                    } else {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(theme.outline.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3]))
                    }
                }
                .frame(width: 30, height: 30)
            }
        }
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.ornament.opacity(0.6)).frame(height: 3).offset(y: 4) }
        .accessibilityElement()
        .accessibilityLabel("\(indices.count) treasures on this shelf")
    }

    private func stageLine(_ stage: Int) -> String {
        let raccoon = theme.id == .midnightRaccoon
        switch stage {
        case 0: return raccoon ? "The den is quiet. \(profile.mascotName) is ready when you are." : "The atelier awaits."
        case 1: return raccoon ? "A few shinies are glinting in the dark ✨" : "The first pieces are on display."
        case 2: return raccoon ? "The den is getting cozy." : "The collection is growing."
        case 3: return raccoon ? "Fairy lights are up — this den is loved!" : "A well-tended atelier."
        case 4: return raccoon ? "Mochi's friends keep visiting to admire it." : "Visitors admire your collection."
        default: return raccoon ? "Legendary den. Raccoons whisper about it. 🦝" : "A masterpiece of steady practice."
        }
    }

    // MARK: Cards

    private var doctorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A gentle note", systemImage: "heart.circle.fill").font(theme.bodyEmphasis).foregroundStyle(theme.text)
            Text(EscalationPolicy.message).font(theme.body).foregroundStyle(theme.text)
            NavigationLink("Open my doctor-visit checklist") { ChecklistView() }
                .font(theme.bodyEmphasis)
                .foregroundStyle(theme.primary)
        }
        .themedCard(raised: true)
    }

    private var engagementCard: some View {
        HStack {
            stat("\(report.activeDays28)", "days practised\n(last 4 weeks)")
            stat("\(report.weeklyStreak)", "week\nstreak")
            stat(report.moonBellTotal > 0 ? "\(report.moonBellHits)/\(report.moonBellTotal)" : "–", "\(theme.id == .midnightRaccoon ? "moons" : "bells")\ncaught")
        }
        .themedCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(theme.display(28)).foregroundStyle(theme.text)
            Text(label).font(.caption).foregroundStyle(theme.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How you learn over a week").font(theme.display(24)).foregroundStyle(theme.text)
            Text("Same set every day of a check-in week. Rising lines = your memory doing its thing.")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
            Chart {
                ForEach(report.curves) { curve in
                    ForEach(curve.daily) { point in
                        LineMark(x: .value("Day", point.day), y: .value("Score", point.score))
                            .foregroundStyle(by: .value("Game", theme.copy.realmName(curve.task)))
                            .symbol(by: .value("Game", theme.copy.realmName(curve.task)))
                            .interpolationMethod(.monotone)
                    }
                }
            }
            .chartYScale(domain: 0...1)
            .chartXScale(domain: 1...7)
            .chartYAxis { AxisMarks(values: [0, 0.5, 1]) { _ in AxisGridLine(); AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent()) } }
            .frame(height: 200)
            ForEach(report.curves) { curve in
                if let gain = curve.practiceGain {
                    Text("\(theme.copy.realmName(curve.task)): \(gain >= 0.05 ? "you improved with practice this week 🌱" : "steady this week — sleep and stress can flatten the curve, and that's normal.")")
                        .font(theme.caption).foregroundStyle(theme.text)
                }
            }
        }
        .themedCard()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your usual range").font(theme.display(24)).foregroundStyle(theme.text)
            Text("A smoothed line compared with your own first week. Single days wobble — only long, steady changes matter.")
                .font(theme.caption).foregroundStyle(theme.secondaryText)
            Chart {
                RuleMark(y: .value("Usual range", report.ewmaLowerLimit))
                    .foregroundStyle(theme.secondaryText.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                ForEach(report.compositeTrend) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Trend", p.value))
                        .foregroundStyle(theme.primary)
                        .interpolationMethod(.monotone)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
        }
        .themedCard()
    }
}

struct ChecklistView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Query(sort: \ChecklistItem.order) private var items: [ChecklistItem]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Button {
                        item.done.toggle()
                        try? context.save()
                    } label: {
                        Label(item.title, systemImage: item.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(theme.text)
                            .frame(minHeight: theme.minTouch, alignment: .leading)
                    }
                }
            } footer: {
                Text("Common, often treatable things that affect memory. Worth asking your doctor about. The app stores this list only — it never interprets results.")
            }
            .listRowBackground(theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Doctor checklist")
    }
}
