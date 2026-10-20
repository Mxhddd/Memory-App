import Foundation

/// The Gathering: meet people at an event (a face, a name, what they do), and meet them again
/// days later somewhere else. Faces are built from many independent features so that real
/// details — brows, nose, glasses, a beard, grey hair — are what tell people apart, and the
/// test shows them smiling or turned, so it can't be passed by matching a picture.
public struct Portrait: Codable, Equatable, Sendable {
    public enum Pose: Int, Codable, Sendable { case front, smile, turned }

    public var female: Bool
    public var age: Int        // 0 young, 1 middle-aged, 2 older
    public var face: Int       // 0 round, 1 oval, 2 long, 3 square
    public var skin: Int       // 0–5
    public var hair: Int       // 0–5 (styles differ by gender; female 5 = headscarf)
    public var hairColor: Int  // 0 black, 1 dark brown, 2 auburn, 3 blonde, 4 grey
    public var brows: Int      // 0 thin, 1 thick, 2 arched, 3 straight
    public var eyes: Int       // 0 round, 1 almond, 2 narrow, 3 wide-set
    public var nose: Int       // 0 small, 1 long, 2 wide, 3 button
    public var mouth: Int      // 0 thin, 1 full, 2 wide
    public var glasses: Int    // 0 none, 1 round, 2 rectangular
    public var beard: Int      // 0 none, 1 moustache, 2 stubble, 3 full (men only)
    public var mark: Int       // 0 none, 1 freckles, 2 mole

    /// How many visible features differ — used to keep everyone at an event distinguishable.
    public func differences(to o: Portrait) -> Int {
        [female != o.female, age != o.age, face != o.face, skin != o.skin, hair != o.hair,
         hairColor != o.hairColor, brows != o.brows, eyes != o.eyes, nose != o.nose,
         mouth != o.mouth, glasses != o.glasses, beard != o.beard, mark != o.mark].filter { $0 }.count
    }

    static func random(_ rng: inout SeededRandom) -> Portrait {
        func pick(_ n: Int) -> Int { Int(rng.next() % UInt64(n)) }
        let female = rng.next() % 2 == 0
        let age = pick(3)
        var hairColor = pick(4)
        if age == 2 && rng.unit() < 0.7 { hairColor = 4 }
        return Portrait(
            female: female, age: age, face: pick(4), skin: pick(6), hair: pick(6), hairColor: hairColor,
            brows: pick(4), eyes: pick(4), nose: pick(4), mouth: pick(3),
            glasses: rng.unit() < 0.3 ? 1 + pick(2) : 0,
            beard: female ? 0 : (rng.unit() < 0.45 ? 1 + pick(3) : 0),
            mark: rng.unit() < 0.25 ? 1 + pick(2) : 0)
    }
}

public struct Person: Codable, Equatable, Sendable, Identifiable {
    public var id: String          // "p:<event seed>:<index>" — regenerates the same person
    public var name: String
    public var job: String
    public var hometown: String
    public var portrait: Portrait
}

public struct GatheringEvent: Equatable, Sendable {
    public var seed: String
    public var setting: String     // "a wedding", "a book club"…
    public var people: [Person]
}

public enum Gathering {
    public static let femaleNames = [
        "Ayesha", "Fatima", "Zainab", "Hira", "Sana", "Mahnoor", "Iqra", "Amna", "Sadia", "Rabia",
        "Nida", "Mariam", "Laila", "Saba", "Huma", "Farah", "Emma", "Sofia", "Grace", "Chloe",
        "Hannah", "Lucy", "Mei", "Yuki", "Priya", "Ana", "Olivia", "Leila", "Noor", "Zara",
    ]
    public static let maleNames = [
        "Omar", "Ali", "Bilal", "Hamza", "Usman", "Faisal", "Imran", "Tariq", "Kamran", "Saad",
        "Zain", "Junaid", "Asad", "Haris", "Daniyal", "Adeel", "James", "Leo", "Noah", "Daniel",
        "Lucas", "Ken", "Raj", "Diego", "Sam", "Felix", "Yusuf", "Ibrahim", "Rayan", "Arman",
    ]
    /// Jobs you can picture — a hook for a vivid image.
    public static let jobs = [
        "baker", "pilot", "dentist", "florist", "plumber", "tailor", "chef", "firefighter",
        "librarian", "farmer", "photographer", "architect", "nurse", "judge", "mechanic", "potter",
        "beekeeper", "jeweller", "astronomer", "fisherman", "carpenter", "violinist", "gardener",
        "journalist", "vet", "painter", "magician", "teacher", "banker", "scientist", "cricket coach",
        "perfumer", "bus driver", "calligrapher", "chemist", "poet",
    ]
    public static let hometowns = [
        "Lahore", "Karachi", "Islamabad", "Peshawar", "Quetta", "Multan", "Hunza", "Murree",
        "Sialkot", "Faisalabad", "Hyderabad", "Gilgit", "Skardu", "London", "Paris", "Istanbul",
        "Dubai", "Toronto", "Tokyo", "Cairo", "Rome", "Madrid", "Lisbon", "Kyoto", "Nairobi",
        "Sydney", "Oslo", "Vienna", "Prague", "Marrakesh",
    ]
    public static let settings = [
        "a wedding", "a book club", "a neighbourhood picnic", "an art opening", "a cricket match",
        "a cooking class", "a train journey", "a museum tour", "a garden party", "a school reunion",
    ]
    /// Everyone at one event differs from everyone else in at least this many features.
    public static let minDifferences = 5

    public static func event(seed: String, size: Int) -> GatheringEvent {
        var rng = SeededRandom("\(seed)#gathering")
        let setting = settings[Int(rng.next() % UInt64(settings.count))]
        var used = Set<String>()
        var people: [Person] = []
        var jobs = Gathering.jobs.shuffled(using: &rng)
        for i in 0..<max(1, min(size, 12)) {
            var portrait = Portrait.random(&rng)
            for _ in 0..<60 where people.contains(where: { $0.portrait.differences(to: portrait) < minDifferences }) {
                portrait = Portrait.random(&rng)
            }
            let pool = (portrait.female ? femaleNames : maleNames).filter { !used.contains($0) }
            let name = pool[Int(rng.next() % UInt64(pool.count))]
            used.insert(name)
            let job = jobs.removeFirst()
            let town = hometowns[Int(rng.next() % UInt64(hometowns.count))]
            people.append(Person(id: "p:\(seed):\(i)", name: name, job: job, hometown: town, portrait: portrait))
        }
        return GatheringEvent(seed: seed, setting: setting, people: people)
    }

    /// Rebuilds a person from their id (events are deterministic, so nothing else is stored).
    public static func person(id: String) -> Person? {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.first == "p", let index = Int(parts.last!) else { return nil }
        let seed = parts[1..<(parts.count - 1)].joined(separator: ":")
        let people = event(seed: seed, size: max(index + 1, 8)).people
        return people.indices.contains(index) ? people[index] : nil
    }

    /// Ledger items for one person: their face → name, and their name → job.
    public static func items(for p: Person, source: String, at date: Date) -> [MemoryItem] {
        [MemoryItem(id: "\(p.id)#name", kind: .personName, cue: p.id, answer: p.name, source: source, createdAt: date),
         MemoryItem(id: "\(p.id)#job", kind: .personFact, cue: p.id, answer: p.job, source: source, createdAt: date)]
    }

    /// Four names to choose from for recognition mode: the right one plus same-gender look-alikes.
    public static func nameChoices(for p: Person, among others: [Person], seed: String) -> [String] {
        var rng = SeededRandom("\(seed)#choices#\(p.id)")
        let sameGender = p.portrait.female ? femaleNames : maleNames
        let fromEvent = others.filter { $0.id != p.id && $0.portrait.female == p.portrait.female }.map(\.name)
        var pool = Array(Set(fromEvent + sameGender.shuffled(using: &rng).prefix(6))).filter { $0 != p.name }.sorted()
        pool.shuffle(using: &rng)
        return ([p.name] + pool.prefix(3)).shuffled(using: &rng)
    }
}
