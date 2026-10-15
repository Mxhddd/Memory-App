import Foundation
import AppIntents
import WidgetKit

/// "I forgot something" — one tap from the widget logs an everyday memory slip.
/// Logged slips drive which realm gets more practice; they are never scored against anyone.
struct LogLapseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a memory slip"
    static var description = IntentDescription("Note that you just forgot something. It helps tailor your practice.")

    func perform() async throws -> some IntentResult {
        SharedStore.appendPendingLapse()
        if var snapshot = SharedStore.readSnapshot() {
            snapshot.lapsesToday += 1
            SharedStore.writeSnapshot(snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
