import Foundation
import SwiftData
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif
import MemoryCore

/// Writes the widget snapshot into the shared App Group container and reloads timelines.
@MainActor
enum WidgetBridge {
    static func update(profile: Profile) {
        let steps = Quest.steps(for: profile)
        let now = Date()
        let intentions = (try? Store.context.fetch(FetchDescriptorFactory.activeIntentions())) ?? []
        let upcoming = intentions.flatMap { i in
            Notifications.occurrences(of: i, from: now, days: 2, calendar: .current)
                .filter { $0 > now && !i.isDone(on: $0) }
                .map { (i.text, $0) }
        }.min { $0.1 < $1.1 }

        let startOfDay = Calendar.current.startOfDay(for: now)
        let lapses = (try? Store.context.fetchCount(FetchDescriptor<LapseLog>(predicate: #Predicate { $0.date >= startOfDay }))) ?? 0

        let snapshot = WidgetSnapshot(
            themeRaw: profile.themeRaw,
            mascotName: profile.mascotName,
            questDone: steps.filter(\.done).count,
            questTotal: steps.count,
            questComplete: Store.dayRecord().questDone,
            dueCards: Quest.dueCards(now).count,
            nextIntentionText: upcoming?.0,
            nextIntentionTime: upcoming?.1,
            shinies: profile.shinies,
            lapsesToday: lapses,
            updatedAt: now
        )
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// "Quest 1/3" on the Lock Screen and Dynamic Island while today's quest is in progress.
@MainActor
enum LiveActivityService {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true }

    static func sync(profile: Profile) {
        #if canImport(ActivityKit)
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let steps = Quest.steps(for: profile)
        guard !steps.isEmpty else { return }
        let done = steps.filter(\.done).count
        let theme = Theme.forID(profile.theme)
        let complete = done == steps.count
        let state = QuestActivityAttributes.ContentState(
            done: done, total: steps.count,
            headline: complete ? (theme.copy.celebrations.first ?? "Done!") : theme.copy.questTitle
        )
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date())
        let content = ActivityContent(state: state, staleDate: endOfDay)
        let current = Activity<QuestActivityAttributes>.activities

        if complete {
            for activity in current {
                Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(30 * 60))) }
            }
            return
        }
        if let activity = current.first {
            Task { await activity.update(content) }
        } else {
            let hour = Calendar.current.component(.hour, from: Date())
            guard (8..<23).contains(hour) else { return }
            let attributes = QuestActivityAttributes(mascotName: profile.mascotName, themeRaw: profile.themeRaw)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        #endif
    }

    static func endAll() {
        #if canImport(ActivityKit)
        for activity in Activity<QuestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }
}
