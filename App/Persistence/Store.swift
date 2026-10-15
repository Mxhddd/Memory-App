import Foundation
import SwiftData
import MemoryCore

enum Store {
    static let schema = Schema([
        Profile.self, TaskSession.self, MemoryCard.self, ReviewLogEntry.self, Intention.self,
        Supporter.self, DayRecord.self, Palace.self,
    ])

    /// Local-only store (no CloudKit — that needs a paid developer account).
    static let container: ModelContainer = {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .none, cloudKitDatabase: .none)
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

    /// Wipes everything on this phone.
    @MainActor
    static func deleteEverything() {
        func wipe<T: PersistentModel>(_ type: T.Type) { try? context.delete(model: type) }
        wipe(Profile.self); wipe(TaskSession.self); wipe(MemoryCard.self); wipe(ReviewLogEntry.self)
        wipe(Intention.self); wipe(Supporter.self); wipe(DayRecord.self); wipe(Palace.self)
        try? context.save()
        SharedStore.clear()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }
}
