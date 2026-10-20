import XCTest
@testable import MemoryCore

final class EngineV2Tests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Ledger

    func testLedgerSchedulesMissesSoonerThanRecalls() {
        let s = Ledger.scheduler(fuzz: false)
        var hit = MemoryItem(id: "a", kind: .delivery, cue: "stop 1", answer: "stamps", source: "j", createdAt: t0)
        var miss = MemoryItem(id: "b", kind: .delivery, cue: "stop 2", answer: "milk", source: "j", createdAt: t0)
        Ledger.record(&hit, .recalled, at: t0, scheduler: s)
        Ledger.record(&miss, .missed, at: t0, scheduler: s)
        XCTAssertEqual(hit.fsrs.state, .review, "no minute-scale steps: in-session relearning handles those")
        XCTAssertGreaterThan(hit.fsrs.due, miss.fsrs.due)
        XCTAssertGreaterThanOrEqual(miss.fsrs.due.timeIntervalSince(t0), 86_400, "a miss still waits for another day")
        XCTAssertEqual(miss.lapses, 1)
        XCTAssertTrue(hit.accepts("Stamps "))
    }

    func testDueIsWeakestFirstAndInterleaved() {
        let s = Ledger.scheduler(fuzz: false)
        var items: [MemoryItem] = []
        for (i, kind) in [ItemKind.delivery, .delivery, .delivery, .personName, .personName, .peg].enumerated() {
            var it = MemoryItem(id: "i\(i)", kind: kind, cue: "c", answer: "a", source: "s", createdAt: t0)
            Ledger.record(&it, i % 2 == 0 ? .missed : .recalled, at: t0, scheduler: s)
            items.append(it)
        }
        items.append(MemoryItem(id: "new", kind: .card, cue: "c", answer: "a", source: "s", createdAt: t0))
        let due = Ledger.due(items, at: t0.addingTimeInterval(30 * 86_400), limit: 10, scheduler: s)
        XCTAssertEqual(due.count, 6, "never-seen items aren't 'due'")
        XCTAssertNotEqual(due[0].kind, due[1].kind, "kinds are mixed")
        let limited = Ledger.due(items, at: t0.addingTimeInterval(30 * 86_400), limit: 2, scheduler: s)
        XCTAssertEqual(limited.count, 2)
    }

    func testRelearningRepeatsMissesUntilRightOrThreeTries() {
        var q = RelearningQueue(["a", "b", "c", "d"])
        q.answer(.missed)                 // a missed → comes back after two others
        XCTAssertEqual(q.upcoming, ["b", "c", "a", "d"])
        q.answer(.recalled)               // b
        q.answer(.recalled)               // c
        XCTAssertTrue(q.isRetry)
        q.answer(.recalled)               // a, relearned
        q.answer(.missed)                 // d
        q.answer(.missed)                 // d again
        q.answer(.missed)                 // d a third time → gives up
        XCTAssertTrue(q.isFinished)
        XCTAssertEqual(q.missedFirstTime, ["a", "d"])
        XCTAssertEqual(q.relearned, ["a"])
        XCTAssertEqual(q.unresolved, ["d"])
        XCTAssertEqual(q.firstTryCorrect, 2)
        XCTAssertEqual(q.firstAttempt["a"], .missed, "the first attempt is what gets scheduled")
    }

    // MARK: Staircases

    /// A simulated player whose chance of getting a Lookout trial right rises with display time.
    private func observer(threshold: Double, ms: Double, rng: inout SeededRandom) -> Bool {
        let guess = 1.0 / 16
        let p = guess + (1 - guess) / (1 + exp(-(ms - threshold) / (threshold * 0.15)))
        return rng.unit() < p
    }

    func testLookoutStaircaseFindsTheThreshold() throws {
        for truth in [80.0, 150.0, 250.0] {
            var s = Lookout.staircase()
            var rng = SeededRandom("observer\(truth)")
            for _ in 0..<160 { s.record(correct: observer(threshold: truth, ms: s.value, rng: &rng)) }
            let est = try XCTUnwrap(s.threshold)
            XCTAssertEqual(est, truth, accuracy: truth * 0.35, "2-down/1-up lands near the 71 % point")
        }
    }

    func testKitchenStaircaseClimbsForAStrongPlayerAndStaysInBounds() {
        var s = Kitchen.staircase()
        for _ in 0..<40 { s.record(correct: true) }
        XCTAssertEqual(s.value, Kitchen.maxOrders)
        for _ in 0..<40 { s.record(correct: false) }
        XCTAssertEqual(s.value, Kitchen.minOrders)
    }

    // MARK: Games

    func testLookoutTrials() {
        let t1 = Lookout.trial(seed: "s", index: 3, stage: 1)
        XCTAssertTrue((1...2).contains(t1.ring))
        XCTAssertTrue(t1.distractors.isEmpty)
        let t3 = Lookout.trial(seed: "s", index: 3, stage: 3)
        XCTAssertFalse(t3.distractors.contains(t3.ring * Lookout.directions + t3.direction))
        XCTAssertEqual(t3.distractors.count, 15)
        XCTAssertTrue(Lookout.isCorrect(t3, center: t3.center, direction: t3.direction))
        XCTAssertFalse(Lookout.isCorrect(t3, center: 1 - t3.center, direction: t3.direction))
        XCTAssertEqual(Lookout.nextStage(current: 1, threshold: 100), 2)
        XCTAssertEqual(Lookout.nextStage(current: 1, threshold: 200), 1)
        XCTAssertEqual(Lookout.trial(seed: "s", index: 3, stage: 2), Lookout.trial(seed: "s", index: 3, stage: 2))
    }

    func testKitchenRoundAndScore() {
        let r = Kitchen.round(size: 5, seed: "k")
        XCTAssertEqual(r.orders.count, 5)
        XCTAssertEqual(Set(r.orders).count, 5)
        XCTAssertEqual(r.interruptions.count, 5)
        XCTAssertTrue(Set(r.orders).isSubset(of: Set(r.menu)))
        XCTAssertGreaterThanOrEqual(r.menu.count, 9)
        let perfect = Kitchen.score(r, served: r.orders, checks: r.interruptions.map(\.isCorrect))
        XCTAssertTrue(perfect.perfect)
        let sloppy = Kitchen.score(r, served: r.orders, checks: r.interruptions.map { !$0.isCorrect })
        XCTAssertFalse(sloppy.perfect, "rehearsing instead of checking the change doesn't count")
        let honest = (0..<200).flatMap { Kitchen.round(size: 6, seed: "h\($0)").interruptions }.filter(\.isCorrect).count
        XCTAssertEqual(Double(honest) / 1200, 0.5, accuracy: 0.08)
    }

    func testMissions() {
        let ms = (0..<1000).map { Missions.mission(seed: "m\($0)") }
        XCTAssertEqual(Double(ms.compactMap { $0 }.count) / 1000, 0.6, accuracy: 0.05)
        XCTAssertTrue(ms.compactMap { $0 }.allSatisfy { (15...45).contains($0.appearsAfter) })
        XCTAssertEqual(Missions.hitRate([true, false, true, true]), 0.75)
        XCTAssertEqual(ms.compactMap { $0 }.first?.intention.hasPrefix("When I see the"), true)
    }

    func testDayRecall() {
        let e = DayEntry(day: 20261020, notes: ["Lunch with Hira at the café", "Bought new running shoes", "Watched the cricket"])
        let s = DayRecall.score(entry: e, answer: "I had lunch with Hira, and watched cricket in the evening")
        XCTAssertEqual(s.recalled, 2)
        XCTAssertEqual(DayRecall.score(entry: e, answer: "").recalled, 0)
    }

    func testGatheringPeopleAreDistinctAndRebuildable() throws {
        for seed in ["a", "b", "c", "wedding-1"] {
            let e = Gathering.event(seed: seed, size: 8)
            XCTAssertEqual(e.people.count, 8)
            XCTAssertEqual(Set(e.people.map(\.name)).count, 8, "unique names at an event")
            XCTAssertEqual(Set(e.people.map(\.job)).count, 8)
            for (i, p) in e.people.enumerated() {
                if p.portrait.female { XCTAssertEqual(p.portrait.beard, 0) }
                XCTAssertTrue((p.portrait.female ? Gathering.femaleNames : Gathering.maleNames).contains(p.name))
                for q in e.people[(i + 1)...] { XCTAssertGreaterThanOrEqual(p.portrait.differences(to: q.portrait), Gathering.minDifferences) }
                XCTAssertEqual(try XCTUnwrap(Gathering.person(id: p.id)), p)
            }
            let choices = Gathering.nameChoices(for: e.people[0], among: e.people, seed: seed)
            XCTAssertEqual(choices.count, 4)
            XCTAssertEqual(Set(choices).count, 4)
            XCTAssertTrue(choices.contains(e.people[0].name))
        }
        XCTAssertNil(Gathering.person(id: "nonsense"))
    }

    func testJourneyDelivery() {
        let stops = ["Gate", "Door", "Sofa", "Kitchen", "Stairs", "Bed"]
        let (pack, route) = Journey.delivery(packID: "planets", size: 10, stops: stops, seed: "j")
        XCTAssertEqual(route.count, 6, "capped by the palace")
        XCTAssertEqual(route.map(\.item.keyword), ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn"], "ordered packs keep their order")
        XCTAssertTrue(route[2].scene.lowercased().contains("sofa"))
        XCTAssertTrue(route.allSatisfy { !$0.scene.contains("{") })
        let errands = Journey.packs.first { $0.id == "errands" }!.items[0]
        XCTAssertTrue(Journey.accepts("the dry cleaning", errands))
        XCTAssertTrue(Journey.accepts("laundry", errands))
        XCTAssertFalse(Journey.accepts("stamps", errands))
        let car = Journey.packs.first { $0.id == "errands" }!.items[3]
        XCTAssertFalse(Journey.accepts("card", car), "word by word, not substring")
        let picks = Journey.choices(for: route[0], pack: pack, seed: "j")
        XCTAssertEqual(picks.count, 8)
        XCTAssertTrue(picks.contains("Mercury"))
        XCTAssertTrue(Journey.packs.allSatisfy { $0.items.count >= 7 })
        let items = Journey.items(route: route, pack: pack, palace: "Home", source: "journey:1", at: t0)
        XCTAssertEqual(items.count, 6)
        XCTAssertTrue(items[0].accepts("mercury"))
    }

    func testNumberVaultUnlocksPegsInOrderAndUsesOnlyKnownOnes() throws {
        XCTAssertEqual(NumberVault.studyBatch(stability: [:]), Array(0..<10))
        var st: [Int: Double] = [:]
        for n in 0..<8 { st[n] = 3 }
        XCTAssertEqual(NumberVault.studyBatch(stability: st), Array(10..<20), "8 of 10 known moves on")
        XCTAssertTrue(NumberVault.acceptsPeg("sofa", for: 8))
        XCTAssertTrue(NumberVault.acceptsPeg("cat", for: 71), "your own word that encodes to 71")
        XCTAssertFalse(NumberVault.acceptsPeg("dog", for: 71))
        let known = [12, 34, 47, 3, 8]
        for kind in [NumberChallenge.Kind.pin, .locker, .phone] {
            let c = try XCTUnwrap(NumberVault.challenge(kind: kind, known: known, seed: "n\(kind)"))
            let pairs = kind == .phone ? Array(c.pairs.dropFirst()) : c.pairs
            XCTAssertTrue(pairs.allSatisfy { known.contains(Int($0)!) }, "\(kind): \(c.digits)")
        }
        XCTAssertEqual(try XCTUnwrap(NumberVault.challenge(kind: .year, known: known, seed: "y")).kind, .pin, "no year fits → falls back")
        let y = try XCTUnwrap(NumberVault.challenge(kind: .year, known: [19, 47], seed: "y"))
        XCTAssertEqual(y.digits, "1947")
        let sc = NumberVault.score(y, answer: "1946")
        XCTAssertEqual(sc.pairsRight, 1)
        XCTAssertFalse(sc.perfect)
        XCTAssertTrue(NumberVault.score(y, answer: "19 47").perfect)
    }

    func testStoriesScoreIdeaUnits() {
        for story in Battery.stories {
            XCTAssertEqual(story.units.count, 12, story.title)
            XCTAssertEqual(Battery.score(story, retelling: story.text), 12, "the story itself recalls every idea: \(story.title)")
            XCTAssertEqual(Battery.score(story, retelling: ""), 0)
            let words = story.text.split(separator: " ").count
            XCTAssertTrue((60...90).contains(words), "\(story.title): \(words) words")
        }
        XCTAssertLessThanOrEqual(Battery.score(Battery.stories[0], retelling: "Something about a cat in a library"), 1)
        let forms = Set((0..<8).map { Battery.storyForm(session: $0, userSeed: "u").id })
        XCTAssertEqual(forms.count, 8, "every story once per eight sessions")
        XCTAssertEqual(Battery.selfRatingScore([1, 2, 3, 4, 5, 3]), 3)
        XCTAssertNil(Battery.selfRatingScore([1, 2]))
    }

    // MARK: Plan

    func testCoursePlanVariesAndTeachesInOrder() {
        var previous: Game?
        var counts: [Game: Int] = [:]
        for d in 1...70 {
            let p = CoursePlan.plan(day: d, minutes: 15, dueItems: d > 1 ? 5 : 0, seed: "u")
            XCTAssertNotEqual(p.main, previous, "day \(d): no main game two days running")
            XCTAssertNotEqual(p.quick, p.main)
            if p.lesson { XCTAssertEqual(p.main, p.chapter.teaches, "day \(d)") }
            if p.main == .numberVault { XCTAssertGreaterThanOrEqual(p.chapter.week, 4, "pegs are taught first") }
            if p.backwards { XCTAssertEqual(p.main, .journey); XCTAssertGreaterThanOrEqual(p.chapter.week, 3) }
            previous = p.main
            counts[p.main, default: 0] += 1
        }
        XCTAssertGreaterThan(counts[.journey] ?? 0, 15)
        XCTAssertGreaterThan(counts[.gathering] ?? 0, 15)
        XCTAssertGreaterThan(counts[.numberVault] ?? 0, 8)
        let first = CoursePlan.plan(day: 1, minutes: 15, dueItems: 0, seed: "u")
        XCTAssertTrue(first.storyTest && first.lesson && first.selfRating)
        XCTAssertFalse(first.review)
        XCTAssertNil(first.mission, "missions start on day 3")
        XCTAssertTrue(CoursePlan.plan(day: 15, minutes: 15, dueItems: 3, seed: "u").storyRetell)
        XCTAssertNil(CoursePlan.plan(day: 1, minutes: 10, dueItems: 0, seed: "u").quick, "short days drop the quick game")
        XCTAssertTrue(CoursePlan.plan(day: 40, minutes: 15, dueItems: 3, seed: "u").champion)
        for d in 1...42 { let p = CoursePlan.plan(day: d, minutes: 15, dueItems: 3, seed: "u"); if p.champion { XCTAssertFalse(p.lesson || p.storyTest, "day \(d)") } }
        XCTAssertEqual(CoursePlan.plan(day: 50, minutes: 15, dueItems: 3, seed: "u").chapter.title, "Keeping it sharp")
        let backwardsDays = (15...49).filter { CoursePlan.plan(day: $0, minutes: 15, dueItems: 1, seed: "u").backwards }.count
        XCTAssertGreaterThan(backwardsDays, 4)
    }
}
