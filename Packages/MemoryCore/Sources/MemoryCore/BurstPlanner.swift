import Foundation

/// Burst schedule: a 7-day baseline burst, then a 7-day burst every 4 weeks, with
/// training-only days in between. Also the ACTIVE-style speed schedule with boosters.
public struct BurstPlanner: Sendable {
    public var start: Date
    public var burstLength: Int
    public var cycleDays: Int
    public var calendar: Calendar

    public init(start: Date, burstLength: Int = 7, cycleDays: Int = 28, calendar: Calendar = .current) {
        self.start = calendar.startOfDay(for: start)
        self.burstLength = burstLength
        self.cycleDays = cycleDays
        self.calendar = calendar
    }

    public func dayIndex(for date: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// (burst number from 0, day within burst from 1) or nil on training days.
    public func burstDay(for date: Date) -> (burst: Int, day: Int)? {
        let d = dayIndex(for: date)
        guard d >= 0 else { return nil }
        let within = d % cycleDays
        guard within < burstLength else { return nil }
        return (d / cycleDays, within + 1)
    }

    public func burstStart(_ burst: Int) -> Date {
        calendar.date(byAdding: .day, value: burst * cycleDays, to: start)!
    }

    /// The rotating third task on a burst day (Face–Name and Ancient Runes run every day).
    public static let rotation: [RealmTask] = [.wordList, .sequences, .runeSort, .stash, .snackPrices, .wordList, .sequences]

    public func tasks(for date: Date) -> [RealmTask] {
        guard let b = burstDay(for: date) else { return [] }
        return [.faceName, .ancientRunes, Self.rotation[(b.day - 1) % Self.rotation.count]]
    }
}

/// ACTIVE: ~10 speed sessions over the first 5–6 weeks, boosters ~11 and ~35 months later.
public enum SpeedSchedule {
    public static let initialSessions = 10
    public static let initialWindowDays = 42
    public static let boosterMonths = [11, 35]
    public static let boosterSessions = 4

    public enum Phase: Equatable, Sendable { case initial, booster(Int), rest }

    public static func phase(start: Date, now: Date, calendar: Calendar = .current) -> Phase {
        let days = calendar.dateComponents([.day], from: start, to: now).day ?? 0
        if days < initialWindowDays { return .initial }
        let months = calendar.dateComponents([.month], from: start, to: now).month ?? 0
        for (i, m) in boosterMonths.enumerated() where months >= m && months < m + 1 {
            return .booster(i + 1)
        }
        return .rest
    }

    /// Whether a speed session is suggested today, given sessions already done in this phase.
    public static func sessionSuggested(phase: Phase, sessionsDoneInPhase: Int) -> Bool {
        switch phase {
        case .initial: return sessionsDoneInPhase < initialSessions
        case .booster: return sessionsDoneInPhase < boosterSessions
        case .rest: return false
        }
    }
}
