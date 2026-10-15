import Foundation

/// Original stimuli with alternate forms. Everything is generated from a seed, so a burst can
/// reuse the *same* set for 7 days (learning curve) and the next burst gets a fresh one.
public enum Stimuli {
    // MARK: Word lists (legacy short forms; sprints & benchmarks use `WordBank`)

    public static let wordForms: [[String]] = [
        ["lantern", "pillow", "carrot", "bridge", "violin", "candle", "garden", "button", "rabbit", "teapot", "mirror", "basket"],
        ["blanket", "cherry", "ladder", "wallet", "dolphin", "hammer", "orange", "kettle", "spider", "window", "pencil", "trumpet"],
        ["feather", "onion", "rocket", "saddle", "parrot", "bucket", "lemon", "anchor", "jacket", "tiger", "spoon", "castle"],
        ["umbrella", "camel", "bottle", "pepper", "comet", "glove", "tractor", "honey", "ribbon", "turtle", "shovel", "piano"],
        ["compass", "melon", "scarf", "wagon", "falcon", "needle", "pumpkin", "harbor", "statue", "slipper", "zebra", "crayon"],
        ["helmet", "mango", "tunnel", "sponge", "goose", "barrel", "cactus", "locket", "spinach", "canoe", "puppet", "drum"],
    ]

    public static let wordFoils: [String] = [
        "pebble", "curtain", "biscuit", "engine", "squirrel", "napkin", "garlic", "lighthouse", "sandal", "kitten",
        "pocket", "walnut", "chimney", "parcel", "beetle", "saucer", "trolley", "almond", "tower", "marble",
        "fountain", "peacock", "ruler", "cabbage", "violet", "satchel", "lobster", "meadow", "thimble", "pigeon",
        "cushion", "radish", "kayak", "oyster", "flute", "monkey", "ladle", "sleeve", "pickle", "harp",
    ]

    public static func wordList(form: Int) -> [String] {
        wordForms[((form % wordForms.count) + wordForms.count) % wordForms.count]
    }

    /// 12 targets + 12 foils, shuffled — tap-to-select recognition (kinder than typing for older users).
    public static func recognitionBoard(targets: [String], seed: String) -> [String] {
        var rng = SeededRandom(seed)
        let used = Set(wordForms.flatMap { $0 })
        let pool = wordFoils.filter { !used.contains($0) }
        let foils = Array(pool.shuffled(using: &rng).prefix(targets.count))
        return (targets + foils).shuffled(using: &rng)
    }

    // MARK: Names (face–name)

    public static let names: [String] = [
        "Ayesha", "Bilal", "Fatima", "Hamza", "Sana", "Omar", "Zara", "Imran", "Nadia", "Faisal",
        "Hina", "Kamran", "Mariam", "Usman", "Rabia", "Tariq", "Amna", "Saad", "Iqra", "Danish",
        "Lily", "Theo", "Maya", "Leo", "Ruby", "Felix", "Ivy", "Hugo", "Nora", "Otto",
    ]

    // MARK: Object–location (stash)

    public static let stashItems: [(String, String)] = [
        ("🔑", "keys"), ("👓", "glasses"), ("📱", "phone"), ("💍", "ring"), ("🧦", "sock"),
        ("✉️", "letter"), ("🪙", "coin"), ("🧸", "teddy"), ("💊", "pill box"), ("🎧", "headphones"),
        ("🕶️", "sunglasses"), ("📒", "notebook"),
    ]

    public struct Placement: Equatable, Sendable {
        public let emoji: String
        public let name: String
        public let cell: Int
    }

    public static func stash(count: Int, gridCells: Int, seed: String) -> [Placement] {
        var rng = SeededRandom(seed)
        let items = stashItems.shuffled(using: &rng).prefix(count)
        let cells = Array(0..<gridCells).shuffled(using: &rng).prefix(count)
        return zip(items, cells).map { Placement(emoji: $0.0.0, name: $0.0.1, cell: $0.1) }
    }

    // MARK: Sequences (working memory)

    public static func sequence(length: Int, gridCells: Int, rng: inout SeededRandom) -> [Int] {
        var out: [Int] = []
        while out.count < length {
            let c = Int.random(in: 0..<gridCells, using: &rng)
            if c != out.last { out.append(c) }
        }
        return out
    }

    // MARK: Runes (invented glyphs — no prior-knowledge confound, ORCA-LLT style)

    /// A 7×7 left-right symmetric glyph built from a short random walk, so it looks like a "letter".
    /// Glyphs that are too plain (a lone bar) are rejected and re-rolled.
    public static func rune(seed: String) -> [[Bool]] {
        var attempt = 0
        while true {
            let r = rawRune(seed: attempt == 0 ? seed : "\(seed)~\(attempt)")
            if isComplex(r) { return r }
            attempt += 1
        }
    }

    /// ≥ 10 filled cells spanning ≥ 4 rows and ≥ 4 columns.
    public static func isComplex(_ r: [[Bool]]) -> Bool {
        let filled = r.joined().filter { $0 }.count
        let rows = r.filter { $0.contains(true) }.count
        let cols = (0..<7).filter { c in r.contains { $0[c] } }.count
        return filled >= 10 && rows >= 4 && cols >= 4
    }

    static func rawRune(seed: String) -> [[Bool]] {
        var rng = SeededRandom(seed)
        var grid = Array(repeating: Array(repeating: false, count: 7), count: 7)
        var x = Int.random(in: 1...3, using: &rng), y = Int.random(in: 0...1, using: &rng)
        for _ in 0..<Int.random(in: 12...18, using: &rng) {
            grid[y][x] = true
            grid[y][6 - x] = true
            switch Int.random(in: 0..<4, using: &rng) {
            case 0: x = max(0, x - 1)
            case 1: x = min(3, x + 1)
            case 2: y = max(0, y - 1)
            default: y = min(6, y + 1)
            }
        }
        // Give it a "baseline" or "crossbar" sometimes for variety.
        if Bool.random(using: &rng) {
            let row = Int.random(in: 2...6, using: &rng)
            for c in 1...5 { grid[row][c] = true }
        }
        return grid
    }

    public static func runeSignature(_ r: [[Bool]]) -> String {
        r.map { $0.map { $0 ? "#" : "." }.joined() }.joined(separator: "/")
    }

    /// `count` mutually distinct runes for one burst.
    public static func runeSet(count: Int, seed: String) -> [[[Bool]]] {
        var seen = Set<String>()
        var out: [[[Bool]]] = []
        var i = 0
        while out.count < count {
            let r = rune(seed: "\(seed)#\(i)")
            if seen.insert(runeSignature(r)).inserted { out.append(r) }
            i += 1
        }
        return out
    }

    public static let runeMeanings: [String] = [
        "river", "salt", "door", "owl", "lamp", "bread", "wind", "seed", "stone", "bell",
        "boat", "milk", "smoke", "fox", "tea", "rain", "rope", "honey", "cloud", "thread",
    ]

    // MARK: Villagers (face–name portraits) — procedurally composed 12×12 pixel faces

    public struct Villager: Equatable, Sendable {
        public let name: String
        public let art: PixelArt
    }

    public static func villagers(count: Int, seed: String) -> [Villager] {
        var rng = SeededRandom(seed)
        let chosen = names.shuffled(using: &rng).prefix(count)
        return chosen.enumerated().map { i, name in
            Villager(name: name, art: portrait(seed: "\(seed)-face-\(i)"))
        }
    }

    static let skinTones: [UInt32] = [0xF6D7B8, 0xE8B98F, 0xC98E64, 0xA36A43, 0x7A4A2C, 0x5A3520]
    static let hairColors: [UInt32] = [0x1C1414, 0x4A2E1E, 0x8A5A2B, 0xD9B45A, 0xB0B0B8, 0x9E3B32, 0x3B2A4A]
    static let shirtColors: [UInt32] = [0xB9A3E3, 0xF4A7C6, 0x9FE3C8, 0x7FD6F0, 0xE8C26A, 0xE86A92, 0x6C8CD5]
    static let scarfColors: [UInt32] = [0x2E6F5E, 0x7A3E6B, 0x2C4A7A, 0xC0563B, 0xD9A441]
    static let backgrounds: [UInt32] = [0x3A3150, 0x2E4057, 0x40304A, 0x2F4A3E, 0x4A3A2E]

    public static func portrait(seed: String) -> PixelArt {
        var rng = SeededRandom(seed)
        let style = Int.random(in: 0..<6, using: &rng) // 0 short, 1 long, 2 bun, 3 scarf, 4 cap, 5 curly
        let glasses = Int.random(in: 0..<4, using: &rng) == 0
        let earring = Int.random(in: 0..<4, using: &rng) == 0
        let beard = style != 3 && Int.random(in: 0..<5, using: &rng) == 0

        // Base 12×12: B background, S skin, H hair, K eyes/outline, M mouth, C shirt
        var g: [[Character]] = [
            Array("BBBBBBBBBBBB"),
            Array("BBBBBBBBBBBB"),
            Array("BBBBSSSSBBBB"),
            Array("BBBSSSSSSBBB"),
            Array("BBBSSSSSSBBB"),
            Array("BBBSKSSKSBBB"),
            Array("BBBSSSSSSBBB"),
            Array("BBBSSMMSSBBB"),
            Array("BBBBSSSSBBBB"),
            Array("BBBBBSSBBBBB"),
            Array("BBCCCCCCCCBB"),
            Array("BCCCCCCCCCCB"),
        ]
        func set(_ y: Int, _ xs: [Int], _ c: Character) { for x in xs { g[y][x] = c } }
        switch style {
        case 0: set(1, [4, 5, 6, 7], "H"); set(2, [3, 4, 5, 6, 7, 8], "H"); set(3, [3, 8], "H")
        case 1: set(1, [4, 5, 6, 7], "H"); set(2, [3, 4, 5, 6, 7, 8], "H"); for y in 3...9 { set(y, [2, 9], "H") }; set(3, [3, 8], "H")
        case 2: set(0, [5, 6], "H"); set(1, [4, 5, 6, 7], "H"); set(2, [3, 4, 5, 6, 7, 8], "H"); set(3, [3, 8], "H")
        case 3: // headscarf framing the face
            set(1, [3, 4, 5, 6, 7, 8], "A"); set(2, [2, 3, 4, 5, 6, 7, 8, 9], "A")
            for y in 3...8 { set(y, [2, 3, 8, 9], "A") }
            set(9, [3, 4, 7, 8], "A"); set(10, [2, 3, 4, 7, 8, 9], "A")
        case 4: set(1, [3, 4, 5, 6, 7, 8], "A"); set(2, [2, 3, 4, 5, 6, 7, 8, 9, 10], "A"); set(3, [3, 8], "H")
        default: set(1, [3, 4, 5, 6, 7, 8], "H"); set(2, [2, 3, 4, 5, 6, 7, 8, 9], "H"); set(3, [2, 3, 8, 9], "H"); set(4, [2, 9], "H")
        }
        if glasses { set(5, [3, 4, 5, 6, 7, 8], "G"); g[5][4] = "K"; g[5][7] = "K" }
        if beard { set(7, [3, 4, 7, 8], "H"); set(8, [4, 5, 6, 7], "H") }
        if earring && style != 3 { g[7][2] = "E" }

        let pal: [Character: UInt32] = [
            "B": backgrounds.randomElement(using: &rng)!,
            "S": skinTones.randomElement(using: &rng)!,
            "H": hairColors.randomElement(using: &rng)!,
            "A": style == 3 ? scarfColors.randomElement(using: &rng)! : shirtColors.randomElement(using: &rng)!,
            "C": shirtColors.randomElement(using: &rng)!,
            "K": 0x1B1626,
            "M": 0xB0505A,
            "G": 0xD9B45A,
            "E": 0xFFE08A,
        ]
        return PixelArt(rows: g.map { String($0) }, palette: pal)
    }
}

/// Lenient answer matching for typed recall (case/diacritic-insensitive, one typo allowed for longer words).
public enum AnswerMatch {
    public static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(_ given: String, _ expected: String) -> Bool {
        let a = normalize(given), b = normalize(expected)
        if a == b { return true }
        return b.count >= 5 && levenshtein(a, b) <= 1
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        for i in 1...x.count {
            var cur = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[y.count]
    }
}
