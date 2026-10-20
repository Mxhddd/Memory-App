import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Lock Screen / Dynamic Island tile for today's training: the trail of steps, what's next, and a
/// countdown while a study timer runs. Updated locally by the app (no push needed).
struct QuestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var done: Int
        var total: Int
        var headline: String
        /// Title and SF Symbol of the next step ("Midnight Sprint · 15 words").
        var nextTitle: String? = nil
        var nextSymbol: String? = nil
        /// One flag per step, for the mini trail.
        var steps: [Bool] = []
        var complete: Bool = false
        /// While a study timer runs: when it ends, and what it's for.
        var countdownEnd: Date? = nil
        var countdownLabel: String? = nil
    }

    var mascotName: String
    var themeRaw: String
}
#endif
