#!/usr/bin/env python3
"""Rebuild MemoryCore/WordBank.swift: equated benchmark forms + a large sprint pool.

    python3 distribution/tools/build_wordbank.py path/to/Concreteness_ratings_Brysbaert_et_al_BRM.txt

Norms: Brysbaert, Warriner & Kuperman (2014) concreteness ratings, which also carry the SUBTLEX-US
word count used here for frequency (Zipf scale; van Heuven et al., 2014).
Get the file from https://github.com/ArtsEngine/concreteness (or the paper's supplement).

Forms are equated on concreteness, Zipf frequency and length: words are dealt to forms in a
serpentine order of a composite score, then pairs are swapped between forms until every form
mean sits within 0.05 SD of every other on each norm.
"""
import csv, math, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SWIFT = os.path.join(HERE, '..', '..', 'Packages', 'MemoryCore', 'Sources', 'MemoryCore', 'WordBank.swift')

WORD_FORMS, WORD_FORM_SIZE = 6, 30          # technique-free 30-word benchmark
CHAMPION_FORMS, CHAMPION_SIZE = 3, 72       # Dresler et al. (2017) 72-word test, technique allowed
TOLERANCE = 0.05                             # max difference between form means, in SDs of the norm

# The original bank (v0.1–0.3), kept so earlier sprint words stay in the pool.
ORIGINAL = [w.replace("_", " ") for w in """
apple anchor ankle ant apron arrow attic avocado axe baby badge bagel balloon banana bandage banjo barn barrel
basket bathtub battery beard bed bee beetle bench bicycle bird blanket blender boat bottle bowl box bracelet
brain bread brick bridge broom brush bubble bucket buffalo bull butter butterfly button cabbage cactus camel
camera candle cannon canoe carpet carrot castle caterpillar ceiling cello chimney chocolate cigar clock cloud
clown coconut coffee compass cookie corn cow crab crane crayon crocodile crown cucumber cup curtain cushion
dagger daisy desk diamond dinosaur doll dolphin donkey door dragon drum eagle earring egg elephant elevator
envelope eraser eyebrow fan feather fence fern ferry flag flame flamingo flashlight flower flute fork fountain
fox frog garlic gate ghost giraffe glacier glass glove goat gorilla grape grasshopper guitar hammer hammock
hamster hanger harp hat hedgehog helicopter helmet hippo honey horn horse hospital hourglass igloo iron island
ivy jacket jaguar jar jeep jelly jellyfish jewel kangaroo kettle key kite kitten koala ladder ladle lamp
lantern laptop leaf lemon letter lettuce lighthouse lizard llama lobster magnet mango marble mask medal melon
mermaid microphone mirror mitten monkey mop mosquito motorbike mountain muffin mushroom necklace needle nest
noodle notebook nut oar octopus onion orange ostrich otter owl oyster paintbrush palace pancake panda
parachute parrot peach peacock peanut pear pearl pebble pelican pen pencil penguin pepper piano pickle pie pig
pigeon pillow pineapple pirate pizza planet plate plum pocket popcorn potato pumpkin puppet puzzle pyramid
quilt rabbit raccoon radio rainbow raspberry razor robot rocket ruler saddle salad sandal sandwich saxophone
scarf scissors scorpion screw seahorse seal shark shell shield shoe shovel skateboard skeleton skull sled
slipper snail snake snowman spider spinach sponge spoon squid squirrel stairs stamp starfish statue stool
strawberry submarine suitcase swan sword syringe table taco tank teapot telescope tent tiger toaster tomato
toothbrush torch tractor train trampoline tree trophy trumpet tulip turkey turtle umbrella unicorn vase violin
volcano waffle wagon wallet walrus wand watermelon whale wheel whistle wig windmill window wolf worm yacht
yoyo zebra zipper accordion acorn alligator antler apricot aquarium armchair asteroid backpack badger bagpipe
bamboo bandana barbell beehive birdcage blimp bookshelf boomerang bouquet bowtie broccoli bulldozer cabin cake
canary candy cauldron chandelier cherry chess chopsticks cobweb comet cookie_jar coral cowboy cupcake
dartboard deer doughnut dragonfly dumbbell easel eel fireplace firework fishbowl footprint forklift gargoyle
genie gingerbread globe goblet gondola goose gumball harmonica hay hive hotdog hummingbird iceberg icicle
jukebox kayak kiwi lasso lemonade lollipop mailbox mammoth meteor mixer moose narwhal nutcracker origami
pajamas parrotfish peppermint pinecone pinwheel popsicle porcupine pretzel quill raft reindeer rhino ribbon
rooster sailboat sardine scarecrow seesaw sheriff skunk snorkel snowflake sombrero spaceship sprinkler
stethoscope sunflower surfboard swing tambourine tiara toucan tuba tortoise treasure tricycle trolley tuxedo
typewriter vampire vulture walnut wardrobe wasp weasel wizard yak yeti
""".split()]

# Hand-curated additions: concrete, picturable, family-friendly single nouns (conc >= 4.6, known by >= 97%).
NEW = """
house car phone doctor book hair ball paper hotel ship plane bag ring dress rock card fish star bus truck wall
church sun tape suit cat arm chicken sea neck computer tea kitchen bear beach lock leg river rose van moon rain
cream milk coat shower oil chest stone princess bell cheese hook sugar hill football market lake cab roof
medicine television ear engine map snow ocean desert garage closet juice lily knight garden bone bike taxi
baseball soup yard valley robin duck belt penny bride sofa tower rope jungle pot ambulance fruit cable cliff
basketball basement bug bat cage wing purse salt pipe mouse nail museum tunnel ranch sink toy factory grass
tube pin satellite lion soap rice towel jet bush dessert cave sweater zoo tooth sheep palm hut cattle hawk tub
string pole soccer sailor tire lawn pan vault clay log tattoo ruby bacon thumb picnic sheet dish puppy perfume
trailer dentist boot luggage airplane lip tool passport dice rug plug wrist burger branch skirt menu butler
coin dock porch hallway mill fog cellar telegram wax cart cargo swamp sock oven lipstick shrimp tin throne
briefcase robe nickel cabinet doorbell fur cape canyon pony ski hose tray tuna chapel forehead hamburger
sausage stove seed carriage receipt shepherd heel olive balcony armor cheek jaw carnival calendar mule cord
shelf nun bolt bean mug driveway mattress coal salmon pier gown mustard mansion ginger canal cereal pond timer
straw wheelchair pudding elbow stadium comb elk poster stereo spaghetti banner glue cracker wheat vegetable
cottage toad shack sleeve oak dove corridor rodeo shuttle orchestra sidewalk runway portrait leopard blouse
gravy thread strap saloon hog thorn playground syrup altar cafe buckle cocoa lid beaver fabric lens grill
classroom villa claw squash sushi doe fisherman ballroom leash pasta canvas shampoo tailor postcard crate wrench
astronaut sunglasses buzzer bookstore clam pea rudder barge biscuit paddle cathedral dictionary lace monastery
knot coyote fudge arena fiddle napkin chute chalk lasagna dresser bumper brownie bakery ledge berry mat lava
mustang pharmacy fin manor terrace fortress wallpaper cobra oatmeal falcon lime cashier windshield sleigh
macaroni pitcher doorway hen lever stallion flour insect wool toothpaste raven sculpture tavern goldfish
armadillo cloak cinnamon rake scanner cone fireman linen spotlight bun ramp cork moss cradle poodle baton
cricket limousine prairie vineyard sticker saucer scooter heater cardboard furnace hoop jug handbag patio
meatball crater blueberry emerald panther microscope diploma screwdriver postman cupboard grapefruit gem knob
curry diver antenna omelet buttercup sweatshirt cheesecake ballerina cheetah jester yogurt meadow moth softball
thermometer textbook greenhouse boar orchid piglet tile beak vine printer plank chariot dishwasher cougar
blizzard puddle urn pastry dart mistletoe orchard cider bonnet waterfall celery jigsaw boardwalk pottery
keyboard crumb charcoal bonfire pantry staircase hoof seaweed turnip baboon canteen locket doorknob vinegar
bathrobe casserole raincoat bungalow stork ferret raisin folder yarn rooftop pillar clarinet fossil propeller
pasture firewood pistachio groundhog tablet mower railing satchel sloth gravel carousel camper frosting gopher
snowball slingshot parcel ivory haystack periscope mitt billboard twig sauna hornet medallion farmhouse clover
escalator calculator turban trombone podium chestnut toolbox kelp catfish caramel seagull fig chimpanzee
blazer skillet gazelle firehouse projector necktie sapphire scrapbook blackboard pliers wristwatch racehorse
volleyball thermostat bead corkscrew cocoon doghouse flask eggplant papaya almond parakeet keyhole horseshoe
toothpick swordfish sphinx hydrant mural ponytail incubator antelope asparagus woodpecker dashboard zucchini
plunger bobsled bookcase pail pecan tablecloth beret milkman loudspeaker tarantula gazebo pendant tripod
croissant stroller dumpling chisel eyelash poncho stapler blowtorch driftwood nightstand broomstick skylight
parsley blackbird chipmunk milkshake treadmill porridge locomotive pheasant meteorite snowboard iguana
gladiator skyscraper houseboat lilac bluebird duckling carp tangerine shoelace blackberry clipboard gerbil
termite headlight stopwatch cookbook flagpole hairbrush smoothie dalmatian jumpsuit magnolia nutmeg barracuda
pitchfork mallet padlock ravioli sneaker tutu bumblebee pillowcase teacup knapsack mongoose boxcar windowsill
jackrabbit chalice wolverine wastebasket scoreboard radish wheelbarrow kilt tadpole gymnast sidecar mane
orangutan ukulele cauliflower firefly mozzarella sickle lamppost artichoke drawbridge speedboat chinchilla
quartz sheepdog beanbag bullfrog steamboat candlestick welder horseradish wishbone lawnmower anaconda tinsel
mandolin teaspoon awning jellybean sundial centipede arrowhead headband bookmark clothesline paperweight
aardvark ladybug lunchbox honeycomb pacifier washcloth matchbox gecko drumstick stepladder bison chessboard
warthog seashell ottoman tortilla stingray dandelion snowmobile megaphone joystick thimble shamrock lampshade
flowerpot beet baguette dustpan birdhouse stirrup raindrop unicycle anteater geyser birdbath daffodil honeybee
eclair manatee thumbtack xylophone pincushion beekeeper scallop hazelnut pickaxe salamander saucepan anchovy
earthworm puma hubcap teakettle spiderweb angelfish
""".split()


def load_norms(path):
    norms = {}
    for r in csv.DictReader(open(path, encoding='utf-8'), delimiter='\t'):
        count = float(r['SUBTLEX'] or 0)
        zipf = math.log10((count + 1) / 51.0) + 3        # SUBTLEX-US: 51 million tokens
        norms[r['Word']] = (float(r['Conc.M']), round(zipf, 3))
    return norms


def features(words, norms):
    return [(norms[w][0], norms[w][1], len(w)) for w in words]


def spread(forms, norms, sds):
    """Largest gap between form means, in SDs, over the three norms."""
    worst = 0.0
    for k in range(3):
        means = [sum(features([w], norms)[0][k] for w in f) / len(f) for f in forms]
        worst = max(worst, (max(means) - min(means)) / sds[k])
    return worst


def equate(words, n_forms, size, norms, seed):
    rnd = random.Random(seed)
    feats = features(words, norms)
    sds = []
    for k in range(3):
        xs = [f[k] for f in feats]; m = sum(xs) / len(xs)
        sds.append(math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1)))
    order = sorted(words, key=lambda w: sum(v / s for v, s in zip(features([w], norms)[0], sds)))
    forms = [[] for _ in range(n_forms)]
    for i, w in enumerate(order):
        r, c = divmod(i, n_forms)
        forms[c if r % 2 == 0 else n_forms - 1 - c].append(w)
    best = spread(forms, norms, sds)
    for _ in range(200000):
        if best < TOLERANCE / 2: break
        a, b = rnd.sample(range(n_forms), 2); i, j = rnd.randrange(size), rnd.randrange(size)
        forms[a][i], forms[b][j] = forms[b][j], forms[a][i]
        s = spread(forms, norms, sds)
        if s <= best: best = s
        else: forms[a][i], forms[b][j] = forms[b][j], forms[a][i]
    assert best < TOLERANCE, best
    for f in forms: rnd.shuffle(f)                 # presentation order within a form
    return forms, best


def swift_list(words, indent=8, width=112):
    lines, line = [], ' ' * indent
    for w in words:
        piece = f'"{w}", '
        if len(line) + len(piece) > width: lines.append(line.rstrip()); line = ' ' * indent
        line += piece
    lines.append(line.rstrip())
    return '\n'.join(lines)


def main():
    norms = load_norms(sys.argv[1])
    old = ORIGINAL
    seen, bank = set(), []
    for w in old + NEW:
        if w not in seen: seen.add(w); bank.append(w)
    missing = [w for w in bank if w not in norms]          # kept for sprints, never benchmarks
    # Benchmark words: the central band of the bank (typical concreteness and frequency), so forms are
    # neither unusually easy nor hard; everything else trains in sprints.
    normed_bank = [w for w in bank if w in norms]
    conc = sorted(norms[w][0] for w in normed_bank); zipf = sorted(norms[w][1] for w in normed_bank)
    med_c, med_z = conc[len(conc) // 2], zipf[len(zipf) // 2]
    sd_c = math.sqrt(sum((x - med_c) ** 2 for x in conc) / len(conc)); sd_z = math.sqrt(sum((x - med_z) ** 2 for x in zipf) / len(zipf))
    need = WORD_FORMS * WORD_FORM_SIZE + CHAMPION_FORMS * CHAMPION_SIZE
    central = sorted(normed_bank, key=lambda w: ((norms[w][0] - med_c) / sd_c) ** 2 + ((norms[w][1] - med_z) / sd_z) ** 2 + (w.count(' ') * 9))
    chosen = central[:need]
    rnd = random.Random('memory-garden-forms'); rnd.shuffle(chosen)
    champ_words, word_words = chosen[:CHAMPION_FORMS * CHAMPION_SIZE], chosen[CHAMPION_FORMS * CHAMPION_SIZE:]
    word_forms, s1 = equate(sorted(word_words), WORD_FORMS, WORD_FORM_SIZE, norms, 'word-forms')
    champ_forms, s2 = equate(sorted(champ_words), CHAMPION_FORMS, CHAMPION_SIZE, norms, 'champion-forms')
    used = set(chosen)
    pool = [w for w in bank if w not in used]
    normed = sorted(used)
    out = f'''import Foundation

// Generated by distribution/tools/build_wordbank.py — edit the curated list there, not here.

/// Concrete, highly imageable nouns (easy to picture = good palace material).
/// Benchmark words live in fixed, equated alternate forms and never appear in sprints,
/// so a benchmark measures plain remembering rather than practice with the same words.
public enum WordBank {{
    /// Technique-free 30-word free-recall benchmark: {WORD_FORMS} forms equated on concreteness,
    /// SUBTLEX-US Zipf frequency and length (form means within {TOLERANCE} SD; largest gap {s1:.3f}).
    public static let benchmarkForms: [[String]] = [
{chr(10).join('        [' + chr(10) + swift_list(f, 12) + chr(10) + '        ],' for f in word_forms)}
    ]

    /// 72-word list for the Champion test (Dresler et al., 2017): {CHAMPION_FORMS} equated forms
    /// (largest gap {s2:.3f} SD). Technique allowed; recalled again the next day without re-study.
    public static let championForms: [[String]] = [
{chr(10).join('        [' + chr(10) + swift_list(f, 12) + chr(10) + '        ],' for f in champ_forms)}
    ]

    /// Everything else: practice material for sprints ({len(pool)} words).
    public static let sprintPool: [String] = [
{swift_list(pool)}
    ]

    /// (concreteness 1–5, Zipf frequency) for every benchmark word, from Brysbaert et al. (2014).
    public static let norms: [String: (concreteness: Double, zipf: Double)] = [
{chr(10).join(f'        "{w}": ({norms[w][0]}, {norms[w][1]}),' for w in normed)}
    ]

    public static var all: [String] {{ benchmarkForms.flatMap {{ $0 }} + championForms.flatMap {{ $0 }} + sprintPool }}

    public static let benchmarkFormSize = {WORD_FORM_SIZE}
    public static var formCount: Int {{ benchmarkForms.count }}

    public static func benchmarkForm(_ index: Int) -> [String] {{
        benchmarkForms[((index % formCount) + formCount) % formCount]
    }}

    public static func championForm(_ index: Int) -> [String] {{
        championForms[((index % championForms.count) + championForms.count) % championForms.count]
    }}

    public static func sprint(count: Int, seed: String) -> [String] {{
        var rng = SeededRandom(seed)
        return Array(sprintPool.shuffled(using: &rng).prefix(count))
    }}
}}
'''
    open(SWIFT, 'w', encoding='utf-8').write(out)
    print(f'bank {len(bank)} (+{len(bank) - len(old)} new), benchmark {len(word_words)}, champion {len(champ_words)}, '
          f'sprint pool {len(pool)}; gaps {s1:.3f} / {s2:.3f} SD; sprint-only (no norms): {missing}')


if __name__ == '__main__':
    main()
