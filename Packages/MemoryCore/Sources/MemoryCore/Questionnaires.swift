import Foundation

/// Scoring for the onboarding / weekly check-ins.
/// PRMQ and MMQ are licensed instruments — the app ships original self-report items until the
/// authors grant permission (see docs/DESIGN.md).
public enum PHQ9 {
    public static let items = [
        "Little interest or pleasure in doing things",
        "Feeling down, depressed, or hopeless",
        "Trouble falling or staying asleep, or sleeping too much",
        "Feeling tired or having little energy",
        "Poor appetite or overeating",
        "Feeling bad about yourself — or that you are a failure or have let yourself or your family down",
        "Trouble concentrating on things, such as reading the newspaper or watching television",
        "Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving around a lot more than usual",
        "Thoughts that you would be better off dead or of hurting yourself in some way",
    ]

    public enum Band: String, Sendable { case minimal, mild, moderate, moderatelySevere, severe }

    public static func score(_ answers: [Int]) -> Int { answers.prefix(9).map { min(max($0, 0), 3) }.reduce(0, +) }

    public static func band(_ score: Int) -> Band {
        switch score {
        case ..<5: return .minimal
        case 5..<10: return .mild
        case 10..<15: return .moderate
        case 15..<20: return .moderatelySevere
        default: return .severe
        }
    }

    /// Any non-zero answer on item 9 → show crisis resources immediately.
    public static func needsSafetyResources(_ answers: [Int]) -> Bool {
        answers.count >= 9 && answers[8] > 0
    }
}

public enum GAD7 {
    public static let items = [
        "Feeling nervous, anxious, or on edge",
        "Not being able to stop or control worrying",
        "Worrying too much about different things",
        "Trouble relaxing",
        "Being so restless that it is hard to sit still",
        "Becoming easily annoyed or irritable",
        "Feeling afraid, as if something awful might happen",
    ]

    public static func score(_ answers: [Int]) -> Int { answers.prefix(7).map { min(max($0, 0), 3) }.reduce(0, +) }
}

public let frequencyOptions = ["Not at all", "Several days", "More than half the days", "Nearly every day"]

/// Original everyday-memory self-report (not PRMQ): 1 = never … 5 = very often.
public enum EverydayMemoryCheck {
    public struct Item: Sendable {
        public let text: String
        public let prospective: Bool
    }

    public static let items: [Item] = [
        .init(text: "Forgetting to do something you planned to do a few minutes ago", prospective: true),
        .init(text: "Forgetting an appointment or call unless someone reminds you", prospective: true),
        .init(text: "Walking into a room and forgetting why", prospective: true),
        .init(text: "Forgetting to take something with you when leaving", prospective: true),
        .init(text: "Forgetting the name of someone you met recently", prospective: false),
        .init(text: "Misplacing everyday items like keys, glasses or phone", prospective: false),
        .init(text: "Forgetting something you were told a day or two ago", prospective: false),
        .init(text: "Losing track of what you were saying mid-conversation", prospective: false),
    ]

    public static let scale = ["Never", "Rarely", "Sometimes", "Often", "Very often"]

    /// Mean complaint (1…5) for prospective vs retrospective items.
    public static func profile(_ answers: [Int]) -> (prospective: Double, retrospective: Double) {
        var p: [Int] = [], r: [Int] = []
        for (i, a) in answers.enumerated() where i < items.count {
            items[i].prospective ? p.append(a) : r.append(a)
        }
        func mean(_ xs: [Int]) -> Double { xs.isEmpty ? 0 : Double(xs.reduce(0, +)) / Double(xs.count) }
        return (mean(p), mean(r))
    }
}

/// The 2×2 "complaint vs performance" quadrant per domain.
public enum ProfileQuadrant: String, Codable, Sendable {
    case worriedButSteady      // high complaint / normal performance → strategies, sleep & mood, reassure
    case focusHere             // high complaint / low performance → prioritise domain, suggest a doctor chat
    case quietDip              // low complaint / low performance → gently surface objective trends
    case maintenance           // low complaint / normal performance

    public static func classify(complaint: Double, performanceZ: Double, complaintCut: Double = 3, lowZ: Double = -1) -> ProfileQuadrant {
        let high = complaint >= complaintCut
        let low = performanceZ <= lowZ
        switch (high, low) {
        case (true, false): return .worriedButSteady
        case (true, true): return .focusHere
        case (false, true): return .quietDip
        case (false, false): return .maintenance
        }
    }
}
