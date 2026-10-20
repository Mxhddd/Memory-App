import Foundation

/// The Journey: carry a delivery along your own memory palace. Each delivery is something you
/// could actually need to remember — errands, a packing list, a recipe, a talk, the planets —
/// placed one item per stop with a vivid scene, then collected by walking the route again
/// (forwards, and from week 2 backwards too).
public struct JourneyPack: Equatable, Sendable, Identifiable {
    public struct Item: Equatable, Sendable {
        /// What's shown while placing ("pick up the dry cleaning").
        public var label: String
        /// Words that count as recalling it ("dry cleaning", "cleaning", "laundry").
        public var keywords: [String]
        public var keyword: String { keywords.first ?? label }
    }
    public var id: String
    public var title: String
    /// Order matters (a recipe's steps, the planets) — kept as written instead of shuffled.
    public var ordered: Bool
    public var items: [Item]
}

public struct JourneyStop: Equatable, Sendable {
    public var stop: String
    public var item: JourneyPack.Item
    public var scene: String
}

public enum Journey {
    static func pack(_ id: String, _ title: String, ordered: Bool = false, _ lines: [String]) -> JourneyPack {
        JourneyPack(id: id, title: title, ordered: ordered, items: lines.map { line in
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            return .init(label: parts[0], keywords: parts.count > 1 ? Array(parts.dropFirst()) : [parts[0]])
        })
    }

    public static let packs: [JourneyPack] = [
        pack("errands", "Weekend errands", [
            "pick up the dry cleaning|dry cleaning|cleaning|laundry", "buy stamps|stamps", "return the library book|library|book",
            "get the car washed|car wash|car", "buy birthday candles|candles", "collect a parcel|parcel|package",
            "pay the electricity bill|electricity|bill", "get a haircut|haircut|hair", "buy light bulbs|light bulbs|bulbs",
            "drop off old clothes|old clothes|clothes", "pick up medicine|medicine|pharmacy", "buy fresh flowers|flowers",
            "book a table for dinner|table|restaurant", "fix the bicycle tyre|bicycle|tyre|bike", "post a letter|letter",
        ]),
        pack("beach", "Packing for the beach", [
            "sunscreen", "towel", "sunglasses", "flip-flops|flip flops|slippers", "beach umbrella|umbrella",
            "water bottle|water", "sun hat|hat", "swimsuit|swimming costume", "a novel|novel|book", "snacks",
            "camera", "phone charger|charger", "beach ball|ball", "first-aid kit|first aid", "picnic mat|mat",
        ]),
        pack("groceries", "The grocery run", [
            "eggs", "milk", "bread", "tomatoes", "onions", "rice", "lentils|daal|dal", "yogurt|dahi",
            "bananas", "chicken", "spinach", "butter", "lemons", "tea", "garlic",
        ]),
        pack("karahi", "Chicken karahi, step by step", ordered: true, [
            "heat the oil|oil", "add the chicken|chicken", "add garlic|garlic", "add ginger|ginger",
            "add chopped tomatoes|tomatoes|tomato", "add salt|salt", "add red chilli|red chilli|chilli",
            "add black pepper|black pepper|pepper", "add green chillies|green chillies|green chilli",
            "stir in yogurt|yogurt", "sprinkle garam masala|garam masala|masala", "top with fresh coriander|coriander",
        ]),
        pack("planets", "The planets, from the Sun", ordered: true, [
            "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune",
        ]),
        pack("wedding", "The wedding to-do list", [
            "send the invitations|invitations|invites", "book the caterer|caterer|catering", "order the flowers|flowers",
            "book the mehndi artist|mehndi|henna", "hire the photographer|photographer", "tailor fitting|tailor|fitting",
            "order the sweets|sweets|mithai", "string the fairy lights|lights", "choose the music|music",
            "arrange the car|car", "wrap the gifts|gifts|presents", "collect the rings|rings",
        ]),
        pack("morning", "A talk: seven habits for a good morning", ordered: true, [
            "drink a glass of water|water", "stretch for five minutes|stretch|stretching", "step into sunlight|sunlight|sun",
            "write three goals|goals|three goals", "eat a real breakfast|breakfast", "no phone for the first hour|phone|no phone",
            "take a short walk|walk",
        ]),
        pack("wonders", "The new Seven Wonders", [
            "the Great Wall of China|great wall|wall", "Petra", "Christ the Redeemer|christ|redeemer",
            "Machu Picchu", "Chichen Itza", "the Colosseum|colosseum", "the Taj Mahal|taj mahal|taj",
        ]),
        pack("camping", "Camping trip kit", [
            "tent", "sleeping bag", "torch|flashlight", "matches", "compass", "map", "rope", "kettle",
            "rain jacket|raincoat|jacket", "insect spray|mosquito spray|spray", "pillow", "marshmallows",
        ]),
        pack("repairs", "The hardware shop", [
            "screws", "hammer", "paint", "paintbrush|brush", "duct tape|tape", "glue", "nails", "sandpaper",
            "drill bits|drill", "work gloves|gloves", "ladder", "light switch|switch",
        ]),
        pack("party", "A birthday party", [
            "balloons", "the cake|cake", "candles", "paper plates|plates", "juice", "party games|games",
            "gifts|presents", "music", "napkins", "invitations|invites", "streamers|decorations", "ice cream",
        ]),
        pack("doctor", "Questions for the doctor", [
            "blood pressure", "sleep", "vitamin D|vitamin", "knee pain|knee", "eye test|eyes",
            "flu shot|flu|vaccine", "cholesterol", "diet", "exercise", "prescription refill|prescription|refill",
        ]),
        pack("southasia", "The countries of South Asia", [
            "Pakistan", "India", "Bangladesh", "Nepal", "Bhutan", "Sri Lanka", "the Maldives|maldives", "Afghanistan",
        ]),
        pack("spices", "The spice cabinet", [
            "cumin|zeera", "turmeric|haldi", "cardamom|elaichi", "cinnamon|darchini", "cloves|laung",
            "coriander seeds|coriander", "fennel|saunf", "mustard seeds|mustard", "nutmeg", "saffron", "bay leaves|bay leaf",
            "black pepper|pepper",
        ]),
        pack("garden", "Planting the garden", [
            "roses", "jasmine|motia", "mint", "tomato plants|tomatoes", "chillies", "marigolds|genda", "basil",
            "a lemon tree|lemon", "sunflowers", "lavender", "aloe vera|aloe", "bougainvillea",
        ]),
        pack("istanbul", "A day in Istanbul", [
            "the Blue Mosque|blue mosque", "Hagia Sophia", "the Grand Bazaar|grand bazaar|bazaar", "a Bosphorus cruise|bosphorus|cruise",
            "Topkapi Palace|topkapi", "Galata Tower|galata", "the Spice Bazaar|spice bazaar", "the Basilica Cistern|cistern",
            "the Princes' Islands|princes islands|islands", "Istiklal Street|istiklal",
        ]),
    ]

    static let scenes = [
        "A giant {item} is squeezed onto the {stop} — feel how heavy it is.",
        "The {stop} has turned completely into {item}. Touch it.",
        "{Item} bursts out of the {stop} with a loud bang.",
        "{mascot} is juggling {item} on top of the {stop}.",
        "A tiny {item} is dancing and singing on the {stop}.",
        "The {stop} is buried under a mountain of {item}.",
        "{Item} is on fire on the {stop} — smell the smoke!",
        "The {stop} is dripping wet with {item}; it's sticky and cold.",
    ]

    /// Picks a pack for the day (weekly chapters rotate through them) and the items to carry.
    public static func delivery(packID: String? = nil, size: Int, stops: [String], seed: String, mascot: String = "Mochi") -> (pack: JourneyPack, route: [JourneyStop]) {
        var rng = SeededRandom("\(seed)#journey")
        let pack = packs.first { $0.id == packID } ?? packs[Int(rng.next() % UInt64(packs.count))]
        let n = min(size, pack.items.count, stops.count)
        let items = pack.ordered ? Array(pack.items.prefix(n)) : Array(pack.items.shuffled(using: &rng).prefix(n))
        let route = items.enumerated().map { i, item -> JourneyStop in
            let template = scenes[Int(rng.next() % UInt64(scenes.count))]
            let key = item.keyword
            let scene = template
                .replacingOccurrences(of: "{Item}", with: key.prefix(1).uppercased() + key.dropFirst())
                .replacingOccurrences(of: "{item}", with: key)
                .replacingOccurrences(of: "{stop}", with: stops[i].lowercased())
                .replacingOccurrences(of: "{mascot}", with: mascot)
            return JourneyStop(stop: stops[i], item: item, scene: scene)
        }
        return (pack, route)
    }

    /// Any keyword of the item appears in the answer (typo-tolerant, word by word).
    public static func accepts(_ given: String, _ item: JourneyPack.Item) -> Bool {
        let g = AnswerMatch.normalize(given)
        guard !g.isEmpty else { return false }
        for k in item.keywords + [item.label] {
            let key = AnswerMatch.normalize(k)
            if AnswerMatch.matches(g, key) { return true }
            if key.contains(" ") {
                if g.contains(key) { return true }   // "the dry cleaning" contains "dry cleaning"
            } else if g.split(separator: " ").contains(where: { AnswerMatch.matches(String($0), key) }) {
                return true                           // word by word, so "car" doesn't match "card"
            }
        }
        return false
    }

    /// Eight choices for recognition mode: the item plus look-alikes from the same pack first.
    public static func choices(for stop: JourneyStop, pack: JourneyPack, seed: String) -> [String] {
        var rng = SeededRandom("\(seed)#pick#\(stop.stop)")
        let others = pack.items.filter { $0 != stop.item }.shuffled(using: &rng).prefix(7).map(\.keyword)
        return ([stop.item.keyword] + others).shuffled(using: &rng)
    }

    /// Ledger items: the delivery's items, each cued by pack, position and stop.
    public static func items(route: [JourneyStop], pack: JourneyPack, palace: String, source: String, at date: Date) -> [MemoryItem] {
        route.enumerated().map { i, s in
            MemoryItem(id: "\(source)#\(i)", kind: .delivery, cue: "\(pack.title) · \(palace) · stop \(i + 1) · \(s.stop)",
                       answer: s.item.keyword, alternatives: Array(s.item.keywords.dropFirst()) + [s.item.label],
                       source: source, createdAt: date)
        }
    }

    /// Size ladder for the delivery (capped later by the palace's number of stops).
    public static func staircase(start: Double = 5) -> Staircase {
        Staircase(start: start, lower: 3, upper: 20, scale: .additive, harder: 1, easier: -1)
    }
}
