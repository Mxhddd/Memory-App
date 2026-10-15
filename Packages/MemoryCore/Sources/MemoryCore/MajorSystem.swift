import Foundation

/// The Major system: digits ↔ consonant *sounds*, so numbers become words you can picture.
///   0 s/z · 1 t/d · 2 n · 3 m · 4 r · 5 l · 6 j/sh/ch/soft g · 7 k/hard c/hard g/q · 8 f/v/ph · 9 p/b
/// Vowels and w, h, y are free.
public enum MajorSystem {
    public static let sounds: [String] = [
        "s, z", "t, d", "n", "m", "r", "l", "j, sh, ch, soft g", "k, hard c, hard g", "f, v", "p, b",
    ]

    public static let hints: [String] = [
        "z is for zero", "t has one downstroke", "n has two downstrokes", "m has three downstrokes",
        "r is the last sound of four", "L is 50 in Roman numerals", "a J looks like a mirrored 6",
        "K is made of two 7s", "a script f looks like 8", "p is a mirrored 9",
    ]

    /// Peg words 00–99 (index = number). Every word encodes to its own number (see tests).
    public static let pegs: [String] = [
        "sauce", "seed", "sun", "sumo", "sewer", "sail", "sash", "sock", "sofa", "soap",
        "toes", "toad", "tuna", "dome", "tire", "towel", "dish", "duck", "dove", "tape",
        "nose", "net", "nun", "gnome", "Nero", "nail", "nacho", "neck", "knife", "knob",
        "mouse", "mat", "moon", "mummy", "mower", "mule", "mash", "mug", "movie", "map",
        "rose", "rat", "rain", "ram", "rower", "rail", "roach", "rock", "roof", "rope",
        "lace", "lid", "lion", "lime", "lorry", "lily", "leash", "lock", "lava", "lip",
        "cheese", "sheet", "chain", "jam", "chair", "jail", "judge", "jockey", "chef", "ship",
        "goose", "cat", "coin", "comb", "car", "coal", "cage", "cake", "cave", "cap",
        "face", "foot", "phone", "foam", "fire", "file", "fish", "fig", "fife", "fob",
        "bus", "bat", "bone", "bomb", "bear", "bell", "beach", "book", "beef", "pipe",
    ]

    public static func peg(_ number: Int) -> String { pegs[((number % 100) + 100) % 100] }

    /// Approximate phonetic encoding of an English word to its Major digits —
    /// good enough to check a person's own peg words ("does 'cat' really give 71?").
    public static func encode(_ word: String) -> String {
        let w = Array(word.lowercased().filter(\.isLetter))
        var out = ""
        var i = 0
        func next(_ k: Int) -> Character? { i + k < w.count ? w[i + k] : nil }
        func emit(_ d: Character) { out.append(d) }
        var last: Character? = nil // last consonant letter, to merge doubles (ll, tt…)

        while i < w.count {
            let c = w[i]
            let n1 = next(1)
            // Silent starts and endings
            if i == 0, c == "k" || c == "g", n1 == "n" { i += 1; continue }
            if c == "m", n1 == "b", i + 2 == w.count { emit("3"); i += 2; last = "b"; continue }
            if c == "g", n1 == "h", i > 0 { i += 2; continue } // silent "gh" (night, dough)
            if "aeiouywh".contains(c) { last = nil; i += 1; continue }
            if c == last { i += 1; continue }
            last = c
            switch c {
            case "s", "z": if n1 == "h" { emit("6"); i += 2; continue }; emit("0")
            case "t": if n1 == "h" { emit("1"); i += 2; continue }; emit("1")
            case "d": if n1 == "g" { emit("6"); i += 2; last = "g"; continue }; emit("1")
            case "n": emit("2")
            case "m": emit("3")
            case "r": emit("4")
            case "l": emit("5")
            case "j": emit("6")
            case "c":
                if n1 == "h" { emit("6"); i += 2; continue }
                if n1 == "k" { emit("7"); i += 2; last = "k"; continue }
                if let n = n1, "eiy".contains(n) { emit("0") } else { emit("7") }
            case "g": if let n = n1, "eiy".contains(n), i + 1 < w.count { emit("6") } else { emit("7") }
            case "k", "q": emit("7")
            case "x": emit("7"); emit("0")
            case "f", "v": emit("8")
            case "p": if n1 == "h" { emit("8"); i += 2; continue }; emit("9")
            case "b": emit("9")
            default: break
            }
            i += 1
        }
        return out
    }

    /// Splits a digit string into 2-digit chunks (a trailing single digit stays alone).
    public static func chunks(_ digits: String) -> [String] {
        var out: [String] = []
        var s = Substring(digits)
        while !s.isEmpty {
            out.append(String(s.prefix(2)))
            s = s.dropFirst(2)
        }
        return out
    }

    public static func randomDigits(count: Int, seed: String) -> String {
        var rng = SeededRandom(seed)
        return String((0..<count).map { _ in Character(String(Int.random(in: 0...9, using: &rng))) })
    }
}
