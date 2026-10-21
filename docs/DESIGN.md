# Design & science notes

## Two themes, one codebase
`App/Design/Theme.swift` defines a `Theme` (colours, display font, shape, mascot sprites, copy) that is injected through the SwiftUI environment. The game logic and scoring are shared.

| | Midnight Den (girlfriend) | Gilded Atelier (Mom) |
|---|---|---|
| Mood | Cute-goth pixel night: lilac, ink, bubblegum, moon-cream | Ivory paper, ink-blue text, emerald, brass |
| Mascot | **Mochi**, an original pixel raccoon (eye mask, ear bow, lilac hoodie) | **Professor Raccoon** with gold spectacles, purely ornamental |
| Display font | Pixelify Sans SemiBold (OFL), headings ≥ 24 pt only, with a clearer “2” and “5” | Cormorant Garamond SemiBold (OFL) |
| Surfaces | Stepped pixel corners, no outlines, depth from tone | Soft 28 pt corners and a gentle lift, no brass borders |
| Sounds | Square-wave chiptune | Plucked strings and a soft bell |

Mochi is original art. It is inspired only by the cute-goth vibe and has no Sanrio/Kuromi likeness, names or assets. Sprites are text grids in `Packages/MemoryCore/Sources/MemoryCore/Sprites.swift`; edit the rows to redraw them.

### Scene & path (v0.4: less boxy)
- **Room, not cards.** Today and Progress open on an illustrated room (`RoomSceneView`, layout in `MemoryCore/DenGrowth.swift` → `RoomScene`). Props arrive as weekly training days add up (`DenGrowth` stage 0–5): Den — lamp, bookshelf, plant, poster and fairy lights, cushion and candles; Gallery — paintings, palm, easel and chandelier, marble bust. Growth follows consistency, never scores.
- **Steps as a trail.** Today's session is a winding path of stepping stones (diamonds in the Den, medallions in the Atelier); the walked part is solid.
- **Palace maps.** Your palace is drawn as a floor plan whose rooms snake row by row (`MemoryCore/PalaceMap.swift`), so consecutive stops always touch. The mascot walks to the current stop while you place words, recall them and walk the route; the editor previews the route.
- **Surfaces.** `ThemedCard` and the button styles have no outlines: `PixelCornerShape` (two-step corners) in the Den, continuous rounded rectangles in the Atelier. Hairlines separate figures instead of boxes.
- **Digits.** Pixelify Sans draws “2” like “8” and “5” like “S”. The bundled copy has those two glyphs redrawn on its 5×7 grid (`distribution/tools/patch_pixel_digits.py`).
- **Sounds.** `distribution/tools/make_sounds.py` synthesises `<sound>-den.wav` / `<sound>-atelier.wav`; `SFX` picks the current look's voice.

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
- Practice earns *shinies*, and every 5 shinies adds a treasure to the collection; training days furnish the room.
- On missed days the mascot naps, with no sad faces. Goals are weekly (4 days), and missed days never reset anything.
- At most 3 practice prompts a day (quest reminder, evening nudge, delayed recall). Reminders you set yourself are separate.

## Training science (`Packages/MemoryCore`)

| Module | Evidence | How the app does it | Code |
|---|---|---|---|
| **Memory Palace course** | Dresler et al. 2017 (*Neuron*): 40 days × 30 min of method-of-loci training took recall of 72 words from ~26 to ~62. Connectivity shifted toward memory athletes' patterns, and the gain lasted 4 months. Wagner et al. 2021 (*Sci. Adv.*) found more efficient encoding afterwards. | Week 1: imagery and first palace. Week 2: Major system. Weeks 3–6: sprints grow +5 words or +4 digits at ≥ 80% in-place accuracy. The course advances only on days you train. | `Course.swift`, `Loci.swift`, `MajorSystem.swift`, `WordBank.swift` |
| **Consolidation and re-recall** | Retrieval after sleep shows what was consolidated; spaced retrieval practice slows forgetting (the testing and spacing effects). | Each sprint list comes back after 1 day (Dawn Recall) and again at 3, 7 and 21 days, at most one older list a day (the most overdue). Progress plots the personal forgetting curve (“What sticks”). Re-recalls walk the palace the words were placed in. | `ListReview` in `Course.swift`, `Quest.listReviewFor` |
| **Dual n-back** | Jaeggi et al. 2008 protocol. It reliably improves the trained skill; far transfer is debated (Melby-Lervåg & Hulme 2016; Sala & Gobet 2017). | 20 + n trials, 6 targets per modality (2 dual). Level goes up at < 3 errors per modality and down at > 5. | `NBack.swift` |
| **Operation span** | Conway et al. 2005 partial-credit scoring. | Set sizes 3–6, processing must stay ≥ 85% accurate, 6 s limit per equation. | `ComplexSpan.swift` |
| **Vault** | Spacing plus retrieval practice; the generation effect. FSRS-6 matches py-fsrs exactly. | Typed answers, interleaved decks, new cards capped, warm-up time-boxed. | `FSRS6.swift`, `VaultImport.swift` |
| **Benchmarks** | Transfer is the honest test. Reliable change needs a noise estimate; your own is better than a textbook one. | 30-word free recall and forward digit span. Three **baseline** days come first (one a day, before any technique), then days 14/28/42 and monthly. The baseline gives a personal SEM (pooled with the literature SEM, 4 df prior) and practice gain (shrunk toward the literature, never below 0); “Reliably improved” needs the latest score above baseline + gain + 1.645·SEM·√(1 + 1/3). Progress shades that normal range. | `BenchmarkPlanner`, `Improvement.personal` |
| **Champion test** | Dresler et al. 2017 used 72 words, 20 minutes, free recall, and again after 24 hours. Unlike the 30-word test, palace users don't hit the ceiling. | On the first course day (a pre-technique reference), at the end of the course, then monthly. The next day's recall (no re-study) is its own step. | `ChampionTest` |
| **Alternate forms** | Forms must be interchangeable or a “gain” can just be an easier list. | 6 × 30 word-recall forms and 3 × 72 Champion forms, equated on concreteness and SUBTLEX-US Zipf frequency (Brysbaert et al. 2014) and length: every form mean within 0.05 SD of every other (tested). Benchmark words never appear in sprints. Form order is a cyclic Latin square rotated per person. | `WordBank.swift` (generated by `distribution/tools/build_wordbank.py`), `BenchmarkPlanner.form` |
| **Arcade** | Associative binding practice. | Rasch-adaptive difficulty (target 75%). | `Rasch.swift`, `Stimuli.swift` |
| **Personal FSRS** | The FSRS optimizer starts by fitting the initial stabilities (w0–w3) from each card's first long-term review; these vary most between people. | After 50 reviews: maximum likelihood per first rating on the first review a day or more later, with a light log-space pull toward the defaults; monotone across ratings; refitted every 25 reviews. Progress shows true retention vs the forecast, and a suggested target (85–95 %) from a one-year simulation that minimises review effort per unit of knowledge. | `FSRSPersonal.swift`, `VaultGrading.refitIfNeeded` |
| **Metamemory** | Judgments of learning: knowing what you know guides what you restudy, and calibration improves with feedback. | Before sprint, benchmark and Champion recall you guess your score (slider starts at the midpoint, skippable). Progress plots guess vs result and names the bias once there are 3 guesses. | `Calibration.swift`, `PredictionStep` |
| **Encoding speed ladder** | Memory athletes train speed only once accuracy holds. | Per-item study budget: start 6 s/word, 3 s/digit; × 0.9 after a sprint ≥ 90 %, × 1.15 below 60 %; floor 3 s / 1.5 s, ceiling 1.5 × start. Replayed from course sprints, so nothing extra is stored. Actual seconds per item are charted. | `EncodingPace.swift`, `Quest.pace` |

Every benchmark has a **How sure is this?** sheet (sessions, noise, threshold, latest change), and every drill group a **Why this works** sheet with its evidence and limits.

Runes must have at least 10 cells and span at least 4 rows and 4 columns (re-rolled otherwise, with a test).

### Wording
Use "train memory techniques and working memory". Never claim it prevents or treats disease, or "raises IQ". The gym's limits are stated in the app.

## v0.5: scenes, paths and the phone around the app

**Screens.** Every tab is a scene or a path rather than a stack of boxes:
- Today is a trail through the room.
- Train is *the grounds*: a 42-stone course trail with the mascot on today's stone, then drill medallions.
- The Vault is a deck shelf with a fanned "next card" pile.
- Reminders is a day path (today, tomorrow, later).
- Settings uses themed sections (`ThemedSection`).

**Around the app** (all free-account capabilities, in one widget extension):
- Interactive Flashcard, Trail (including StandBy) and Reminders widgets.
- Three Control Center controls.
- A Live Activity whose Dynamic Island shows the next step or a study countdown.
- App Shortcuts.
- A text-input notification for answering cards.
- Spotlight, quick actions and a background day rollover.
- The app reads its own `embedded.mobileprovision` to warn before the 7-day signature runs out.

## v0.6: a living illustrated world

The whole app is one garden, drawn two ways.

- **The Den (MaoMao)** is the garden at night, in pixel art. It uses palette shading and ordered dithering, with no outlines on scenery.
- **The Atelier (Salma)** is the same garden in the morning, in ink and wash, with hatching where the shade falls.

Both are drawn from a single description in `distribution/art/world.js` (see its README). The playable canvas draws the art live, and `build_art.js` renders it into `App/Resources/Assets.xcassets/Art` for the iPhone.

- **Six places, each with its own hue.**

  | Place | Game | Hue |
  | --- | --- | --- |
  | Palace | Journey | rose |
  | Hall | Gathering | amber |
  | Vault | Number Vault | teal |
  | Kitchen | Kitchen | terracotta |
  | Tower | Lookout | indigo |
  | Journal | Day Recall | sage |

  The hue tints that game's stage, badge and stepping stones.
- **Screen anatomy, in every game.**
  1. Header: place badge and count.
  2. Stepping-stone trail.
  3. Stage: the place's illustration, the mascot and a speech bubble.
  4. Prompt card, rising over the stage.
  5. Action dock.
- **Results land on paper.** Each game ends with its own record: a route receipt, a guest book, a vault ledger, order tickets or a journal page. Stamps mark items right, relearned or missed.
- **Mascots react, never scold.** Mochi and the Professor each have seven moods: idle, happy, thinking, cheer, oops, sleep and wave. A mood hops on a right answer, wobbles on a slip and floats at rest. Measurement screens stay calm.
- **Greenhouse.** Progress is shown as plants. A plant grows with practice and blooms only when a change passes the personal reliable-change threshold.
- **Shelf.** Every ledger item is a card you can flip.
- **Reduce Motion** turns every animation into a fade.

## Roadmap
- Walkable rooms decorated per stop (palace maps currently show stop names).
- Card memorisation (PAO system).
- Bandit-timed reminders (`Bandit.swift` is ready).
- Urdu localisation (String Catalogs).
