import Foundation
import SwiftData
import MemoryCore

enum Store {
    static let schema = Schema([
        Profile.self, TaskSession.self, MemoryCard.self, ReviewLogEntry.self, Intention.self,
        Supporter.self, DayRecord.self, Palace.self,
    ])

    /// Local-only store (no CloudKit — that needs a paid developer account), kept in the App Group
    /// container so widgets, Control Center controls and App Intents can read and update it too.
    static let container: ModelContainer = {
        let group: ModelConfiguration.GroupContainer = SharedStore.isAvailable ? .identifier(SharedStore.groupID) : .none
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: group, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }()

    @MainActor static var context: ModelContext { container.mainContext }

    @MainActor
    static func profile() -> Profile? {
        try? context.fetch(FetchDescriptor<Profile>()).first
    }

    @MainActor
    static func dayRecord(for date: Date = Date()) -> DayRecord {
        let start = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.day == start })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let record = DayRecord(day: start)
        context.insert(record)
        return record
    }

    @MainActor
    static func save() {
        try? context.save()
    }

    /// Wipes everything on this phone. Objects are deleted one by one (not in a batch) so every
    /// `@Query` notices and the app falls back to onboarding instead of holding deleted rows.
    @MainActor
    static func deleteEverything() {
        func wipe<T: PersistentModel>(_ type: T.Type) {
            for object in (try? context.fetch(FetchDescriptor<T>())) ?? [] { context.delete(object) }
        }
        wipe(TaskSession.self); wipe(MemoryCard.self); wipe(ReviewLogEntry.self); wipe(Intention.self)
        wipe(Supporter.self); wipe(DayRecord.self); wipe(Palace.self); wipe(Profile.self)
        try? context.save()
        SharedStore.clear()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        SharedStore.defaults?.removePersistentDomain(forName: SharedStore.groupID)
    }

    /// True while a model still belongs to the live store (false after "Delete everything").
    static func isLive(_ model: some PersistentModel) -> Bool { model.modelContext != nil && !model.isDeleted }
}
