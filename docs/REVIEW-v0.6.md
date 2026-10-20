# Memory Garden: honest review and the v0.6 direction

October 2026, written after 0.5.0 shipped. It answers four questions:
1. Why do the games feel gimmicky and repetitive?
2. How does the old science system compare with the new one?
3. Could this make money?
4. What do I need from you?

**Who it's for:** MaoMao and Salma are healthy adults. The goal is **stronger everyday memory** (names, plans, numbers, things you read and hear) and **staying sharp for the long run**. It is not a dementia treatment, and it should never claim to be one.

---

## 1. The games, reviewed

**The short version: you're right.** The engine underneath is careful. Each game, though, is either a lab test with a costume on or a test of something other than what it says. And most days repeat the same screen three times.

### What a normal day actually is
In week 4, a typical day goes:
1. Vault.
2. A 25-word **sprint**: study the words, then type them stop by stop.
3. **Dawn Recall**: the same typing screen, yesterday's words.
4. **Echo Recall**: the same typing screen again, an older list.
5. Every other day, n-back.

That's about **75 words typed on a phone, and you never see which ones you got wrong**. The result screen says "Shiny get!" even at 0 out of 25. From day 16 the drills just cycle (words → numbers → words → faces + words), and no new lessons arrive after day 16.

### Activity by activity

| Activity | What's wrong | Keep? |
|---|---|---|
| **Word Sprint** (palace) | Random nouns with no real-life meaning. The timer can end before you've seen every word, and the unseen ones count as misses. When the list outgrows your palace, the cue becomes "Item 21", which breaks the method. No review of misses. | The palace idea, your own routes, the map, the pace ladder |
| **Dawn / Echo Recall** | The same screen as the sprint. Your palaces are reused within days, so a 7- or 21-day recall mostly measures *overwriting*, not memory. "Each revisit makes the next one easier" isn't true when misses are never shown. | The idea of coming back after days, done properly |
| **Number Sprint** (Major system) | The intro says "place them along a route", but there is no route. The "show peg words" toggle gives away the answer. Pegs are never taught before the first number game. The digits are random, never phone numbers or dates. | The peg list (it's correct) |
| **Route Walk** | You re-order your own stop names, and the last ones fall out by elimination. That's not a mental walk. | The palace builder |
| **Face–Name** | Every face uses the same template: same eyes, same mouth, no eyebrows, no chin. The lesson says "notice the eyebrows" when there are none. You end up remembering background colours. The test shows the exact same picture, so it's picture-matching. Beards land on "Fatima". | The goal (names are the #1 everyday complaint) |
| **Ancient Runes** | Random pixel blobs paired with random words. Nothing to hook an image to, and no later test. | — |
| **Stash** | Objects on a 4×4 grid of identical squares, tested seconds later. That's a lab short-term-memory task, not "where did I leave my keys". | — |
| **Sequences** (Corsi) | A fine measure, but never scheduled and never taught. | — |
| **Dual n-back** | Faithful to the protocol. But there's no feedback per trial, and the score ignores false alarms (pressing both buttons every time scores 100%). It's the only gym item in the daily plan, and it has the weakest real-life evidence. | Optional free play |
| **Operation span** | It never adapts, a hidden maths-accuracy rule halves your score, and it's rarely scheduled. | The partial-credit scoring |
| **Benchmarks** | Labelled "technique-free", yet the instructions say "use any method, palace included". So it measures the trained skill, not everyday memory. The Champion test (35 minutes) lands on day 4, before any lesson. | The personal-baseline maths (genuinely good) |
| **Vault** (flashcards) | Your typed answer is checked but then ignored: you can type the wrong thing and press "Easy". New users have no cards, so it never shows up. | FSRS scheduling, photos, import. The only real-life content in the app. |
| **Lessons** | Text pages with a "try it" that nothing checks. Several promise drills that don't exist (backward walk, a 6-digit sprint, "learn pegs 00–49 first"). | The content, moved into the games |

**Three root causes:**
- one recall screen reused for five different things;
- no item-level feedback;
- generic lab tasks reskinned instead of games built around real memory needs.

---

## 2. Science: old system vs new system

### What the evidence actually supports (for healthy adults)
Sources: research summary, October 2026.

**Strong**
- **Retrieval practice and spacing.** Pulling something out of memory, spread over days, is among the best-replicated effects in psychology. *Successive relearning* means retrieving until correct, then again in later sessions; it is especially effective.
- **Elaborative and imagery encoding.** The memory palace and face–name imagery work well for the material you practise. In Dresler 2017, beginners went from about 26 to about 62 of 72 words after six weeks. Caveat: the participants were young, and independent replications are few.
- **Implementation intentions** ("When X, I will Y"). They help prospective memory (remembering to do things); d ≈ 0.68 in older adults. External reminders help even more.

**Interesting for long-term sharpness**
- **Speed-of-processing training.** In the ACTIVE trial's 20-year follow-up (2026), speed training plus booster sessions was the *only* arm linked to fewer dementia diagnoses: 40% vs 49%. It's an association from one trial, not a promise. Still, it is the strongest long-term signal for any trainable cognitive exercise.

**Weak**
- **Working-memory training (n-back etc.).** You get better at the trained task and close cousins. Transfer to everyday memory or intelligence is about zero in large meta-analyses (Melby-Lervåg 2016, Sala 2019).
- **Calibration training and encoding-speed training.** The evidence is thin. Fine as light extras, not as pillars.

### Old vs new

| | Old (v0.1–0.5) | New (v0.6) |
|---|---|---|
| **Goal** | A palace course plus a "brain gym" | Stronger everyday memory, plus speed and engagement for later life |
| **What gets remembered** | Random noun lists, random digits, pixel faces | Real-life-flavoured content: errands, packing lists, a talk's points, dates, phone numbers, people with a fact about them, your own day |
| **Scheduling** | Two systems: fixed 1/3/7/21-day list checks, plus FSRS for cards | **One memory ledger.** Every item from every game has FSRS state and comes back when it's about to fade |
| **Feedback** | A count ("17 of 25") | **Item by item:** misses are shown and re-tested until correct (successive relearning) |
| **Daily review** | Dawn and Echo Recall (the same typing screen twice) | One 3-minute **mixed warm-up** of due items from all games (interleaved) |
| **Difficulty** | One size ladder per game | A skill ladder per game (load and pace), kept separate from what you remember |
| **Working memory** | n-back daily | The Kitchen (a game form of complex span), as a short game; n-back optional |
| **Speed** | None | **Lookout:** a brief-flash, peripheral-attention game with an adaptive display time, modelled on ACTIVE's speed training |
| **Prospective memory** | Reminders only | Reminders plus **missions** inside sessions ("When you see the red lantern, tap it"), with hit rate tracked |
| **Measuring progress** | One "technique-free" test that invites the technique | Kept apart: **(a) skill** (palace capacity), **(b) everyday transfer** (story recall now and next day, new names next day, mission hit rate), **(c) speed** (Lookout threshold), plus a monthly 6-question self-rating. All judged against your own 3-day baseline with the existing reliable-change maths |
| **Honesty** | "Why this works" sheets | Same, plus wording that never claims prevention or treatment |

**What stays from the old engine:** FSRS-6 (exact match with the reference), personal FSRS fitting, the reliable-change maths, the equated word forms, the palace builder and map, the pace ladder, and answer matching that forgives typos.

---

## 3. The new games (replacing all of the old ones)

The home becomes a **garden map** with five places. A day is 10–15 minutes:
1. The review warm-up.
2. One main game, rotating.
3. One short game.
4. Optionally, a one-minute Day Recall in the evening.

Weekly "chapters" change the story and content, so days don't repeat.

| Place | Game | What you do | Why it helps |
|---|---|---|---|
| Palace | **The Journey** | Mochi or the Professor carries a *delivery* (errands, a packing list, a talk's points, history dates, a recipe) along **your** route. The app suggests a vivid scene per stop that you can change. You walk back to collect, forwards and, from week 2, backwards. | Method of loci on useful material, with retrieval and spacing |
| Hall | **The Gathering** | Meet 4–8 people at an event: a face, a name, one fact. Days later they come back to a different party: "Which one is Omar? What does he do?" Faces vary in shape, brows, nose, eyes, age and hair, and are tested in a new expression. | The #1 everyday complaint (names), trained the way names are actually needed |
| Vault | **Number Vault** | Learn the Major-system pegs 10 at a time. Number games unlock as pegs stick. Then real-looking numbers (phone numbers, dates, PINs, prices) become images on palace stops. | Numbers are hard to remember, and the technique genuinely works |
| Kitchen | **The Kitchen** | Customers give orders while interruptions happen; then serve them in the right order. | Keeping things in mind under distraction (working memory), honestly framed |
| Tower | **Lookout** | A quick flash: what was in the centre, and where did the lantern appear? It gets faster as you improve. | Speed of processing: the one trainable ability with long-term aging evidence |
| Journal | **Day Recall** | In the evening, jot down three things. Later: "What did you do on Tuesday evening?" | Real memory of your own life, retrieved and spaced |

**Retired:** Runes, Stash, Sequences, Number Sprint, Word Sprint, Dawn/Echo Recall, and n-back as a daily item (it stays as free play). Your history is kept.

---

## 4. The design system (summary of the plan)

**Today:**
- 13 colours and nothing else tokenised.
- 38 places branch on "is this the pixel theme?".
- 14 stray hex colours, 11 fixed-size fonts and 105 raw system text styles.
- 3 different trail implementations.
- Widgets copy-paste their own background, room and ring, and the copies have already drifted.
- Only one view scales with text size.

**v0.6 builds "Garden Kit"**, a shared Swift package used by the app *and* the widgets:
- full tokens: colour roles, a type scale that follows Dynamic Type, spacing, radii, elevation, motion with Reduce Motion, and haptics and sounds;
- about 25 components, each carrying its theme's personality internally;
- a gallery screen;
- a contrast test;
- a CI check that rejects hard-coded styling.

On top sits one illustration language for the garden world in both looks, plus an optional dark "Atelier Night".

---

## 5. Could it make money? (analysis only)

### The market
**Competitor pricing (checked October 2026):**

| App | Price |
|---|---|
| Lumosity | ~$60/yr ($12/mo) |
| Elevate | ~$40/yr |
| Peak | ~$35/yr |
| NeuroNation | ~$84/yr |
| CogniFit | $120/yr |
| AnkiMobile | $24.99 one-off |
| Brainscape | $60–96/yr or $200 lifetime |

- **Biggest player:** Impulse is estimated at about $1–3M a month, from paid acquisition at scale.
- **Market size:** "brain training app" reports range from $3B to $16B depending on definition. They aren't reliable; the honest summary is "large, crowded, dominated by a few".
- **The open niche:** memory-palace apps are small indie tools (free to $3, or about $80 lifetime). **None combines a structured palace course + FSRS + honest benchmarks against your own baseline.** That combination is Memory Garden's real differentiator; the "brain games" are not.

### Costs to sell it

**Fixed costs:**
- Apple Developer Program: $99 a year (no waiver for individuals).
- Apple's commission: 15% (under $1M a year).
- Hosting: about $0 (everything is on-device; ntfy and Supabase have free tiers).

**What it would take:**
- StoreKit paywall, onboarding for strangers, a privacy policy and App Store privacy labels.
- Localisation, support email, and a content pipeline.
- About 2–3 months of focused work before launch, then ongoing marketing.

### Three illustrative scenarios
Assumes $34.99 a year or $24.99 one-off, and 3–5% of downloads paying. These are illustrations, not forecasts.

| Scenario | Downloads/yr | Paying | Net revenue/yr (after 15%) |
|---|---|---|---|
| **Quiet listing** (no marketing, App Store search only) | 1–5k | 30–200 | **$600–6,000** |
| **Niche leader** (memory-palace content on YouTube/TikTok, App Store optimisation, a good rating) | 30–60k | 1,000–3,000 | **$30,000–90,000** |
| **Breakout** (Apple feature or paid ads that pay back) | 300k+ | 10,000+ | $300,000+ gross, but paid ads usually eat most of it |

### Risks
- **Claims.** The FTC fined Lumosity in 2016 for unproven "delay decline" claims. Anything like "prevents dementia" or "clinically proven" invites the same; medical claims also make the app a regulated medical device (FDA, EU MDR).
  - Apple reviews health-ish apps strictly and wants citations.
  - Memory Garden's honest framing is already on the right side of this.
- **Retention.** Most brain-training users quit within weeks; subscriptions depend on habit.
- **Crowding.** Large players outspend indies on ads.
- **Support.** Strangers need help, refunds and reviews answered.

### Recommendation
1. **Stay family-only for now.** You lose nothing: it's free for you and private.
2. **Revisit after about 6 weeks of real use with v0.6.** If MaoMao and Salma keep using it unprompted and their scores move, that's the signal.
3. **If you sell it:** position it as **"Learn the memory-palace skill"**, a course plus a smart flashcard ledger for students and active adults.
   - Price it one-off (about $25–30) or about $35 a year, with a generous free first week of the course.
   - Market with honest before/after numbers people measure themselves.
   - Don't enter the "brain games" race.
4. **First step if you decide yes:** buy the $99 account and run a TestFlight beta with 20–50 friends before any launch.

---

## 6. What I need from you (beyond following the install guide)

1. **Once:** in the repo go to Settings → Pages → Deploy from a branch → `gh-pages` / root → Save. That makes the install page live.
2. **Install 0.5.0** on both phones with the guide, and tell me anything that confused you or didn't match the screen.
3. **At the canvas checkpoint,** play the five new games for about 10 minutes and say which feel good, boring or confusing. Your reactions decide the Swift version.
4. **Optional:**
   - May **The Gathering** use real people from your own photos? It's private and on-device, but your call.
   - **What content** would MaoMao and Salma enjoy remembering? For example recipes, Urdu poetry, family birthdays, places they want to travel, history.
