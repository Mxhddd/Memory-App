import Foundation

/// What the widgets, Lock Screen and controls need, written by the app into the App Group container.
struct WidgetSnapshot: Codable, Equatable {
    struct Step: Codable, Equatable {
        var title: String
        var symbol: String
        var done: Bool
    }
    struct Reminder: Codable, Equatable {
        var id: String
        var text: String
        var time: Date
    }

    var themeRaw: String = "midnightRaccoon"
    var mascotName: String = "Mochi"
    var questDone: Int = 0
    var questTotal: Int = 3
    var questComplete: Bool = false
    var dueCards: Int = 0
    var nextIntentionText: String?
    var nextIntentionTime: Date?
    var shinies: Int = 0
    var courseDay: Int = 1
    var updatedAt: Date = Date()
    // v0.5
    var steps: [Step] = []
    var reminders: [Reminder] = []
    var growthStage: Int = 0
    var activeDays28: Int = 0
    var signatureExpiry: Date?

    var nextStep: Step? { steps.first { !$0.done } }

    static let placeholder = WidgetSnapshot(
        questDone: 1, questTotal: 4, dueCards: 4,
        nextIntentionText: "Call Aunty", nextIntentionTime: Date().addingTimeInterval(3600),
        shinies: 12, courseDay: 9,
        steps: [Step(title: "Vault warm-up", symbol: "rectangle.stack.fill", done: true),
                Step(title: "Lesson · Linking", symbol: "book.fill", done: false),
                Step(title: "Midnight Sprint · 15 words", symbol: "building.columns.fill", done: false),
                Step(title: "Firefly n-back · 2-back", symbol: "square.grid.3x3.fill", done: false)],
        reminders: [Reminder(id: UUID().uuidString, text: "Call Aunty", time: Date().addingTimeInterval(3600))],
        growthStage: 3, activeDays28: 11
    )
}

enum SharedStore {
    /// SideStore/AltStore rewrite App Group IDs on free accounts and list the real ones in
    /// `ALTAppGroups`, so read that first, then our own key.
    static var groupID: String {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String], let first = groups.first {
            return first
        }
        return Bundle.main.object(forInfoDictionaryKey: "MGAppGroupID") as? String ?? "group.com.mxhddd.memorygarden"
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var isAvailable: Bool { containerURL != nil }

    /// Small settings both the app and the widget extension read (e.g. the Live Activity switch).
    static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    /// Set by widget/control intents after they change data, so the app replans reminders and the
    /// Live Activity the next time it becomes active.
    static let needsRefreshKey = "needsRefresh"
    /// Where a control or shortcut asked the app to open ("quest", "review", "reminders").
    static let pendingRouteKey = "pendingRoute"

    private static func url(_ name: String) -> URL? { containerURL?.appendingPathComponent(name) }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let u = url("snapshot.json"), let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let u = url("snapshot.json"), let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: u, options: .atomic)
    }

    static func clear() {
        for name in ["snapshot.json"] {
            if let u = url(name) { try? FileManager.default.removeItem(at: u) }
        }
    }
}
