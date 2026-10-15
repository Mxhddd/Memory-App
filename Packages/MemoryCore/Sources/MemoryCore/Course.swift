import Foundation

/// The 6-week Memory Palace program, modelled on the training used by Dresler et al. (2017,
/// *Neuron*): daily method-of-loci practice took recall of 72 words from ~26 to ~62 in 40 days,
/// shifted brain connectivity toward memory athletes' patterns, and lasted 4 months.
///
/// Week 1: imagery + first palace · Week 2: Major system for numbers ·
/// Weeks 3–6: daily sprints that grow as accuracy stays ≥ 80 %.
public struct Lesson: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let pages: [String]
    public let exercise: String
}

public enum DrillKind: String, Codable, Sendable {
    case routeWalk, wordSprint, numberSprint, faceName
}

public struct CourseDrill: Equatable, Sendable {
    public var kind: DrillKind
    public var size: Int          // words, digits, faces, or stops
}

public struct CourseDay: Equatable, Sendable {
    public var day: Int           // 1…42
    public var week: Int
    public var lesson: Lesson?
    public var drills: [CourseDrill]
}

public enum Course {
    public static let length = 42

    public static let lessons: [Lesson] = [
        Lesson(id: "images", title: "Why images stick",
               pages: [
                "Your brain evolved to remember places and vivid scenes, not lists. Memory champions aren't born different — they turn information into pictures and put them somewhere.",
                "A good memory image is BIG, MOVING, STRANGE and touches your senses. A 'pen' is forgettable. A giant pen squirting ink all over your pillow is not.",
                "Add feeling: funny, gross, a little dramatic. Emotion tags memories as important.",
               ],
               exercise: "Picture: an elephant wearing your shoes, a teapot singing opera, a banana used as a phone. Hold each for 3 seconds."),
        Lesson(id: "palace", title: "Build your first palace",
               pages: [
                "A memory palace is a route you already know — your home, your street, your school.",
                "Walk it in your head and pick stops in a fixed order: front door, shoe rack, sofa, TV, window… Stops should be distinct and spread out.",
                "Start with 10 stops. You'll add more later. Always walk the same direction.",
               ],
               exercise: "Create your first palace with at least 10 stops, then walk it in order."),
        Lesson(id: "placing", title: "Placing images",
               pages: [
                "To remember a list, put one image at each stop. Make it INTERACT with the stop: the carrot isn't near the door — it's jammed in the keyhole, snapping as you turn the key.",
                "Spend a few seconds per stop. Speed comes later; vividness comes first.",
                "To recall, simply walk the route again. The stops cue the images.",
               ],
               exercise: "Word Sprint: 10 words, one per stop."),
        Lesson(id: "linking", title: "Exaggerate and connect",
               pages: [
                "If an image fades, it wasn't strange enough. Make it huge, multiply it (a thousand candles), set it on fire, make it smell.",
                "Abstract word? Use a sound-alike: 'justice' → a juice box wearing a judge's wig.",
                "Two items at one stop? Make them fight or merge.",
               ],
               exercise: "Word Sprint: 12 words. Try making every image move."),
        Lesson(id: "backwards", title: "Walk it backwards",
               pages: [
                "A strong palace works in both directions. Walking it backwards tests whether your images are truly anchored.",
                "Reuse palaces freely: new images overwrite old ones within a day or two. Champions keep several palaces in rotation.",
               ],
               exercise: "Route walk, then a 12-word sprint recalled from the last stop to the first in your head."),
        Lesson(id: "names", title: "Names and faces",
               pages: [
                "Names are hard because they're abstract. Turn the name into an image (Hamza → hamster, Ruby → a red gem).",
                "Pick a striking feature of the face — eyebrows, chin, hair — and put the name image ON it: a hamster nesting in his eyebrows.",
               ],
               exercise: "Names & Faces with an image hook for each person."),
        Lesson(id: "week1", title: "Review: your system so far",
               pages: [
                "Images that are big, moving, strange and emotional. Stops that are distinct and ordered. One image per stop, interacting with it.",
                "Next week: numbers — the thing most people believe they can't remember.",
               ],
               exercise: "Word Sprint: 15 words."),
        Lesson(id: "major1", title: "The Major system, 0–4",
               pages: [
                "Numbers are invisible. The Major system turns digits into consonant SOUNDS, and sounds into words you can picture.",
                "0 = s/z (zero) · 1 = t/d (one downstroke) · 2 = n (two downstrokes) · 3 = m (three) · 4 = r (four ends in r).",
                "Vowels are free: 21 = n,t → 'net'. 14 = t,r → 'tire'.",
               ],
               exercise: "Learn pegs 00–49 in the Vault (Major pegs deck)."),
        Lesson(id: "major2", title: "The Major system, 5–9",
               pages: [
                "5 = L (Roman 50) · 6 = j/sh/ch/soft g (J looks like a mirrored 6) · 7 = k/hard c/hard g (K = two 7s) · 8 = f/v (script f ≈ 8) · 9 = p/b (p is a mirrored 9).",
                "Now every 2-digit number has a picture: 71 = cat, 92 = bone, 38 = movie.",
               ],
               exercise: "Learn pegs 50–99, then a 6-digit Number Sprint."),
        Lesson(id: "numbers", title: "Numbers in the palace",
               pages: [
                "Split a long number into pairs: 7192 → 71 92 → cat, bone. Put each image at a stop: a cat chewing a bone on your doormat.",
                "Phone numbers, PINs you're allowed to know, dates — all become stories along your route.",
               ],
               exercise: "Number Sprint: 10 digits."),
        Lesson(id: "second", title: "A second palace",
               pages: [
                "Bigger lists need more stops. Build a second palace with 20+ stops — a relative's home, your workplace, a favourite walk.",
                "Having two palaces lets you rotate: use one today, the other tomorrow, so old images don't interfere.",
               ],
               exercise: "Create a palace with 20 stops and walk it."),
        Lesson(id: "speed", title: "Speed and the champion's loop",
               pages: [
                "From here on, each sprint grows when you score 80 % or more. Keep images vivid; let speed follow.",
                "The next-day check matters most: it shows what consolidated overnight. Sleep is when memories set.",
               ],
               exercise: "Word Sprint at your current level."),
    ]

    public static func lesson(_ id: String) -> Lesson? { lessons.first { $0.id == id } }

    /// Lesson schedule by course day.
    static let lessonDays: [Int: String] = [
        1: "images", 2: "palace", 3: "placing", 4: "linking", 5: "backwards", 6: "names", 7: "week1",
        8: "major1", 10: "major2", 12: "numbers", 15: "second", 16: "speed",
    ]

    /// Today's plan. `wordLevel` / `digitLevel` are the person's current adaptive sprint sizes.
    public static func day(_ day: Int, wordLevel: Int, digitLevel: Int) -> CourseDay {
        let d = min(max(day, 1), length)
        let week = (d - 1) / 7 + 1
        var drills: [CourseDrill] = []
        switch d {
        case 1: break
        case 2: drills = [CourseDrill(kind: .routeWalk, size: 10)]
        case 3: drills = [CourseDrill(kind: .routeWalk, size: 10), CourseDrill(kind: .wordSprint, size: 10)]
        case 4, 5: drills = [CourseDrill(kind: .wordSprint, size: 12)]
        case 6: drills = [CourseDrill(kind: .faceName, size: 6)]
        case 7: drills = [CourseDrill(kind: .wordSprint, size: 15)]
        case 8...11: drills = [CourseDrill(kind: .wordSprint, size: max(wordLevel, 15))]
        case 12...14: drills = [CourseDrill(kind: .numberSprint, size: max(digitLevel, 10))]
        case 15: drills = [CourseDrill(kind: .routeWalk, size: 20)]
        default:
            // Weeks 3–6 rotate: words, numbers, words, faces.
            switch (d - 16) % 4 {
            case 0, 2: drills = [CourseDrill(kind: .wordSprint, size: wordLevel)]
            case 1: drills = [CourseDrill(kind: .numberSprint, size: digitLevel)]
            default: drills = [CourseDrill(kind: .faceName, size: 8), CourseDrill(kind: .wordSprint, size: max(10, wordLevel - 5))]
            }
        }
        return CourseDay(day: d, week: week, lesson: lessonDays[d].flatMap(lesson), drills: drills)
    }

    /// Adaptive sprint size: grow at ≥ 80 % in-place accuracy, ease off below 50 %.
    public static func nextWordLevel(current: Int, accuracy: Double) -> Int {
        if accuracy >= 0.8 { return min(current + 5, 100) }
        if accuracy < 0.5 { return max(current - 5, 10) }
        return current
    }

    public static func nextDigitLevel(current: Int, accuracy: Double) -> Int {
        if accuracy >= 0.8 { return min(current + 4, 200) }
        if accuracy < 0.5 { return max(current - 4, 6) }
        return current
    }

    /// Encoding time budget: generous early, tighter as people improve (~6 s per word, ~3 s per digit).
    public static func encodingSeconds(kind: DrillKind, size: Int) -> Int {
        switch kind {
        case .wordSprint: return max(60, size * 6)
        case .numberSprint: return max(45, size * 3)
        case .faceName: return max(45, size * 8)
        case .routeWalk: return 0
        }
    }
}

/// Technique-free benchmarks: day 0, 14, 28, 42, then monthly. They measure whether
/// training transfers to plain remembering — the honest test of "my memory improved".
public struct BenchmarkPlanner: Sendable {
    public var start: Date
    public var calendar: Calendar

    public static let earlyDays = [0, 14, 28, 42]
    public static let laterEvery = 30

    public init(start: Date, calendar: Calendar = .current) {
        self.start = calendar.startOfDay(for: start)
        self.calendar = calendar
    }

    public func dueDays(through day: Int) -> [Int] {
        var days = Self.earlyDays.filter { $0 <= day }
        var d = 42 + Self.laterEvery
        while d <= day { days.append(d); d += Self.laterEvery }
        return days
    }

    public func dayIndex(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// Due if a scheduled benchmark day has passed since the last completed one.
    public func isDue(on date: Date, lastCompleted: Date?) -> Bool {
        let today = dayIndex(date)
        guard let latest = dueDays(through: today).last else { return false }
        guard let last = lastCompleted else { return true }
        return dayIndex(last) < latest
    }

    /// Which alternate form to use for the n-th benchmark session.
    public static func form(forSession n: Int) -> Int { n % WordBank.benchmarkForms }
}

/// "Is this a real improvement or just noise?" — reliable-change thresholds per benchmark.
/// SDs and reliabilities are conservative literature-style defaults; personal values replace
/// them once a few sessions exist.
public enum Improvement {
    public struct Norms: Sendable {
        public var sd: Double
        public var reliability: Double
        public var expectedPracticeGain: Double // retest gain with no training
    }

    public static let wordRecall = Norms(sd: 4.0, reliability: 0.80, expectedPracticeGain: 1.0)   // words of 30
    public static let digitSpan = Norms(sd: 1.1, reliability: 0.75, expectedPracticeGain: 0.2)    // digits
    public static let nBack = Norms(sd: 0.8, reliability: 0.80, expectedPracticeGain: 0.3)        // n level

    /// True when the gain beats noise *and* plain test practice (practice-adjusted RCI > 1.645).
    public static func isReliable(baseline: Double, latest: Double, norms: Norms) -> Bool {
        ReliableChange.practiceAdjusted(x1: baseline, x2: latest, expectedGain: norms.expectedPracticeGain,
                                        sd: norms.sd, reliability: norms.reliability) > 1.645
    }
}
