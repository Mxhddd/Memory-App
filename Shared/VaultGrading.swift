import Foundation
import SwiftData
import MemoryCore

/// One place that grades a Vault card, so the review screen, the flashcard widget and the
/// notification quick-answer all schedule cards the same way (FSRS-6).
enum VaultGrading {
    static func grade(_ card: MemoryCard, rating: Rating, desiredRetention: Double, in context: ModelContext, at date: Date = Date()) {
        let scheduler = FSRSScheduler(desiredRetention: desiredRetention)
        let r = scheduler.retrievability(of: card.fsrs, at: date)
        card.fsrs = scheduler.review(card.fsrs, rating: rating, at: date)
        card.reps += 1
        if rating == .again { card.lapses += 1 }
        context.insert(ReviewLogEntry(cardID: card.id, rating: rating, retrievability: r, date: date))
        try? context.save()
    }

    /// The most overdue card, or nil if nothing is due.
    static func nextDue(in context: ModelContext, now: Date = Date()) -> MemoryCard? {
        var d = FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.due <= now }, sortBy: [SortDescriptor(\.due)])
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    static func dueCount(in context: ModelContext, now: Date = Date()) -> Int {
        (try? context.fetchCount(FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.due <= now }))) ?? 0
    }

    static func card(_ id: UUID, in context: ModelContext) -> MemoryCard? {
        var d = FetchDescriptor<MemoryCard>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    static func desiredRetention(in context: ModelContext) -> Double {
        (try? context.fetch(FetchDescriptor<Profile>()).first?.desiredRetention) ?? 0.9
    }
}
