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
        guard Store.isLive(profile) else { return }
        let steps = Quest.steps(for: profile)
        let now = Date()
        let theme = Theme.forID(profile.theme)
        let intentions = (try? Store.context.fetch(FetchDescriptorFactory.activeIntentions())) ?? []
        let upcoming = intentions.flatMap { i in
            Notifications.occurrences(of: i, from: now, days: 2, calendar: .current)
                .filter { $0 > now && !i.isDone(on: $0) }
                .map { (i, $0) }
        }.sorted { $0.1 < $1.1 }
        let active28 = Quest.activeDays(last: 28)

        let snapshot = WidgetSnapshot(
            themeRaw: profile.themeRaw,
            mascotName: profile.mascotName,
            questDone: steps.filter(\.done).count,
            questTotal: steps.count,
            questComplete: Store.dayRecord().questDone,
            dueCards: Quest.dueCards(now).count,
            nextIntentionText: upcoming.first?.0.text,
            nextIntentionTime: upcoming.first?.1,
            shinies: profile.shinies,
            courseDay: Store.dayRecord().planCourseDay ?? profile.courseDay,
            updatedAt: now,
            steps: steps.map { WidgetSnapshot.Step(title: StepText.title($0, theme: theme), symbol: StepText.symbol($0), done: $0.done) },
            reminders: upcoming.prefix(3).map { WidgetSnapshot.Reminder(id: $0.0.id.uuidString, text: $0.0.text, time: $0.1) },
            growthStage: DenGrowth.stage(activeDaysLast28: active28),
            activeDays28: active28,
            signatureExpiry: SigningInfo.expiry
        )
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
    }
}

/// Today's trail on the Lock Screen and in the Dynamic Island: progress, the next step, and a
/// live countdown while a study timer runs. Everything is updated locally (no push server).
@MainActor
enum LiveActivityService {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true }

    /// The countdown currently shown, if a study timer is running.
    private static var countdown: (end: Date, label: String)?

    static func sync(profile: Profile) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard enabled, Store.isLive(profile) else { endAll(); return }
        let steps = Quest.steps(for: profile)
        guard !steps.isEmpty else { return }
        let done = steps.filter(\.done).count
        let theme = Theme.forID(profile.theme)
        // Once the day is complete it stays complete, even if a late card becomes due.
        let complete = done == steps.count || Store.dayRecord().questDone
        let next = steps.first { !$0.done }
        var state = QuestActivityAttributes.ContentState(
            done: complete ? steps.count : done, total: steps.count,
            headline: complete ? (theme.copy.celebrations.first ?? "Done!") : theme.copy.questTitle,
            nextTitle: complete ? nil : next.map { StepText.title($0, theme: theme) },
            nextSymbol: next.map { StepText.symbol($0) },
            steps: steps.map { complete || $0.done },
            complete: complete
        )
        if let countdown, countdown.end > Date() {
            state.countdownEnd = countdown.end
            state.countdownLabel = countdown.label
        }
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date())
        let content = ActivityContent(state: state, staleDate: endOfDay)
        let current = Activity<QuestActivityAttributes>.activities

        if complete && state.countdownEnd == nil {
            for activity in current {
                Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(30 * 60))) }
            }
            return
        }
        if let activity = current.first(where: { $0.attributes.themeRaw == profile.themeRaw }) {
            Task { await activity.update(content) }
            for other in current where other.id != activity.id { Task { await other.end(nil, dismissalPolicy: .immediate) } }
        } else {
            for other in current { Task { await other.end(nil, dismissalPolicy: .immediate) } }
            let hour = Calendar.current.component(.hour, from: Date())
            guard (6..<23).contains(hour) || state.countdownEnd != nil else { return }
            let attributes = QuestActivityAttributes(mascotName: profile.mascotName, themeRaw: profile.themeRaw)
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        #endif
    }

    /// Show a study countdown on the Lock Screen and Dynamic Island (keeps ticking if you leave the app).
    static func showCountdown(until end: Date, label: String) {
        countdown = (end, label)
        if let profile = Store.profile() { sync(profile: profile) }
    }

    static func clearCountdown() {
        guard countdown != nil else { return }
        countdown = nil
        if let profile = Store.profile() { sync(profile: profile) }
    }

    /// Ends yesterday's activity after midnight (called from the background day rollover too).
    static func endIfStale() {
        #if canImport(ActivityKit)
        for activity in Activity<QuestActivityAttributes>.activities {
            if let stale = activity.content.staleDate, stale < Date() {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
        #endif
    }

    static func endAll() {
        #if canImport(ActivityKit)
        countdown = nil
        for activity in Activity<QuestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }
}
