# Design & science notes

## Two themes, one codebase
`App/Design/Theme.swift` defines a `Theme` (colours, display font, shape, mascot sprites, copy) that is injected through the SwiftUI environment. The game logic and scoring are shared.

| | Midnight Den (girlfriend) | Gilded Atelier (Mom) |
|---|---|---|
| Mood | Cute-goth pixel night: lilac, ink, bubblegum, moon-cream | Ivory paper, ink-blue text, emerald, brass |
| Mascot | **Mochi**, an original pixel raccoon (eye mask, ear bow, lilac hoodie) | **Professor Raccoon** with gold spectacles, purely ornamental |
| Display font | Pixelify Sans SemiBold (OFL), headings ≥ 24 pt only | Cormorant Garamond SemiBold (OFL) |
| Layout | Compact pixel cards, chunky borders | Roomier cards and larger targets (60 pt) |

Mochi is original art. It is inspired only by the cute-goth vibe and has no Sanrio/Kuromi likeness, names or assets. Sprites are text grids in `Packages/MemoryCore/Sources/MemoryCore/Sprites.swift`; edit the rows to redraw them.

### Readability rules (both themes)
- Body text uses the system font with Dynamic Type and Bold Text support. Pixel and serif display fonts are used only for headings of 24 pt or more.
- Touch targets are 48 pt minimum, and 60 pt in the Atelier theme.
- Reduce Motion disables the mascot bobbing and word transitions.
- Instructions have a **Read aloud** button. Only the speed game is timed.
- Contrast (WCAG 2.x, computed from the palette):

| Pair | Midnight Den | Gilded Atelier |
|---|---|---|
| text / background | 16.1 | 12.7 |
| text / card | 13.8 | 13.8 |
| secondary text / card | 9.1 | 7.5 |
| button label / button | 9.4 | 7.6 |
| ornament (shinies) / card | 11.8 | 6.0 |

All pairs pass AA at 4.5:1. In the Atelier theme, the light brass `#B08D3C` is used only for borders; ornament text uses `#7A5C17`.

## Cozy, not punishing
- Practice earns *shinies*, and every 5 shinies adds a trinket to the den's shelves.
- On missed days the mascot naps, with no sad faces. Goals are weekly (4 days), and missed days never reset anything.
- At most 3 practice prompts a day (quest reminder, evening nudge, delayed recall). Reminders you set yourself are separate.

## Training science (`Packages/MemoryCore`)

| Module | Evidence | How the app does it | Code |
|---|---|---|---|
| **Memory Palace course** | Dresler et al. 2017 (*Neuron*): 40 days × 30 min of method-of-loci training took recall of 72 words from ~26 to ~62. Connectivity shifted toward memory athletes' patterns, and the gain lasted 4 months. Wagner et al. 2021 (*Sci. Adv.*) found more efficient encoding afterwards. | Week 1: imagery and first palace. Week 2: Major system. Weeks 3–6: sprints grow +5 words or +4 digits at ≥ 80% in-place accuracy. The course advances only on days you train. | `Course.swift`, `Loci.swift`, `MajorSystem.swift`, `WordBank.swift` |
| **Consolidation check** | Retrieval after sleep shows what was consolidated; retrieval practice strengthens memory (the testing effect). | The next day, the same sprint is recalled again. | `Quest.yesterdaysSprint` |
| **Dual n-back** | Jaeggi et al. 2008 protocol. It reliably improves the trained skill; far transfer is debated (Melby-Lervåg & Hulme 2016; Sala & Gobet 2017). | 20 + n trials, 6 targets per modality (2 dual). Level goes up at < 3 errors per modality and down at > 5. | `NBack.swift` |
| **Operation span** | Conway et al. 2005 partial-credit scoring. | Set sizes 3–6, processing must stay ≥ 85% accurate, 6 s limit per equation. | `ComplexSpan.swift` |
| **Vault** | Spacing plus retrieval practice; the generation effect. FSRS-6 matches py-fsrs exactly. | Typed answers, interleaved decks, new cards capped, warm-up time-boxed. | `FSRS6.swift`, `VaultImport.swift` |
| **Benchmarks** | Transfer is the honest test. | 30-word free recall (6 alternate forms, never practised) and forward digit span, on days 0/14/28/42, then monthly. "Reliably improved" requires a practice-adjusted RCI > 1.645. | `Course.swift` (`BenchmarkPlanner`, `Improvement`) |
| **Arcade** | Associative binding practice. | Rasch-adaptive difficulty (target 75%). | `Rasch.swift`, `Stimuli.swift` |

Runes must have at least 10 cells and span at least 4 rows and 4 columns (re-rolled otherwise, with a test).

### Wording
Use "train memory techniques and working memory". Never claim it prevents or treats disease, or "raises IQ". The gym's limits are stated in the app.

## Roadmap
- Card memorisation (PAO system).
- Bandit-timed reminders (`Bandit.swift` is ready).
- Urdu localisation (String Catalogs).
