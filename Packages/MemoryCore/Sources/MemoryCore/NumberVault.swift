import Foundation

/// Number Vault: the Major system, done in the right order. Pegs 00–99 are learned ten at a
/// time as ledger items; number challenges only use pegs you already know; and the numbers look
/// like ones you meet in life — phone numbers, PINs, lockers, years in history.
public struct NumberChallenge: Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case phone, pin, locker, year }
    public var kind: Kind
    /// "Hira's phone", "Bank PIN", "Gym locker", "Eiffel Tower completed".
    public var label: String
    public var digits: String
    /// Grouped for reading ("0347 881 290").
    public var display: String
    public var pairs: [String] { MajorSystem.chunks(digits) }
}

public enum NumberVault {
    public static let batchSize = 10
    /// A batch counts as learned once this many of its pegs are recalled at a day's distance.
    public static let learnedPerBatch = 8
    /// Days of FSRS stability that mark a peg as "known".
    public static let knownStability = 2.0

    /// Which pegs to study now: the first batch whose pegs aren't yet known, and the batch after
    /// it only once the current one is mostly learned.
    public static func studyBatch(stability: [Int: Double]) -> [Int] {
        for start in stride(from: 0, to: 100, by: batchSize) {
            let batch = Array(start..<(start + batchSize))
            let known = batch.filter { (stability[$0] ?? 0) >= knownStability }.count
            if known < learnedPerBatch { return batch }
        }
        return []
    }

    public static func knownPegs(stability: [Int: Double]) -> [Int] {
        (0..<100).filter { (stability[$0] ?? 0) >= knownStability }
    }

    /// Accepts the standard peg word, or any word of your own that encodes to the same digits.
    public static func acceptsPeg(_ given: String, for number: Int) -> Bool {
        let want = String(format: "%02d", number)
        return AnswerMatch.matches(given, MajorSystem.peg(number)) || MajorSystem.encode(given) == want
    }

    public static func pegItems(_ numbers: [Int], source: String, at date: Date) -> [MemoryItem] {
        numbers.map { n in
            MemoryItem(id: "peg:\(n)", kind: .peg, cue: String(format: "%02d", n), answer: MajorSystem.peg(n),
                       source: source, createdAt: date)
        }
    }

    /// Real years worth knowing. Only ones whose two digit pairs you've learned are used.
    public static let years: [(event: String, year: Int)] = [
        ("Pakistan's independence", 1947), ("The Lahore Resolution", 1940), ("Quaid-e-Azam was born", 1876),
        ("Allama Iqbal was born", 1877), ("The Badshahi Mosque was completed", 1673), ("The Mughal Empire was founded", 1526),
        ("Minar-e-Pakistan was completed", 1968), ("Faisal Mosque was completed", 1986), ("K2 was first climbed", 1954),
        ("Everest was first climbed", 1953), ("The first powered flight", 1903), ("Penicillin was discovered", 1928),
        ("The Magna Carta was sealed", 1215), ("Columbus reached the Americas", 1492), ("The Titanic sank", 1912),
        ("World War II ended", 1945), ("The Berlin Wall fell", 1989), ("The first iPhone", 2007),
        ("The Moon landing", 1969), ("The Eiffel Tower was completed", 1889), ("The Great Fire of London", 1666),
        ("The French Revolution began", 1789), ("The US Declaration of Independence", 1776),
        ("Shakespeare was born", 1564), ("Newton's Principia was published", 1687), ("Hubble was launched", 1990),
        ("Ibn Battuta set out on his travels", 1325), ("Constantinople fell", 1453),
    ]

    static let contacts = ["Hira", "Omar", "Aunty Nasreen", "the plumber", "Dr. Saeed", "Zara", "the tailor", "Uncle Javed"]

    public static func challenge(kind requested: NumberChallenge.Kind, known: [Int], seed: String) -> NumberChallenge? {
        guard !known.isEmpty else { return nil }
        var rng = SeededRandom("\(seed)#numbers")
        func pegs(_ n: Int) -> String {
            (0..<n).map { _ in String(format: "%02d", known[Int(rng.next() % UInt64(known.count))]) }.joined()
        }
        switch requested {
        case .year:
            let knownSet = Set(known)
            let usable = years.filter { knownSet.contains($0.year / 100) && knownSet.contains($0.year % 100) }
            guard !usable.isEmpty else { return challenge(kind: .pin, known: known, seed: seed) }
            let y = usable[Int(rng.next() % UInt64(usable.count))]
            return NumberChallenge(kind: .year, label: y.event, digits: String(y.year), display: String(y.year))
        case .pin:
            let d = pegs(2)
            return NumberChallenge(kind: .pin, label: ["Bank card PIN", "Door code", "Phone passcode"][Int(rng.next() % 3)], digits: d, display: d)
        case .locker:
            let d = pegs(3)
            return NumberChallenge(kind: .locker, label: ["Gym locker combination", "Bike lock code", "Suitcase lock"][Int(rng.next() % 3)],
                                   digits: d, display: "\(d.prefix(2))-\(d.dropFirst(2).prefix(2))-\(d.suffix(2))")
        case .phone:
            let d = "03" + pegs(4)   // a Pakistani mobile shape: 03xx xxx xxxx would be 11 digits; 10 keeps whole pegs
            let who = contacts[Int(rng.next() % UInt64(contacts.count))]
            return NumberChallenge(kind: .phone, label: "\(who)'s number", digits: d,
                                   display: "\(d.prefix(4)) \(d.dropFirst(4).prefix(3)) \(d.suffix(3))")
        }
    }

    /// Pairs right in their place, for per-chunk feedback.
    public static func score(_ c: NumberChallenge, answer: String) -> (pairsRight: Int, pairs: Int, perfect: Bool) {
        let given = MajorSystem.chunks(answer.filter(\.isNumber))
        let want = c.pairs
        let right = want.indices.filter { $0 < given.count && given[$0] == want[$0] }.count
        return (right, want.count, right == want.count && answer.filter(\.isNumber).count == c.digits.count)
    }

    public static func item(_ c: NumberChallenge, source: String, at date: Date) -> MemoryItem {
        MemoryItem(id: "\(source)#num", kind: .number, cue: c.label, answer: c.digits, source: source, createdAt: date)
    }
}
