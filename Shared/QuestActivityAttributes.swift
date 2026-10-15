import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Lock Screen / Dynamic Island tile for today's quest ("Quest 1/3").
struct QuestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var done: Int
        var total: Int
        var headline: String
    }

    var mascotName: String
    var themeRaw: String
}
#endif
