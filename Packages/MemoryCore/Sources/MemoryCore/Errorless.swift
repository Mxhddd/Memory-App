import Foundation

/// Errorless-first spaced retrieval (SRT) for new items.
///
/// A new item is first *shown with its answer* (no guessing), then recalled at expanding
/// in-session gaps (30 s → 1 → 2 → 4 min). A miss — or a "show me" — re-presents the answer and
/// restarts the ladder, so the learner never rehearses an error. After the last rung the item
/// graduates into FSRS.
public struct ErrorlessItem<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public var rung: Int          // index into the ladder of the *next* recall
    public var nextDue: Date
    public var presentations: Int // how many times the answer has been shown
    public var graduated: Bool

    public init(id: ID, presentedAt: Date) {
        self.id = id
        rung = 0
        nextDue = presentedAt
        presentations = 1
        graduated = false
    }
}

public struct ErrorlessSession<ID: Hashable & Sendable>: Sendable {
    public static var defaultLadder: [TimeInterval] { [30, 60, 120, 240] }

    public let ladder: [TimeInterval]
    public private(set) var items: [ErrorlessItem<ID>] = []

    public init(ladder: [TimeInterval] = ErrorlessSession.defaultLadder) {
        precondition(!ladder.isEmpty)
        self.ladder = ladder
    }

    /// Call right after the answer has been shown for a new item.
    public mutating func present(_ id: ID, at now: Date) {
        var item = ErrorlessItem(id: id, presentedAt: now)
        item.nextDue = now.addingTimeInterval(ladder[0])
        items.removeAll { $0.id == id }
        items.append(item)
    }

    /// Items whose recall gap has elapsed, earliest first.
    public func due(at now: Date) -> [ID] {
        items.filter { !$0.graduated && $0.nextDue <= now }
            .sorted { $0.nextDue < $1.nextDue }
            .map(\.id)
    }

    /// Seconds until the next pending recall, or nil if everything has graduated.
    public func secondsUntilNext(from now: Date) -> TimeInterval? {
        items.filter { !$0.graduated }.map { max(0, $0.nextDue.timeIntervalSince(now)) }.min()
    }

    public var isFinished: Bool { items.allSatisfy(\.graduated) }
    public var graduatedIDs: [ID] { items.filter(\.graduated).map(\.id) }

    /// Record a recall attempt. Returns true if the item graduated.
    @discardableResult
    public mutating func record(_ id: ID, recalled: Bool, at now: Date) -> Bool {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return false }
        if recalled {
            items[i].rung += 1
            if items[i].rung >= ladder.count {
                items[i].graduated = true
                return true
            }
            items[i].nextDue = now.addingTimeInterval(ladder[items[i].rung])
        } else {
            // Re-show the answer (the UI does this) and restart the ladder.
            items[i].rung = 0
            items[i].presentations += 1
            items[i].nextDue = now.addingTimeInterval(ladder[0])
        }
        return false
    }
}
