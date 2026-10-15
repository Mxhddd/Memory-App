import Foundation

/// When (rarely) to show the gentle, non-diagnostic "mention it to your doctor" card.
///
/// All three must hold:
///  (a) the domain EWMA is below its lower control limit;
///  (b) the practice-adjusted change score is < −1.645 on the two most recent bursts,
///      and those bursts are ≥ 28 days apart;
///  (c) the most recent burst week is not explained by logged poor sleep, illness or low mood.
public struct BurstChange: Codable, Equatable, Sendable {
    public var startDate: Date
    public var changeZ: Double
    public var confounded: Bool // poor sleep / illness / low mood logged that week

    public init(startDate: Date, changeZ: Double, confounded: Bool) {
        self.startDate = startDate
        self.changeZ = changeZ
        self.confounded = confounded
    }
}

public enum EscalationPolicy {
    public static let minimumGapDays = 28.0

    public static func shouldSuggestDoctorVisit(ewmaBelowLimit: Bool, bursts: [BurstChange]) -> Bool {
        guard ewmaBelowLimit else { return false }
        let sorted = bursts.sorted { $0.startDate < $1.startDate }
        guard sorted.count >= 2 else { return false }
        let last = sorted[sorted.count - 1]
        let previous = sorted[sorted.count - 2]
        let gapDays = last.startDate.timeIntervalSince(previous.startDate) / 86_400
        guard gapDays >= minimumGapDays else { return false }
        guard last.changeZ < ReliableChange.threshold90, previous.changeZ < ReliableChange.threshold90 else { return false }
        return !last.confounded
    }

    /// The only wording the app ever uses for this card. Supportive, never diagnostic.
    public static let message = "Your recent practice scores are lower than your usual range. Many things affect this, like sleep, stress, and health. It's a good idea to mention it to your doctor."
}
