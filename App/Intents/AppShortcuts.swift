import AppIntents
import Foundation
import SwiftData
import MemoryCore

// App Intents: Shortcuts, Spotlight, the Action button, Siri phrases and automations
// ("when I get home, start training"). None of this needs a paid developer account.

struct StartTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start today's training"
    static var description = IntentDescription("Opens Memory Garden at the next step of today's trail.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.go(.startQuest)
        return .result()
    }
}

struct ReviewCardsIntent: AppIntent {
    static var title: LocalizedStringResource = "Review Vault cards"
    static var description = IntentDescription("Opens your due Vault cards for a quick review.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Router.shared.go(.review)
        return .result()
    }
}

/// "What's next?" — answered without opening the app.
struct WhatsNextIntent: AppIntent {
    static var title: LocalizedStringResource = "What's next in my training?"
    static var description = IntentDescription("Tells you today's next step, how much is left and your next reminder.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let profile = Store.profile(), profile.onboardingComplete else {
            return .result(dialog: "Open Memory Garden once to set things up.")
        }
        return .result(dialog: IntentDialog(stringLiteral: Briefing.text(for: profile)))
    }
}

struct MarkReminderDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark a reminder done"
    static var description = IntentDescription("Ticks off one of your reminders for today.")

    @Parameter(title: "Reminder") var reminder: ReminderEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        Notifications.markIntentionDone(reminder.id)
        if let profile = Store.profile() { Notifications.replan(profile: profile) }
        return .result(dialog: "Done: \(reminder.text).")
    }
}

struct AddReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a reminder"
    static var description = IntentDescription("Adds a reminder in Memory Garden.")

    @Parameter(title: "What") var text: String
    @Parameter(title: "When") var time: Date
    @Parameter(title: "Every day", default: false) var daily: Bool
    @Parameter(title: "How insistent", default: .nag) var level: ReminderLevelOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(dialog: "What should I remind you about?") }
        Store.context.insert(Intention(text: trimmed, time: time, repeatsDaily: daily, level: level.level))
        Store.save()
        if let profile = Store.profile() {
            Notifications.replan(profile: profile)
            WidgetBridge.update(profile: profile)
        }
        let when = time.formatted(date: daily ? .omitted : .abbreviated, time: .shortened)
        return .result(dialog: "Okay — \(trimmed), \(daily ? "every day at" : "") \(when).")
    }
}

enum ReminderLevelOption: String, AppEnum {
    case gentle, nag, alarm
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reminder level"
    static var caseDisplayRepresentations: [ReminderLevelOption: DisplayRepresentation] = [
        .gentle: "Gentle", .nag: "Keep nudging", .alarm: "Alarm",
    ]
    var level: ReminderLevel { ReminderLevel(rawValue: rawValue) ?? .nag }
}

/// A reminder, as Shortcuts and Siri see it.
struct ReminderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Reminder"
    static var defaultQuery = ReminderQuery()

    var id: UUID
    var text: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(text)") }
}

struct ReminderQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ReminderEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ReminderEntity] { all() }

    @MainActor
    private func all() -> [ReminderEntity] {
        let list = (try? Store.context.fetch(FetchDescriptorFactory.activeIntentions())) ?? []
        return list.map { ReminderEntity(id: $0.id, text: $0.text) }
    }
}

struct MemoryGardenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTrainingIntent(), phrases: [
            "Start training in \(.applicationName)",
            "Start my \(.applicationName) session",
            "Train my memory with \(.applicationName)",
        ], shortTitle: "Start training", systemImageName: "moon.stars.fill")
        AppShortcut(intent: WhatsNextIntent(), phrases: [
            "What's next in \(.applicationName)",
            "What's left in \(.applicationName) today",
        ], shortTitle: "What's next?", systemImageName: "sparkles")
        AppShortcut(intent: ReviewCardsIntent(), phrases: [
            "Review cards in \(.applicationName)",
            "Quiz me in \(.applicationName)",
        ], shortTitle: "Review cards", systemImageName: "rectangle.stack.fill")
        AppShortcut(intent: AddReminderIntent(), phrases: [
            "Add a reminder in \(.applicationName)",
            "Remind me with \(.applicationName)",
        ], shortTitle: "Add reminder", systemImageName: "bell.badge.fill")
        AppShortcut(intent: MarkReminderDoneIntent(), phrases: [
            "Mark a reminder done in \(.applicationName)",
            "I did it in \(.applicationName)",
        ], shortTitle: "Reminder done", systemImageName: "checkmark.circle.fill")
    }
}

/// One spoken/written summary of the day, shared by Siri/Shortcuts and the "What's next" dialog.
@MainActor
enum Briefing {
    static func text(for profile: Profile) -> String {
        let theme = Theme.forID(profile.theme)
        let steps = Quest.steps(for: profile)
        let done = steps.filter(\.done).count
        var parts: [String] = []
        if steps.isEmpty || done == steps.count {
            parts.append("Today's training is done. \(theme.copy.celebrations.first ?? "Well done!")")
        } else if let next = steps.first(where: { !$0.done }) {
            parts.append("\(done) of \(steps.count) done. Next: \(StepText.title(next, theme: theme)).")
        }
        let due = Quest.dueCards().count
        if due > 0 { parts.append("\(due) Vault card\(due == 1 ? "" : "s") ready.") }
        let now = Date()
        let intentions = (try? Store.context.fetch(FetchDescriptorFactory.activeIntentions())) ?? []
        if let next = intentions.flatMap({ i in
            Notifications.occurrences(of: i, from: now, days: 2, calendar: .current).filter { $0 > now && !i.isDone(on: $0) }.map { (i.text, $0) }
        }).min(by: { $0.1 < $1.1 }) {
            parts.append("Next reminder: \(next.0) at \(next.1.formatted(date: .omitted, time: .shortened)).")
        }
        return parts.joined(separator: " ")
    }
}
