import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

/// iOS 26+ AlarmKit: user-set intentions at the "Alarm" level ring through Silent mode and Focus,
/// full-screen, like the Clock app. No paid entitlement needed — just a one-time permission.
/// On older iOS (or if permission is denied) the notification nag-chain is used instead.
@MainActor
enum AlarmService {
    private static let scheduledKey = "alarmkit.scheduled"

    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static var isAuthorized: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return AlarmManager.shared.authorizationState == .authorized
        }
        #endif
        return false
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        }
        #endif
        return false
    }

    /// Brings AlarmKit in line with the alarm-level reminders, touching only what changed
    /// (each alarm is remembered with a signature of its text, time and repeat).
    static func sync(intentions: [Intention]) {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), isAuthorized else { return }
        let previous = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: String] ?? [:]
        let now = Date()
        let wanted = intentions.filter { $0.active && $0.level == .alarm && ($0.repeatsDaily || ($0.time > now && !$0.isDone(on: now))) }
        var next: [String: String] = [:]
        var toSchedule: [(id: UUID, text: String, time: Date, repeats: Bool)] = []
        for i in wanted {
            let hm = Calendar.current.dateComponents([.hour, .minute], from: i.time)
            let signature = i.repeatsDaily ? "\(i.text)|daily|\(hm.hour ?? 0):\(hm.minute ?? 0)" : "\(i.text)|\(Int(i.time.timeIntervalSince1970))"
            next[i.id.uuidString] = signature
            if previous[i.id.uuidString] != signature { toSchedule.append((i.id, i.text, i.time, i.repeatsDaily)) }
        }
        for (key, signature) in previous where next[key] != signature {
            if let id = UUID(uuidString: key) { try? AlarmManager.shared.cancel(id: id) }
        }
        UserDefaults.standard.set(next, forKey: scheduledKey)
        Task {
            for item in toSchedule {
                try? await schedule(id: item.id, text: item.text, time: item.time, repeats: item.repeats)
            }
        }
        #endif
    }

    /// Cancels every alarm this app scheduled (used before "Delete everything").
    static func cancelAll() {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        let previous = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: String] ?? [:]
        for key in previous.keys { if let id = UUID(uuidString: key) { try? AlarmManager.shared.cancel(id: id) } }
        UserDefaults.standard.removeObject(forKey: scheduledKey)
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func schedule(id: UUID, text: String, time: Date, repeats: Bool) async throws {
        let title: LocalizedStringResource = "\(text)"
        let stop = AlarmButton(text: "Done", textColor: .white, systemImageName: "checkmark.circle.fill")
        let alert = AlarmPresentation.Alert(title: title, stopButton: stop)
        let attributes = AlarmAttributes<IntentionAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: IntentionAlarmMetadata(text: text),
            tintColor: Color(hex: 0xF4A7C6)
        )
        let schedule: Alarm.Schedule
        if repeats {
            let hm = Calendar.current.dateComponents([.hour, .minute], from: time)
            schedule = .relative(.init(
                time: .init(hour: hm.hour ?? 9, minute: hm.minute ?? 0),
                repeats: .weekly([.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
            ))
        } else {
            schedule = .fixed(time)
        }
        let configuration = AlarmManager.AlarmConfiguration<IntentionAlarmMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: AlarmDoneIntent(intentionID: id),
            secondaryIntent: nil,
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
    #endif
}

#if canImport(AlarmKit)
/// The alarm's "Done" button: stops the alarm and ticks the reminder off for today.
@available(iOS 26.0, *)
struct AlarmDoneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reminder done"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Reminder") var intentionID: String

    init() {}
    init(intentionID: UUID) { self.intentionID = intentionID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: intentionID) {
            try? AlarmManager.shared.stop(id: id)
            Notifications.markIntentionDone(id)
        }
        return .result()
    }
}

@available(iOS 26.0, *)
struct IntentionAlarmMetadata: AlarmMetadata {
    var text: String
}
#endif
