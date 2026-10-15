# Memory Garden 🦝🌙

A cozy, science-based memory coach for iPhone, built natively in SwiftUI for two people:

- **Midnight Den:** a cute-goth pixel world with **Mochi the raccoon**, for the girlfriend.
- **Gilded Atelier:** calm, elegant and extra legible, for her mom.

Practice takes five minutes a day: short memory games, personal flashcards scheduled with FSRS-6, reminders that keep nudging until you tap Done (or ring like an alarm on iOS 26), and a den that fills with treasures as you practise. Supporters get completion-only alerts through the free ntfy app.

**Cost: $0.** There is no Apple Developer Program, no App Store, no paid push and no WhatsApp Business API. → **[docs/INSTALL.md](docs/INSTALL.md)**

<img src="distribution/icon.png" width="96" alt="Mochi app icon">

## Quick start (Mac)
```bash
brew install xcodegen
xcodegen generate && open MemoryGarden.xcodeproj   # pick your free Personal Team, Run
./distribution/build-ipa.sh                         # IPA for SideStore on other phones
```

## What's inside
```
App/                SwiftUI app: Today, games, Practice deck, Reminders, Den, Circle, Settings
Widgets/            The single extension: Home/Lock Screen widgets + Live Activity
Shared/             App Group snapshot, Live Activity attributes, widget intents
Packages/MemoryCore Pure-Swift science engine (FSRS-6, learning curves, RCI, EWMA, Rasch…) + tests
backend/supabase/   Optional free server: Postgres → ntfy alerts ("done", "not yet", weekly)
distribution/       build-ipa.sh, SideStore source template, icon
docs/               INSTALL, PRIVACY, DESIGN
```

## Tests
```bash
swift test --package-path Packages/MemoryCore   # runs on macOS or Linux (also in CI)
```
FSRS-6 is checked against the reference implementation (py-fsrs 6.3.2) value for value.

## Important
Memory Garden is for memory training and general wellness. It does not diagnose, treat or predict any condition. Everything stays on the phone except "practised today: yes/no" for the people you choose. See [docs/PRIVACY.md](docs/PRIVACY.md).
