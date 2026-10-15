# Design & science notes

## Two themes, one codebase
`App/Design/Theme.swift` defines a `Theme` (colours, display font, shape, mascot sprites, copy) that is injected through the SwiftUI environment. The game logic and scoring are shared.

| | Midnight Den (girlfriend) | Gilded Atelier (Mom) |
|---|---|---|
| Mood | Cute-goth pixel night: lilac, ink, bubblegum, moon-cream | Ivory paper, ink-blue text, emerald, brass |
| Mascot | **Mochi**, an original pixel raccoon (eye mask, ear bow, lilac hoodie) | **Professor Raccoon** with gold spectacles, purely ornamental |
| Display font | Pixelify Sans SemiBold (OFL), headings ≥ 24 pt only | Cormorant Garamond SemiBold (OFL) |
| Pacing | Standard, four rating buttons | Gentle: errorless learning, larger targets (60 pt), two rating buttons, slower word pacing, words read aloud |

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

## Science engine (`Packages/MemoryCore`)
| Piece | What | Where |
|---|---|---|
| FSRS-6 | Spaced repetition for personal cards. Matches py-fsrs 6.3.2 exactly (tests). Desired retention: 0.92 Atelier, 0.88 Den. | `FSRS6.swift` |
| Errorless SRT | The answer is shown first, then recalled at 30 s, 1, 2 and 4 min within the session; a miss re-shows the answer. Then the card moves to FSRS. | `Errorless.swift` |
| Bursts | A 7-day baseline, then 7 days every 4 weeks, at fixed difficulty with the **same stimuli all week**. | `BurstPlanner.swift` |
| Learning curve | y = A − (A − y₁)e^(−λ(d−1)), MDLC-style AUC, practice gain = mean(days 5–7) − day 1 | `LearningCurve.swift` |
| Reliable change | Jacobson–Truax, Chelune practice-adjusted (*verify against Chelune 1993*), McSweeny SRB | `ReliableChange.swift` |
| EWMA | λ = 0.2, L = 2.7 over the person-relative daily composite | `EWMA.swift` |
| Doctor card | Requires **all** of: EWMA breach, practice-adjusted change below −1.645 on 2 bursts at least 28 days apart, and no logged poor sleep, illness or low mood that week | `EscalationPolicy.swift` |
| Garden Index | Weighted domain z-scores (0.25 / 0.20 / 0.20 / 0.15 / 0.10 / 0.10), shown only as den growth | `GardenIndex.swift` |
| Adaptive training | Rasch θ by EAP, targeting 75% success (90% in gentle mode). Training days only, so measurement stays constant. | `Rasch.swift` + `GameSupport.swift` |
| Speed module | About 10 sessions in the first 6 weeks, then boosters at 11 and 35 months (ACTIVE) | `BurstPlanner.swift` (`SpeedSchedule`) |
| JITAI bandit | Thompson sampling and a 60/40 micro-randomised prompt (ready, not yet wired into timing) | `Bandit.swift` |

### Tasks
| Domain | Den | Atelier | Notes |
|---|---|---|---|
| Face–name | Night Market Regulars | Salon Portraits | Procedurally generated 12×12 pixel villagers, with no licensing issues |
| Pair learning | Ancient Runes | Old Scripts | Invented symmetric runes (ORCA-LLT-style, no prior knowledge) |
| Item–price | Midnight Snack Prices | Market Ledger | BRANCH-style |
| Word list | Moonlit Shopping List | Letter Recall | 12 words, recognition among 24, **+20 min delayed recall** |
| Object–location | Mochi's Stash | Cabinet of Curiosities | |
| Working memory | Firefly Sequences | Constellations | Adaptive span |
| Speed | Rune Sort | Seal Matching | Digit–symbol-style |
| Prospective | Moon Bell | Brass Bell | Embedded cue during another game |

### Wording guardrail (FDA general-wellness, January 2026 guidance)
Use: "memory training", "brain fitness", "track your practice", "talk to your doctor".
Never use: "detects", "risk score", "MCI", "Alzheimer's", "dementia", "diagnoses".

## Licensing to-dos
- The PRMQ (Edinburgh) and MMQ (Baycrest) are **not** shipped. The app uses original everyday-memory items. Email the authors before swapping them in.
- PHQ-9 and GAD-7 are free to use. A positive PHQ-9 item 9 shows crisis resources immediately (1122 and findahelpline.com).
- The PSQI is not used; the daily check-in replaces it.

## Roadmap (M4)
Bandit-timed reminders, N-of-1 "experiment" cards, HealthKit sleep as a covariate, Urdu localisation (String Catalogs).
