import AppIntents
import Foundation
import SwiftData
import UserNotifications
import WidgetKit
import MemoryCore

// Intents that run inside the widget extension (interactive widgets) as well as the app.
// They only touch the shared SwiftData store in the App Group, so both targets compile them.

/// Flashcard widget: turn the card over.
struct RevealCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Reveal the answer"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Card") var cardID: String

    init() {}
    init(cardID: UUID) { self.cardID = cardID.uuidString }

    func perform() async throws -> some IntentResult {
        SharedStore.defaults?.set(cardID, forKey: FlashcardState.revealedKey)
        return .result()
    }
}

/// Flashcard widget: grade the card you just recalled (FSRS-6, same as the Vault).
struct GradeCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Grade a Vault card"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Card") var cardID: String
    @Parameter(title: "Rating") var rating: Int

    init() {}
    init(cardID: UUID, rating: Rating) {
        self.cardID = cardID.uuidString
        self.rating = rating.rawValue
    }

    func perform() async throws -> some IntentResult {
        let context = ModelContext(Store.container)
        if let id = UUID(uuidString: cardID), let card = VaultGrading.card(id, in: context),
           let r = Rating(rawValue: rating) {
            VaultGrading.grade(card, rating: r, desiredRetention: VaultGrading.desiredRetention(in: context), in: context)
        }
        SharedStore.defaults?.removeObject(forKey: FlashcardState.revealedKey)
        SharedStore.defaults?.set(true, forKey: SharedStore.needsRefreshKey)
        if var snapshot = SharedStore.readSnapshot() {
            snapshot.dueCards = VaultGrading.dueCount(in: context)
            SharedStore.writeSnapshot(snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Reminders widget and Control Center: mark a reminder done for today.
struct ReminderDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark a reminder done"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Reminder") var reminderID: String

    init() {}
    init(reminderID: UUID) { self.reminderID = reminderID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: reminderID) else { return .result() }
        let context = ModelContext(Store.container)
        var d = FetchDescriptor<Intention>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        if let intention = try? context.fetch(d).first {
            intention.lastDone = Date()
            try? context.save()
        }
        await ReminderNotifications.clear(id: id, on: Date())
        SharedStore.defaults?.set(true, forKey: SharedStore.needsRefreshKey)
        if var snapshot = SharedStore.readSnapshot() {
            snapshot.reminders.removeAll { $0.id == reminderID }
            if snapshot.nextIntentionText != nil, snapshot.reminders.first?.text != snapshot.nextIntentionText {
                snapshot.nextIntentionText = snapshot.reminders.first?.text
                snapshot.nextIntentionTime = snapshot.reminders.first?.time
            }
            SharedStore.writeSnapshot(snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

enum FlashcardState {
    static let revealedKey = "flashcard.revealed"
    static var revealedID: String? { SharedStore.defaults?.string(forKey: revealedKey) }
}

/// Notification identifiers are shared knowledge between the app (which schedules them) and the
/// widget extension (which may cancel them when a reminder is ticked off from the Home Screen).
enum ReminderNotifications {
    static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func prefix(_ id: UUID, on day: Date) -> String { "int.\(id.uuidString).\(dayStamp(day))" }

    static func clear(id: UUID, on day: Date) async {
        let center = UNUserNotificationCenter.current()
        let prefix = prefix(id, on: day)
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(prefix) || $0.hasPrefix("snooze.\(id.uuidString)") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(prefix) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }
}

/// Opens the app at a destination. Used by Control Center controls and App Shortcuts; the
/// route is left in the App Group so the app can act on it however it was launched.
struct OpenMemoryGardenIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Memory Garden"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @Parameter(title: "Destination") var route: String

    init() { route = "today" }
    init(route: String) { self.route = route }

    func perform() async throws -> some IntentResult {
        SharedStore.defaults?.set(route, forKey: SharedStore.pendingRouteKey)
        return .result()
    }
}
