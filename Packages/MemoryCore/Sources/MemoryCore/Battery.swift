import Foundation

/// How progress is measured in v0.6, kept separate from what's trained:
/// - **Everyday transfer:** retell a short story right away and again the next day, *without*
///   any special technique (like remembering a conversation or the news).
/// - **Speed:** the Lookout threshold (from the game itself).
/// - **Names a day later** and **mission hit rate** (from the Gathering and missions).
/// - **How memory feels:** a monthly six-question self-rating.
/// Each is judged against your own three-session baseline (`Improvement.personal`).
public struct Story: Equatable, Sendable, Identifiable {
    public struct Unit: Equatable, Sendable {
        public var idea: String
        /// Any of these in the retelling counts for the idea.
        public var keywords: [String]
    }
    public var id: Int
    public var title: String
    public var text: String
    public var units: [Unit]
}

public enum Battery {
    static func story(_ id: Int, _ title: String, _ text: String, _ units: [(String, [String])]) -> Story {
        Story(id: id, title: title, text: text, units: units.map { Story.Unit(idea: $0.0, keywords: $0.1) })
    }

    /// Eight original stories of the same shape: about 75 words, 12 idea units each (names,
    /// numbers, places, events, an outcome), so forms can rotate between sessions.
    public static let stories: [Story] = [
        story(0, "The bakery fire",
              "Early on Thursday morning a small fire started in the oven at Karim's bakery on Mall Road. The night baker, a young woman called Sara, smelled smoke and phoned the fire brigade. Two engines arrived within ten minutes. Nobody was hurt, but four hundred loaves were ruined. Neighbours brought tea for the firefighters, and by noon the bakery was selling bread again from a borrowed van.",
              [("Thursday", ["thursday"]), ("early morning", ["morning", "early"]), ("fire in the oven", ["oven"]),
               ("Karim's bakery", ["karim", "bakery"]), ("Mall Road", ["mall"]), ("night baker Sara", ["sara"]),
               ("smelled smoke", ["smoke", "smelled"]), ("two fire engines", ["two engines", "engines", "fire brigade"]),
               ("within ten minutes", ["ten minutes", "10 minutes"]), ("nobody hurt", ["nobody", "no one", "hurt"]),
               ("four hundred loaves ruined", ["four hundred", "400", "loaves"]), ("selling from a borrowed van by noon", ["van", "noon", "borrowed"])]),
        story(1, "The lost suitcase",
              "Last Monday, Farid flew from Karachi to Istanbul for his sister's wedding. When he landed, his blue suitcase was missing, and inside it was the wedding gift: a silver tea set. The airline found the case two days later in Doha. A courier delivered it to the hotel on Wednesday evening, just one hour before the ceremony began. Farid tipped the driver fifty lira and ran upstairs to change.",
              [("Monday", ["monday"]), ("Farid", ["farid"]), ("Karachi to Istanbul", ["karachi", "istanbul"]),
               ("sister's wedding", ["sister", "wedding"]), ("blue suitcase", ["blue"]), ("suitcase missing", ["missing", "lost"]),
               ("silver tea set", ["silver", "tea set", "tea"]), ("found in Doha", ["doha"]), ("two days later", ["two days", "2 days"]),
               ("courier to the hotel Wednesday evening", ["wednesday", "courier", "hotel"]), ("one hour before the ceremony", ["one hour", "an hour", "1 hour"]),
               ("tipped fifty lira", ["fifty", "50", "lira", "tip"])]),
        story(2, "The school garden",
              "In March, the pupils of Green Hill School planted a vegetable garden behind the library. Their teacher, Mrs Rahman, divided the class of thirty into six teams. Each team grew one crop: tomatoes, spinach, carrots, peas, mint or chillies. In June a storm flattened the peas, but the carrots won first prize at the town fair. The children sold the rest of the harvest and bought a new bench.",
              [("March", ["march"]), ("Green Hill School", ["green hill"]), ("vegetable garden", ["garden", "vegetable"]),
               ("behind the library", ["library"]), ("teacher Mrs Rahman", ["rahman"]), ("class of thirty", ["thirty", "30"]),
               ("six teams", ["six", "6 teams"]), ("each grew one crop", ["tomato", "spinach", "mint", "chilli"]),
               ("storm in June", ["june", "storm"]), ("peas flattened", ["flattened", "peas"]), ("carrots won first prize at the fair", ["prize", "fair", "first"]),
               ("sold the harvest and bought a bench", ["bench", "sold"])]),
        story(3, "The night train",
              "On a cold Friday night, the train from Lahore to Quetta stopped in the desert because a camel was standing on the track. The driver, Mr Baig, blew the horn six times, but the camel would not move. A passenger named Ayesha, who grew up on a farm, walked out with a bag of dates. The camel followed her off the line, and the train arrived in Quetta forty minutes late.",
              [("Friday night", ["friday"]), ("cold", ["cold"]), ("Lahore to Quetta", ["lahore", "quetta"]), ("stopped in the desert", ["desert"]),
               ("camel on the track", ["camel"]), ("driver Mr Baig", ["baig"]), ("horn six times", ["horn", "six times"]),
               ("camel would not move", ["move", "wouldn't", "would not"]), ("passenger Ayesha", ["ayesha"]), ("grew up on a farm", ["farm"]),
               ("bag of dates", ["dates"]), ("forty minutes late", ["forty", "40", "late"])]),
        story(4, "The library cat",
              "For eleven years a grey cat named Pepper lived in the public library in Murree. She slept on the history shelf and greeted every reader at the door. One winter she disappeared for three weeks. The librarian, Mr Dar, put posters in twenty shops. A tourist from Lahore finally found Pepper asleep in a hotel laundry room. The town held a small party, and children still bring her fish on Saturdays.",
              [("eleven years", ["eleven", "11"]), ("grey cat", ["grey", "gray"]), ("named Pepper", ["pepper"]),
               ("library in Murree", ["murree", "library"]), ("slept on the history shelf", ["history", "shelf"]), ("greeted readers at the door", ["door", "greeted"]),
               ("disappeared one winter", ["winter", "disappeared", "missing"]), ("three weeks", ["three weeks", "3 weeks"]),
               ("librarian Mr Dar", ["dar"]), ("posters in twenty shops", ["posters", "twenty", "20"]),
               ("tourist found her in a hotel laundry", ["laundry", "hotel", "tourist"]), ("fish on Saturdays", ["fish", "saturday"])]),
        story(5, "The cricket final",
              "The village cricket final was played on a hot Sunday in August. The Blue Lions needed eight runs from the last over. Their youngest player, fifteen-year-old Hamza, was batting with a borrowed bat. He hit the first ball for four and the fifth ball over the mosque wall for six. The crowd carried him around the ground, and the trophy now stands in his grandmother's shop.",
              [("village final", ["village", "final"]), ("Sunday", ["sunday"]), ("August, hot", ["august", "hot"]),
               ("Blue Lions", ["blue lions", "lions"]), ("eight runs needed", ["eight", "8 runs"]), ("last over", ["last over", "over"]),
               ("Hamza, fifteen", ["hamza", "fifteen", "15"]), ("borrowed bat", ["borrowed", "bat"]), ("first ball for four", ["four", "first ball"]),
               ("six over the mosque wall", ["mosque", "wall", "six"]), ("carried around the ground", ["carried", "crowd"]),
               ("trophy in grandmother's shop", ["grandmother", "trophy", "shop"])]),
        story(6, "The wrong recipe",
              "Nadia wanted to bake a lemon cake for her neighbour's birthday on Tuesday. She copied the recipe from her aunt's old notebook, but misread two spoons of salt as two cups. The cake came out of the oven looking perfect. At the party, the first person to try it was the neighbour's husband, who bravely ate the whole slice. Now Nadia labels every jar, and her aunt has rewritten the notebook.",
              [("Nadia", ["nadia"]), ("lemon cake", ["lemon"]), ("neighbour's birthday", ["neighbour", "neighbor", "birthday"]),
               ("Tuesday", ["tuesday"]), ("aunt's old notebook", ["aunt", "notebook"]), ("two spoons misread", ["spoons", "misread"]),
               ("two cups of salt", ["salt", "cups"]), ("looked perfect", ["perfect"]), ("neighbour's husband tried first", ["husband"]),
               ("ate the whole slice", ["whole slice", "slice", "ate"]), ("labels every jar", ["label", "jar"]), ("aunt rewrote the notebook", ["rewrote", "rewritten"])]),
        story(7, "The mountain rescue",
              "In October, two hikers from Islamabad got lost on a mountain path near Hunza when thick fog came down. One of them, a nurse called Sana, had a whistle on her keychain. She blew it every five minutes. A shepherd named Akbar heard it from across the valley and guided them to his stone hut. They stayed the night, drank apricot tea, and walked down safely the next morning.",
              [("October", ["october"]), ("two hikers", ["two hikers", "hikers"]), ("from Islamabad", ["islamabad"]),
               ("near Hunza", ["hunza"]), ("thick fog", ["fog"]), ("nurse Sana", ["sana", "nurse"]), ("whistle on keychain", ["whistle", "keychain"]),
               ("every five minutes", ["five minutes", "5 minutes"]), ("shepherd Akbar", ["akbar", "shepherd"]),
               ("across the valley", ["valley"]), ("stone hut", ["hut", "stone"]), ("apricot tea", ["apricot"])]),
    ]

    /// Idea units recalled in a free retelling.
    public static func score(_ story: Story, retelling: String) -> Int {
        let text = " " + AnswerMatch.normalize(retelling)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ") + " "
        let words = text.split(separator: " ").map(String.init)
        return story.units.filter { unit in
            unit.keywords.contains { k in
                let key = AnswerMatch.normalize(k)
                if key.contains(" ") { return text.contains(" \(key) ") }
                return words.contains { AnswerMatch.matches($0, key) || ($0.hasPrefix(key) && key.count >= 4) }
            }
        }.count
    }

    /// The story for the n-th measurement session, rotated per person (same scheme as the old
    /// benchmark forms, so everyone sees each story once per eight sessions).
    public static func storyForm(session n: Int, userSeed: String) -> Story {
        var rng = SeededRandom("\(userSeed)#stories")
        let order = Array(0..<stories.count).shuffled(using: &rng)
        return stories[order[((n % stories.count) + stories.count) % stories.count]]
    }

    public static let selfRating = [
        "Forgot the name of someone you had just met",
        "Walked into a room and forgot why",
        "Forgot to do something you meant to (a call, an errand)",
        "Lost track of where you put something",
        "Struggled to recall something you read or watched recently",
        "Forgot a number you needed (a PIN, a phone number)",
    ]
    public static let ratingScale = ["Never", "Rarely", "Sometimes", "Often", "Very often"]

    /// Average of the answers (1 = never … 5 = very often); lower is better.
    public static func selfRatingScore(_ answers: [Int]) -> Double? {
        let valid = answers.filter { (1...5).contains($0) }
        return valid.count == selfRating.count ? Double(valid.reduce(0, +)) / Double(valid.count) : nil
    }

    /// Norms for the reliable-change maths (story units of 12; Lookout in ms).
    public static let storyNorms = Improvement.Norms(sd: 2.0, reliability: 0.75, expectedPracticeGain: 0.5)
    public static let lookoutNorms = Improvement.Norms(sd: 40, reliability: 0.8, expectedPracticeGain: 10)
}
