import Foundation

/// What the widget / Lock Screen needs, written by the app into the shared App Group container.
struct WidgetSnapshot: Codable, Equatable {
    var themeRaw: String = "midnightRaccoon"
    var mascotName: String = "Mochi"
    var questDone: Int = 0
    var questTotal: Int = 3
    var questComplete: Bool = false
    var dueCards: Int = 0
    var nextIntentionText: String?
    var nextIntentionTime: Date?
    var shinies: Int = 0
    var lapsesToday: Int = 0
    var updatedAt: Date = Date()

    static let placeholder = WidgetSnapshot(questDone: 1, questTotal: 3, dueCards: 4,
                                            nextIntentionText: "Call Aunty", nextIntentionTime: Date().addingTimeInterval(3600),
                                            shinies: 12)
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

    private static func url(_ name: String) -> URL? { containerURL?.appendingPathComponent(name) }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let u = url("snapshot.json"), let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let u = url("snapshot.json"), let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: u, options: .atomic)
    }

    /// Lapses logged from the widget, imported into SwiftData next time the app opens.
    static func appendPendingLapse(_ date: Date = Date()) {
        guard let u = url("pending-lapses.json") else { return }
        var list = (try? JSONDecoder().decode([Date].self, from: Data(contentsOf: u))) ?? []
        list.append(date)
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: u, options: .atomic) }
    }

    static func takePendingLapses() -> [Date] {
        guard let u = url("pending-lapses.json"),
              let list = try? JSONDecoder().decode([Date].self, from: Data(contentsOf: u)) else { return [] }
        try? FileManager.default.removeItem(at: u)
        return list
    }

    static func clear() {
        for name in ["snapshot.json", "pending-lapses.json"] {
            if let u = url(name) { try? FileManager.default.removeItem(at: u) }
        }
    }
}
