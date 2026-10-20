import WidgetKit
import SwiftUI
import AppIntents

// iOS 18 Control Center / Lock Screen / Action button controls. No paid entitlement needed.

struct StartTrainingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mxhddd.memorygarden.control.start") {
            ControlWidgetButton(action: OpenMemoryGardenIntent(route: "quest")) {
                Label("Start training", systemImage: "moon.stars.fill")
            }
        }
        .displayName("Start training")
        .description("Opens Memory Garden at the next step of today's trail.")
    }
}

struct ReviewCardControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mxhddd.memorygarden.control.review") {
            ControlWidgetButton(action: OpenMemoryGardenIntent(route: "review")) {
                Label("Review cards", systemImage: "rectangle.stack.fill")
            }
        }
        .displayName("Review Vault cards")
        .description("Jump straight into your due Vault cards.")
    }
}

/// "Done" for the next reminder, right from Control Center.
struct ReminderDoneControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mxhddd.memorygarden.control.reminder", provider: NextReminderValue()) { next in
            // Control builders can't branch, so one button: with no reminder its id is empty and it does nothing.
            ControlWidgetButton(action: ReminderDoneIntent(reminderID: next?.id ?? "")) {
                Label(next?.text ?? "No reminders", systemImage: next == nil ? "bell.slash" : "checkmark.circle")
            }
        }
        .displayName("Reminder done")
        .description("Tick off your next reminder.")
    }
}

struct NextReminderValue: ControlValueProvider {
    var previewValue: WidgetSnapshot.Reminder? { WidgetSnapshot.Reminder(id: UUID().uuidString, text: "Call Aunty", time: Date()) }

    func currentValue() async throws -> WidgetSnapshot.Reminder? {
        SharedStore.readSnapshot()?.reminders.first { $0.time > Date().addingTimeInterval(-3600) }
    }
}
