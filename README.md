# Memory Garden 🦝🌙

A native iPhone app (SwiftUI) that **trains memory the way memory champions do**, with a cozy pixel-art companion:

- **Memory Palace course.** Six weeks of the method of loci plus the Major system for numbers. It is modelled on Dresler et al. 2017 (*Neuron*), where 40 days of this training roughly doubled word recall and shifted brain networks toward memory athletes' patterns.
- **Working-memory gym.** Adaptive dual n-back (Jaeggi protocol), operation span and spatial span.
- **Vault.** Learn anything with FSRS-6 spaced repetition and typed active recall: languages, facts, passages. Starter packs include the Major-system pegs 00–99.
- **Honest progress.** Technique-free benchmarks (30-word recall and digit span) on days 0, 14, 28 and 42, then monthly. A "Reliably improved" badge appears only when a gain beats measurement noise and normal practice effects.
- **Two looks.** *Midnight Den* (cute-goth, Mochi the raccoon) and *Gilded Atelier* (ivory and brass).
- **Reminders** you set yourself, which can keep nudging until you tap Done or ring like an alarm on iOS 26. Supporters get "trained today" pings through the free ntfy app.

**Cost: $0, and no Mac is needed.** GitHub builds the app in the cloud, and the phones install it with SideStore from a Windows laptop. → **[docs/INSTALL.md](docs/INSTALL.md)**

<img src="distribution/icon.png" width="96" alt="Mochi app icon">

## What's inside
```
App/                SwiftUI app: Today, Train (course, palaces, gym, arcade), Vault, Progress, Reminders
Widgets/            The single extension: Home/Lock Screen widgets + Live Activity
Shared/             App Group snapshot, Live Activity attributes
Packages/MemoryCore Pure-Swift engine: FSRS-6, course, Major system, n-back, spans, benchmarks… + tests
backend/supabase/   Optional free server: Postgres → ntfy pings ("trained", "not yet", weekly)
distribution/       build-ipa.sh (used by CI), SideStore source template, icon
.github/workflows/  core-tests (Linux) and build-ipa (macOS: compile check + releases)
docs/               INSTALL (Windows-first), PRIVACY, DESIGN
```

## Tests
```bash
swift test --package-path Packages/MemoryCore
```
These check that FSRS-6 matches py-fsrs 6.3.2 value for value, that all 100 Major pegs round-trip, the n-back target and lure counts and staircase, complex-span scoring, the course schedule, and benchmark reliable-change. CI also compiles the iOS app on every push.

Memory Garden trains skills. It is not a medical device and makes no health claims. See [docs/PRIVACY.md](docs/PRIVACY.md).
