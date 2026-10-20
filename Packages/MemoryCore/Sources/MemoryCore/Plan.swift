import Foundation

/// The v0.6 games. Each is a place in the garden.
public enum Game: String, Codable, CaseIterable, Sendable, Identifiable {
    case journey       // the Palace: carry a delivery along your route
    case gathering     // the Hall: faces, names and what people do
    case numberVault   // the Vault: Major-system pegs, then real numbers
    case kitchen       // the Kitchen: keep orders in mind through interruptions
    case lookout       // the Tower: a glimpse, faster and wider
    case dayRecall     // the Journal: your own days

    public var id: String { rawValue }
}

/// One week of the six-week course: a technique, taught inside the game that uses it.
public struct Chapter: Equatable, Sendable {
    public var week: Int
    public var title: String
    public var technique: String
    public var teaches: Game
    /// The main game rotates through this list during the week.
    public var rotation: [Game]
}

/// A day's session: a short warm-up of due memories, one main game, one quick game, sometimes a
/// mission and a measurement. Around 10–15 minutes.
public struct DayPlan: Equatable, Sendable {
    public var day: Int
    public var chapter: Chapter
    public var review: Bool
    /// Teach the chapter's technique before playing (first day of the week).
    public var lesson: Bool
    public var main: Game
    public var quick: Game?
    public var mission: Mission?
    /// Walk the Journey backwards today (from week 3, every other Journey).
    public var backwards: Bool
    /// Hear a new story and retell it (baseline days 1–3, then 14, 28, 42, then monthly).
    public var storyTest: Bool
    /// Retell yesterday's story first.
    public var storyRetell: Bool
    public var selfRating: Bool
    /// The 72-word Champion test (35 minutes, optional): early in week 2 and near the end, on days
    /// without a lesson or story.
    public var champion: Bool
}

public enum CoursePlan {
    public static let length = 42

    public static let chapters: [Chapter] = [
        Chapter(week: 1, title: "Make it vivid", technique: "Turn anything into a big, strange, moving picture.",
                teaches: .journey, rotation: [.gathering, .journey]),
        Chapter(week: 2, title: "Faces and names", technique: "Find a feature, turn the name into a picture, link them.",
                teaches: .gathering, rotation: [.gathering, .journey]),
        Chapter(week: 3, title: "Walk it both ways", technique: "A palace you can walk forwards and backwards.",
                teaches: .journey, rotation: [.journey, .gathering]),
        Chapter(week: 4, title: "Numbers become pictures", technique: "The Major system: digits are sounds, sounds make words.",
                teaches: .numberVault, rotation: [.numberVault, .gathering, .journey]),
        Chapter(week: 5, title: "Numbers in the palace", technique: "Peg pictures placed along your route.",
                teaches: .numberVault, rotation: [.numberVault, .gathering, .journey]),
        Chapter(week: 6, title: "Everything together", technique: "Mix techniques for real-life lists, people and numbers.",
                teaches: .journey, rotation: [.journey, .gathering, .numberVault]),
    ]
    /// After the course: keep everything warm.
    public static let maintenance = Chapter(week: 7, title: "Keeping it sharp", technique: "Little and often keeps memories alive.",
                                            teaches: .journey, rotation: [.journey, .gathering, .numberVault])

    public static func chapter(forDay day: Int) -> Chapter {
        let d = max(day, 1)
        return d > length ? maintenance : chapters[min((d - 1) / 7, chapters.count - 1)]
    }

    public static let storyTestDays = [1, 2, 3, 14, 28, 42]
    public static func isStoryTestDay(_ day: Int) -> Bool {
        storyTestDays.contains(day) || (day > length && (day - length) % 30 == 0)
    }

    /// The day's main game: lesson days play the game they teach; other days cycle through the
    /// chapter's rotation, never repeating yesterday and never pre-empting tomorrow's lesson.
    public static func mainGame(day: Int) -> Game {
        var previous: Game?
        var game = Game.journey
        for d in 1...max(day, 1) {
            let ch = chapter(forDay: d)
            let dayInWeek = d > length ? (d - length - 1) % 7 : (d - 1) % 7
            if d <= length && dayInWeek == 0 {
                game = ch.teaches
            } else {
                let r = ch.rotation
                let pos = previous.flatMap { r.firstIndex(of: $0) } ?? -1
                game = r[(pos + 1) % r.count]
                if game == previous { game = r.first { $0 != previous } ?? game }
                if d < length && dayInWeek == 6 {
                    let tomorrow = chapter(forDay: d + 1).teaches
                    if game == tomorrow { game = r.first { $0 != previous && $0 != tomorrow } ?? game }
                }
            }
            previous = game
        }
        return game
    }

    public static func plan(day: Int, minutes: Int, dueItems: Int, seed: String) -> DayPlan {
        let d = max(day, 1)
        let ch = chapter(forDay: d)
        let dayInWeek = d > length ? (d - length - 1) % 7 : (d - 1) % 7
        let main = mainGame(day: d)
        let story = isStoryTestDay(d)
        let lesson = d <= length && dayInWeek == 0
        // A story test takes the quick game's slot; on 10-minute days a lesson does too.
        let quick: Game? = story || (minutes <= 10 && lesson) ? nil : (d % 2 == 1 ? .lookout : .kitchen)
        let weekStart = d - dayInWeek
        let journeysBefore = (weekStart..<d).filter { mainGame(day: $0) == .journey }.count
        return DayPlan(
            day: d, chapter: ch, review: dueItems > 0, lesson: lesson, main: main, quick: quick,
            mission: d >= 3 ? Missions.mission(seed: "\(seed)#\(d)") : nil,
            backwards: main == .journey && ch.week >= 3 && journeysBefore % 2 == 1,
            storyTest: story, storyRetell: isStoryTestDay(d - 1) && d > 1,
            selfRating: d == 1 || (d - 1) % 30 == 0,
            champion: d == 10 || d == length - 2)
    }
}
