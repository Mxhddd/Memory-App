import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
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

    /// Cancels the alarms we scheduled before and schedules the current alarm-level intentions.
    static func sync(intentions: [Intention]) {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), isAuthorized else { return }
        let previous = (UserDefaults.standard.stringArray(forKey: scheduledKey) ?? []).compactMap(UUID.init(uuidString:))
        for id in previous { try? AlarmManager.shared.cancel(id: id) }

        let now = Date()
        let wanted = intentions.filter { $0.active && $0.level == .alarm && ($0.repeatsDaily || ($0.time > now && !$0.isDone(on: now))) }
        let payload = wanted.map { (id: $0.id, text: $0.text, time: $0.time, repeats: $0.repeatsDaily) }
        UserDefaults.standard.set(wanted.map(\.id.uuidString), forKey: scheduledKey)
        Task {
            for item in payload {
                try? await schedule(id: item.id, text: item.text, time: item.time, repeats: item.repeats)
            }
        }
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
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct IntentionAlarmMetadata: AlarmMetadata {
    var text: String
}
#endif
