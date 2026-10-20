import Foundation
import UserNotifications
import SwiftData
import MemoryCore

/// Local notifications — fully available on a free Apple ID.
///
/// Strategy: on every launch / change we *replan* the next 7 days of individual notifications
/// (quest reminder, optional evening nudge, intention nag-chains), capped below iOS's 64-pending
/// limit. Completing the quest removes today's remaining nudges; tapping Done stops a nag chain.
@MainActor
enum Notifications {
    static let center = UNUserNotificationCenter.current()

    enum Category: String { case quest = "MG_QUEST", intention = "MG_INTENTION", card = "MG_CARD", refresh = "MG_REFRESH" }
    enum Action: String {
        case done = "MG_DONE", snooze = "MG_SNOOZE10", tonight = "MG_TONIGHT", start = "MG_START"
        case answer = "MG_ANSWER", showCard = "MG_SHOW_CARD"
    }

    static let followUps: [TimeInterval] = [5 * 60, 15 * 60]
    static let maxPlanned = 58

    // MARK: Setup

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    static func registerCategories() {
        let done = UNNotificationAction(identifier: Action.done.rawValue, title: "Done ✓", options: [])
        let snooze = UNNotificationAction(identifier: Action.snooze.rawValue, title: "Snooze 10 min", options: [])
        let tonight = UNNotificationAction(identifier: Action.tonight.rawValue, title: "Tonight", options: [])
        let start = UNNotificationAction(identifier: Action.start.rawValue, title: "Start now", options: [.foreground])
        // Answer a Vault card right from the notification (retrieval practice without opening the app).
        let answer = UNTextInputNotificationAction(identifier: Action.answer.rawValue, title: "Answer", options: [],
                                                   textInputButtonTitle: "Check", textInputPlaceholder: "Your answer")
        let show = UNNotificationAction(identifier: Action.showCard.rawValue, title: "Show me", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.intention.rawValue, actions: [done, snooze, tonight], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.quest.rawValue, actions: [start, tonight], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.card.rawValue, actions: [answer, show], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.refresh.rawValue, actions: [], intentIdentifiers: []),
        ])
    }

    // MARK: Planning

    private struct Planned {
        let id: String
        let date: Date
        let content: UNMutableNotificationContent
    }

    static func replan(profile: Profile) {
        let calendar = Calendar.current
        let now = Date()
        let theme = Theme.forID(profile.theme)
        let questDoneToday = Store.dayRecord().questDone
        var planned: [Planned] = []

        // Quest reminder + evening nudge for the next 7 days, plus a "we miss you" on day 8.
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            if offset == 0 && questDoneToday { continue }
            let stamp = dayStamp(day)
            if let at = calendar.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: day), at > now {
                let c = questContent(profile: profile, theme: theme, missYou: offset == 7)
                planned.append(Planned(id: "quest.\(stamp)", date: at, content: c))
            }
            if profile.eveningNudge, offset < 7, profile.reminderHour < 20,
               let at = calendar.date(bySettingHour: 20, minute: 45, second: 0, of: day), at > now {
                let c = UNMutableNotificationContent()
                c.title = theme.id == .midnightRaccoon ? "\(theme.copy.eveningSession)?" : "A quiet moment for practice?"
                c.body = theme.id == .midnightRaccoon ? "\(profile.mascotName) saved you a spot in the den. Train before bed — sleep locks it in." : "Your training is ready whenever you are."
                c.sound = .default
                c.categoryIdentifier = Category.quest.rawValue
                c.threadIdentifier = "quest"
                c.interruptionLevel = .active
                planned.append(Planned(id: "evening.\(stamp)", date: at, content: c))
            }
        }

        // Intentions the person set (alarm-level ones go through AlarmKit when available).
        let intentions = (try? Store.context.fetch(FetchDescriptorFactory.activeIntentions())) ?? []
        for intention in intentions {
            if intention.level == .alarm && AlarmService.isAuthorized { continue }
            for date in occurrences(of: intention, from: now, days: 7, calendar: calendar) {
                if intention.isDone(on: date, calendar: calendar) { continue }
                let offsets: [TimeInterval] = intention.level == .gentle ? [0] : [0] + followUps
                for (i, offset) in offsets.enumerated() {
                    let at = date.addingTimeInterval(offset)
                    guard at > now else { continue }
                    planned.append(Planned(id: "int.\(intention.id.uuidString).\(dayStamp(date)).\(i)", date: at,
                                           content: intentionContent(intention, followUp: i > 0)))
                }
            }
        }

        // One "recall a card" prompt a day at 13:00 when something is due (the third practice prompt).
        if let card = Quest.dueCards(now.addingTimeInterval(86_400)).first {
            for offset in 0..<2 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                      let at = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: day), at > now, card.due <= at else { continue }
                planned.append(Planned(id: "card.\(dayStamp(day))", date: at, content: cardContent(card)))
                break
            }
        }

        // A free Apple ID signs the app for 7 days: warn 2 days and 1 day before it would stop opening.
        if let expiry = SigningInfo.expiry {
            for hours in [48.0, 24.0] {
                var at = expiry.addingTimeInterval(-hours * 3600)
                if let h = calendar.dateComponents([.hour], from: at).hour, h < 9 || h >= 21 {
                    at = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: at.addingTimeInterval(h < 9 ? -86_400 : 0)) ?? at
                }
                guard at > now else { continue }
                planned.append(Planned(id: "refresh.\(Int(hours))", date: at, content: refreshContent(hoursLeft: hours)))
            }
        }

        let keep = planned.sorted { $0.date < $1.date }.prefix(maxPlanned)
        Task {
            let pending = await center.pendingNotificationRequests()
            // Snoozes survive a replan, except a snoozed training reminder once today is done.
            let ours = pending.map(\.identifier).filter { !$0.hasPrefix("snooze.") || (questDoneToday && $0.hasPrefix("snooze.quest.")) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for p in keep {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: p.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: p.id, content: p.content, trigger: trigger))
            }
        }
        AlarmService.sync(intentions: intentions)
    }

    static func occurrences(of intention: Intention, from now: Date, days: Int, calendar: Calendar) -> [Date] {
        if !intention.repeatsDaily { return [intention.time] }
        let hm = calendar.dateComponents([.hour, .minute], from: intention.time)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { return nil }
            return calendar.date(bySettingHour: hm.hour ?? 9, minute: hm.minute ?? 0, second: 0, of: day)
        }
    }

    private static func questContent(profile: Profile, theme: Theme, missYou: Bool) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        if theme.id == .midnightRaccoon {
            c.title = missYou ? "\(profile.mascotName) misses you" : "\(profile.mascotName) is waiting in the den"
            c.body = missYou ? "Your course picks up exactly where you left off." : "\(theme.copy.questTitle) is ready — about \(profile.dailyMinutes) minutes."
        } else {
            c.title = missYou ? "Welcome back whenever you're ready" : "Today's training is ready"
            c.body = "About \(profile.dailyMinutes) minutes. Your course continues where you left off."
        }
        c.sound = .default
        c.categoryIdentifier = Category.quest.rawValue
        c.threadIdentifier = "quest"
        c.interruptionLevel = .active // Time Sensitive needs a paid developer account
        c.userInfo = ["link": "today"]
        return c
    }

    private static func intentionContent(_ intention: Intention, followUp: Bool) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = followUp ? "Still to do: \(intention.text)" : "Reminder you set"
        c.body = intention.whenCue.isEmpty ? intention.text : "When \(intention.whenCue) → \(intention.text)"
        c.sound = .default
        c.categoryIdentifier = Category.intention.rawValue
        c.threadIdentifier = "intention.\(intention.id.uuidString)"
        c.interruptionLevel = .active
        c.userInfo = ["intention": intention.id.uuidString]
        return c
    }

    private static func cardContent(_ card: MemoryCard) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "Recall one card · \(card.deck)"
        c.body = "\(card.prompt)\n\nThink of the answer first — then long-press to type it."
        c.sound = .default
        c.categoryIdentifier = Category.card.rawValue
        c.threadIdentifier = "card"
        c.interruptionLevel = .passive
        c.userInfo = ["card": card.id.uuidString]
        return c
    }

    private static func refreshContent(hoursLeft: Double) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = hoursLeft > 24 ? "Refresh Memory Garden soon" : "Refresh Memory Garden today"
        c.body = "Open SideStore (LocalDevVPN on) and tap Refresh All, so the app keeps opening. Nothing is lost."
        c.sound = .default
        c.categoryIdentifier = Category.refresh.rawValue
        c.interruptionLevel = .active
        c.userInfo = ["refresh": true]
        return c
    }

    // MARK: One-offs

    /// Grades a Vault card answered from a notification and replies with how it went.
    static func answerCard(_ id: UUID, with text: String) {
        guard let card = VaultGrading.card(id, in: Store.context) else { return }
        let right = AnswerMatch.matches(text, card.answer)
        let retention = Store.profile()?.desiredRetention ?? 0.9
        VaultGrading.grade(card, rating: right ? .good : .again, desiredRetention: retention, in: Store.context)
        let c = UNMutableNotificationContent()
        if right {
            c.title = "Remembered"
            let days = max(1, Int(card.due.timeIntervalSinceNow / 86_400))
            c.body = "\(card.answer) — it comes back in about \(days) day\(days == 1 ? "" : "s")."
        } else {
            c.title = "Not quite"
            c.body = "It's \(card.answer). It'll come back soon so it sticks."
        }
        c.sound = right ? .default : nil
        c.threadIdentifier = "card"
        center.add(UNNotificationRequest(identifier: "card.reply.\(id.uuidString)", content: c,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
        if let profile = Store.profile() { WidgetBridge.update(profile: profile) }
    }

    /// Marks the reminder done for the occurrence on `day` (today unless the card showed another day).
    static func markIntentionDone(_ id: UUID, on day: Date = Date()) {
        guard let intention = (try? Store.context.fetch(FetchDescriptorFactory.intention(id)))?.first else { return }
        intention.lastDone = day
        Store.save()
        let prefix = "int.\(id.uuidString).\(dayStamp(day))"
        Task {
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) || $0.hasPrefix("snooze.\(id.uuidString)") }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
        if let profile = Store.profile() { WidgetBridge.update(profile: profile) }
    }

    static func snooze(_ request: UNNotificationRequest, minutes: Double) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let key = (request.content.userInfo["intention"] as? String) ?? "quest"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, minutes * 60), repeats: false)
        center.add(UNNotificationRequest(identifier: "snooze.\(key).\(Int(Date().timeIntervalSince1970))", content: content, trigger: trigger))
    }

    static func snoozeToTonight(_ request: UNNotificationRequest) {
        let tonight = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        let minutes = tonight > Date() ? tonight.timeIntervalSinceNow / 60 : 120
        snooze(request, minutes: minutes)
    }

    /// Debug: fire one of each reminder type within ~10 seconds.
    static func fireTestReminders(profile: Profile) {
        let theme = Theme.forID(profile.theme)
        let samples: [(String, UNMutableNotificationContent)] = [
            ("test.quest", questContent(profile: profile, theme: theme, missYou: false)),
            ("test.intention", intentionContent(Intention(text: "Test reminder — tap Done", time: Date(), repeatsDaily: false, level: .nag), followUp: false)),
        ]
        for (i, s) in samples.enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(5 + i * 5), repeats: false)
            center.add(UNNotificationRequest(identifier: s.0, content: s.1, trigger: trigger))
        }
    }

    static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

enum FetchDescriptorFactory {
    static func activeIntentions() -> FetchDescriptor<Intention> {
        FetchDescriptor<Intention>(predicate: #Predicate { $0.active == true }, sortBy: [SortDescriptor(\.time)])
    }

    static func intention(_ id: UUID) -> FetchDescriptor<Intention> {
        FetchDescriptor<Intention>(predicate: #Predicate { $0.id == id })
    }
}
