import Foundation
import CoreSpotlight
import SwiftData
import MemoryCore

/// Vault cards, palaces and lessons show up in iPhone search; tapping one opens it in the app.
@MainActor
enum SpotlightIndex {
    private static let lastKey = "spotlight.lastIndexed"

    static func refreshIfStale() {
        let last = UserDefaults.standard.object(forKey: lastKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 6 * 3600 else { return }
        reindex()
    }

    static func reindex() {
        UserDefaults.standard.set(Date(), forKey: lastKey)
        var items: [CSSearchableItem] = []
        let cards = (try? Store.context.fetch(FetchDescriptor<MemoryCard>())) ?? []
        for card in cards.prefix(2000) {
            let a = CSSearchableItemAttributeSet(contentType: .text)
            a.title = card.prompt
            a.contentDescription = "Vault · \(card.deck)"   // the answer stays out of search results
            a.keywords = [card.deck, "vault", "memory"]
            items.append(CSSearchableItem(uniqueIdentifier: "card:\(card.id.uuidString)", domainIdentifier: "cards", attributeSet: a))
        }
        for palace in Quest.palaces() {
            let a = CSSearchableItemAttributeSet(contentType: .text)
            a.title = palace.name
            a.contentDescription = "Memory palace · \(palace.stops.count) stops"
            items.append(CSSearchableItem(uniqueIdentifier: "palace:\(palace.id.uuidString)", domainIdentifier: "palaces", attributeSet: a))
        }
        for lesson in Course.lessons {
            let a = CSSearchableItemAttributeSet(contentType: .text)
            a.title = "Lesson · \(lesson.title)"
            a.contentDescription = lesson.pages.first
            items.append(CSSearchableItem(uniqueIdentifier: "lesson:\(lesson.id)", domainIdentifier: "lessons", attributeSet: a))
        }
        let index = CSSearchableIndex.default()
        index.deleteAllSearchableItems { _ in index.indexSearchableItems(items) }
    }

    static func clear() { CSSearchableIndex.default().deleteAllSearchableItems() }

    /// Opens a Spotlight result ("card:<uuid>", "palace:<uuid>", "lesson:<id>").
    static func open(_ identifier: String) {
        let parts = identifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        switch parts[0] {
        case "card": if let id = UUID(uuidString: parts[1]) { Router.shared.go(.card(id)) }
        case "palace": Router.shared.tab = .train
        default: Router.shared.go(.today)
        }
    }
}
