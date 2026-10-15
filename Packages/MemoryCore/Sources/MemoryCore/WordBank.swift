import Foundation

/// Concrete, highly imageable nouns (easy to picture = good palace material).
/// The first 180 are reserved for the technique-free benchmark (6 alternate forms of 30);
/// sprints draw from the rest, so benchmark words are never practised.
public enum WordBank {
    public static let all: [String] = [
        "apple", "anchor", "ankle", "ant", "apron", "arrow", "attic", "avocado", "axe", "baby", "badge",
        "bagel", "balloon", "banana", "bandage", "banjo", "barn", "barrel", "basket", "bathtub", "battery",
        "beard", "bed", "bee", "beetle", "bench", "bicycle", "bird", "blanket", "blender", "boat", "bottle",
        "bowl", "box", "bracelet", "brain", "bread", "brick", "bridge", "broom", "brush", "bubble", "bucket",
        "buffalo", "bull", "butter", "butterfly", "button", "cabbage", "cactus", "camel", "camera", "candle",
        "cannon", "canoe", "carpet", "carrot", "castle", "caterpillar", "ceiling", "cello", "chimney",
        "chocolate", "cigar", "clock", "cloud", "clown", "coconut", "coffee", "compass", "cookie", "corn",
        "cow", "crab", "crane", "crayon", "crocodile", "crown", "cucumber", "cup", "curtain", "cushion",
        "dagger", "daisy", "desk", "diamond", "dinosaur", "doll", "dolphin", "donkey", "door", "dragon",
        "drum", "eagle", "earring", "egg", "elephant", "elevator", "envelope", "eraser", "eyebrow", "fan",
        "feather", "fence", "fern", "ferry", "flag", "flame", "flamingo", "flashlight", "flower", "flute",
        "fork", "fountain", "fox", "frog", "garlic", "gate", "ghost", "giraffe", "glacier", "glass", "glove",
        "goat", "gorilla", "grape", "grasshopper", "guitar", "hammer", "hammock", "hamster", "hanger",
        "harp", "hat", "hedgehog", "helicopter", "helmet", "hippo", "honey", "horn", "horse", "hospital",
        "hourglass", "igloo", "iron", "island", "ivy", "jacket", "jaguar", "jar", "jeep", "jelly",
        "jellyfish", "jewel", "kangaroo", "kettle", "key", "kite", "kitten", "koala", "ladder", "ladle",
        "lamp", "lantern", "laptop", "leaf", "lemon", "letter", "lettuce", "lighthouse", "lizard", "llama",
        "lobster", "magnet", "mango", "marble", "mask", "medal", "melon", "mermaid", "microphone", "mirror",
        "mitten", "monkey", "mop", "mosquito", "motorbike", "mountain", "muffin", "mushroom", "necklace",
        "needle", "nest", "noodle", "notebook", "nut", "oar", "octopus", "onion", "orange", "ostrich",
        "otter", "owl", "oyster", "paintbrush", "palace", "pancake", "panda", "parachute", "parrot", "peach",
        "peacock", "peanut", "pear", "pearl", "pebble", "pelican", "pen", "pencil", "penguin", "pepper",
        "piano", "pickle", "pie", "pig", "pigeon", "pillow", "pineapple", "pirate", "pizza", "planet",
        "plate", "plum", "pocket", "popcorn", "potato", "pumpkin", "puppet", "puzzle", "pyramid", "quilt",
        "rabbit", "raccoon", "radio", "rainbow", "raspberry", "razor", "robot", "rocket", "ruler", "saddle",
        "salad", "sandal", "sandwich", "saxophone", "scarf", "scissors", "scorpion", "screw", "seahorse",
        "seal", "shark", "shell", "shield", "shoe", "shovel", "skateboard", "skeleton", "skull", "sled",
        "slipper", "snail", "snake", "snowman", "spider", "spinach", "sponge", "spoon", "squid", "squirrel",
        "stairs", "stamp", "starfish", "statue", "stool", "strawberry", "submarine", "suitcase", "swan",
        "sword", "syringe", "table", "taco", "tank", "teapot", "telescope", "tent", "tiger", "toaster",
        "tomato", "toothbrush", "torch", "tractor", "train", "trampoline", "tree", "trophy", "trumpet",
        "tulip", "turkey", "turtle", "umbrella", "unicorn", "vase", "violin", "volcano", "waffle", "wagon",
        "wallet", "walrus", "wand", "watermelon", "whale", "wheel", "whistle", "wig", "windmill", "window",
        "wolf", "worm", "yacht", "yoyo", "zebra", "zipper", "accordion", "acorn", "alligator", "antler",
        "apricot", "aquarium", "armchair", "asteroid", "backpack", "badger", "bagpipe", "bamboo", "bandana",
        "barbell", "beehive", "birdcage", "blimp", "bookshelf", "boomerang", "bouquet", "bowtie", "broccoli",
        "bulldozer", "cabin", "cake", "canary", "candy", "cauldron", "chandelier", "cherry", "chess",
        "chopsticks", "cobweb", "comet", "cookie jar", "coral", "cowboy", "cupcake", "dartboard", "deer",
        "doughnut", "dragonfly", "dumbbell", "easel", "eel", "fireplace", "firework", "fishbowl",
        "footprint", "forklift", "gargoyle", "genie", "gingerbread", "globe", "goblet", "gondola", "goose",
        "gumball", "harmonica", "hay", "hive", "hotdog", "hummingbird", "iceberg", "icicle", "jukebox",
        "kayak", "kiwi", "lasso", "lemonade", "lollipop", "mailbox", "mammoth", "meteor", "mixer", "moose",
        "narwhal", "nutcracker", "origami", "pajamas", "parrotfish", "peppermint", "pinecone", "pinwheel",
        "popsicle", "porcupine", "pretzel", "quill", "raft", "reindeer", "rhino", "ribbon", "rooster",
        "sailboat", "sardine", "scarecrow", "seesaw", "sheriff", "skunk", "snorkel", "snowflake", "sombrero",
        "spaceship", "sprinkler", "stethoscope", "sunflower", "surfboard", "swing", "tambourine", "tiara",
        "toucan", "tuba", "tortoise", "treasure", "tricycle", "trolley", "tuxedo", "typewriter", "vampire",
        "vulture", "walnut", "wardrobe", "wasp", "weasel", "wizard", "yak", "yeti",
    ]

    public static let benchmarkFormSize = 30
    public static let benchmarkForms = 6

    public static func benchmarkForm(_ index: Int, seed: String = "benchmark") -> [String] {
        var rng = SeededRandom(seed)
        let reserved = Array(all.prefix(benchmarkFormSize * benchmarkForms)).shuffled(using: &rng)
        let i = ((index % benchmarkForms) + benchmarkForms) % benchmarkForms
        return Array(reserved[(i * benchmarkFormSize)..<((i + 1) * benchmarkFormSize)])
    }

    public static var sprintPool: [String] { Array(all.dropFirst(benchmarkFormSize * benchmarkForms)) }

    public static func sprint(count: Int, seed: String) -> [String] {
        var rng = SeededRandom(seed)
        return Array(sprintPool.shuffled(using: &rng).prefix(count))
    }
}
