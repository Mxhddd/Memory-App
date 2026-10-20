import XCTest
@testable import MemoryCore

final class NBackTests: XCTestCase {
    func testBlockHasExactTargetCountsAndNoAccidentalMatches() {
        for n in 1...5 {
            let block = NBack.block(n: n, seed: "s\(n)")
            XCTAssertEqual(block.count, 20 + n)
            XCTAssertEqual(block.filter(\.positionMatch).count, NBack.targetsPerModality)
            XCTAssertEqual(block.filter(\.letterMatch).count, NBack.targetsPerModality)
            XCTAssertEqual(block.filter { $0.positionMatch && $0.letterMatch }.count, NBack.bothTargets)
            XCTAssertTrue(block.prefix(n).allSatisfy { !$0.positionMatch && !$0.letterMatch })
            for i in n..<block.count {
                XCTAssertEqual(block[i].positionMatch, block[i].position == block[i - n].position)
                XCTAssertEqual(block[i].letterMatch, block[i].letter == block[i - n].letter)
            }
        }
    }

    func testPerfectResponsesScoreZeroErrorsAndLevelUp() {
        let block = NBack.block(n: 2, seed: "x")
        let responses = block.map { NBackResponse(position: $0.positionMatch, letter: $0.letterMatch) }
        let score = NBack.score(block, responses: responses)
        XCTAssertEqual(score.positionErrors, 0)
        XCTAssertEqual(score.letterErrors, 0)
        XCTAssertEqual(score.accuracy, 1)
        XCTAssertEqual(NBack.nextLevel(current: 2, score: score), 3)
    }

    func testNoResponsesMeansSixMissesPerModalityAndLevelDown() {
        let block = NBack.block(n: 3, seed: "y")
        let score = NBack.score(block, responses: Array(repeating: NBackResponse(), count: block.count))
        XCTAssertEqual(score.positionErrors, 6)
        XCTAssertEqual(NBack.nextLevel(current: 3, score: score), 2)
        XCTAssertEqual(NBack.nextLevel(current: 1, score: score), 1)
    }

    func testMiddleBandStays() {
        let s = NBackBlockScore(positionErrors: 4, letterErrors: 2, hits: 8, targets: 12)
        XCTAssertEqual(NBack.nextLevel(current: 2, score: s), 2)
    }
}

final class SpanTests: XCTestCase {
    func testComplexSpanPartialCredit() {
        let a = ComplexSpan.set(size: 3, seed: "a")
        let b = ComplexSpan.set(size: 4, seed: "b")
        let recalled = [a.map(\.letter), [b[0].letter, b[1].letter, "Z", "Z"]]
        let s = ComplexSpan.score(sets: [a, b], recalled: recalled, processingCorrect: 6, processingTotal: 7)
        XCTAssertEqual(s.partialCredit, (1.0 + 0.5) / 2, accuracy: 1e-12)
        XCTAssertEqual(s.absolute, 3)
        XCTAssertTrue(s.valid)
        XCTAssertFalse(ComplexSpan.score(sets: [a], recalled: [[]], processingCorrect: 1, processingTotal: 3).valid)
    }

    func testEquationsAreHonest() {
        for i in 0..<50 {
            for item in ComplexSpan.set(size: 5, seed: "e\(i)") {
                let parts = item.equation.split(separator: " ")
                let a = Int(parts[0])!, b = Int(parts[2])!, shown = Int(parts[4])!
                let truth = parts[1] == "×" ? a * b : a + b
                XCTAssertEqual(item.equationIsTrue, truth == shown, item.equation)
            }
        }
    }

    func testSetSizesCoverRange() {
        XCTAssertEqual(ComplexSpan.setSizes(minSize: 3, maxSize: 7, repetitions: 2, seed: "s").sorted(), [3, 3, 4, 4, 5, 5, 6, 6, 7, 7])
    }

    func testDigitSpanStopRule() {
        XCTAssertFalse(DigitSpan.shouldStop([(4, true), (4, false)]))
        XCTAssertTrue(DigitSpan.shouldStop([(4, true), (5, false), (5, false)]))
        XCTAssertEqual(DigitSpan.span([(4, true), (5, true), (6, false), (6, false)]), 5)
        XCTAssertEqual(DigitSpan.digits(length: 9, seed: "d").count, 9)
    }
}

final class MajorSystemTests: XCTestCase {
    func testEveryPegEncodesToItsNumber() {
        XCTAssertEqual(MajorSystem.pegs.count, 100)
        for (n, word) in MajorSystem.pegs.enumerated() {
            XCTAssertEqual(MajorSystem.encode(word), String(format: "%02d", n), "\(word) should encode to \(n)")
        }
    }

    func testCommonWords() {
        XCTAssertEqual(MajorSystem.encode("cat"), "71")
        XCTAssertEqual(MajorSystem.encode("Butterfly"), "91485")
        XCTAssertEqual(MajorSystem.encode("knight"), "21")
    }

    func testChunks() {
        XCTAssertEqual(MajorSystem.chunks("71920"), ["71", "92", "0"])
        XCTAssertEqual(MajorSystem.randomDigits(count: 12, seed: "x").count, 12)
    }
}

final class LociAndCourseTests: XCTestCase {
    func testPositionalScoring() {
        let s = Loci.scoreWords(recalled: ["apple", "brige", "", "cat"], targets: ["apple", "bridge", "cat", "dog"])
        XCTAssertEqual(s.inPlace, 2) // apple, bridge (one typo)
        XCTAssertEqual(s.anyPlace, 3) // + cat out of place
        XCTAssertEqual(Loci.scoreDigits(recalled: "71 92 03", target: "719204").inPlace, 5)
    }

    func testCourseShape() {
        XCTAssertEqual(Course.day(1, wordLevel: 10, digitLevel: 6).lesson?.id, "images")
        XCTAssertTrue(Course.day(1, wordLevel: 10, digitLevel: 6).drills.isEmpty)
        XCTAssertEqual(Course.day(3, wordLevel: 10, digitLevel: 6).drills.last?.kind, .wordSprint)
        XCTAssertEqual(Course.day(8, wordLevel: 10, digitLevel: 6).lesson?.id, "major1")
        for d in 2...Course.length {
            XCTAssertFalse(Course.day(d, wordLevel: 20, digitLevel: 12).drills.isEmpty, "day \(d) has no drill")
        }
        XCTAssertEqual(Course.day(99, wordLevel: 10, digitLevel: 6).day, Course.length)
        XCTAssertEqual(Set(Course.lessons.map(\.id)).count, Course.lessons.count)
    }

    func testProgression() {
        XCTAssertEqual(Course.nextWordLevel(current: 20, accuracy: 0.85), 25)
        XCTAssertEqual(Course.nextWordLevel(current: 20, accuracy: 0.6), 20)
        XCTAssertEqual(Course.nextWordLevel(current: 10, accuracy: 0.2), 10)
        XCTAssertEqual(Course.nextDigitLevel(current: 10, accuracy: 0.9), 14)
    }

    func testWordBankSeparatesBenchmarkFromPractice() {
        let benchmark = Set(WordBank.benchmarkForms.flatMap { $0 })
        let champion = Set(WordBank.championForms.flatMap { $0 })
        XCTAssertEqual(benchmark.count, WordBank.formCount * WordBank.benchmarkFormSize)
        XCTAssertEqual(champion.count, WordBank.championForms.count * ChampionTest.size)
        XCTAssertTrue(benchmark.isDisjoint(with: champion))
        XCTAssertTrue(benchmark.isDisjoint(with: Set(WordBank.sprintPool)))
        XCTAssertTrue(champion.isDisjoint(with: Set(WordBank.sprintPool)))
        XCTAssertGreaterThanOrEqual(WordBank.sprintPool.count, 300)
        XCTAssertEqual(Set(WordBank.all).count, WordBank.all.count)
        XCTAssertTrue(WordBank.championForms.allSatisfy { $0.count == ChampionTest.size })
    }

    /// Alternate forms must be interchangeable: every form mean within 0.05 SD of every other
    /// on concreteness, frequency and length.
    func testFormsAreEquated() {
        for forms in [WordBank.benchmarkForms, WordBank.championForms] {
            let words = forms.flatMap { $0 }
            let measures: [(String) -> Double] = [
                { WordBank.norms[$0]!.concreteness }, { WordBank.norms[$0]!.zipf }, { Double($0.count) },
            ]
            for measure in measures {
                let all = words.map(measure)
                let mean = all.reduce(0, +) / Double(all.count)
                let sd = (all.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(all.count - 1)).squareRoot()
                let means = forms.map { f in f.map(measure).reduce(0, +) / Double(f.count) }
                XCTAssertLessThan((means.max()! - means.min()!) / sd, 0.05)
            }
        }
    }
}

final class BenchmarkTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Karachi")!
        return c
    }()

    func testBaselineThenSchedule() {
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        let p = BenchmarkPlanner(start: start, calendar: cal)
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: start)! }
        XCTAssertTrue(p.isDue(on: start, lastCompleted: nil, completed: 0))
        XCTAssertFalse(p.isDue(on: day(0), lastCompleted: day(0), completed: 1))   // one baseline a day
        XCTAssertTrue(p.isDue(on: day(1), lastCompleted: day(0), completed: 1))
        XCTAssertTrue(p.isDue(on: day(6), lastCompleted: day(1), completed: 2))    // a missed day just waits
        XCTAssertFalse(p.isDue(on: day(7), lastCompleted: day(6), completed: 3))
        XCTAssertTrue(p.isDue(on: day(14), lastCompleted: day(6), completed: 3))
        XCTAssertTrue(p.isDue(on: day(16), lastCompleted: day(6), completed: 3))   // missed day 14 → still due
        XCTAssertFalse(p.isDue(on: day(20), lastCompleted: day(15), completed: 4))
        XCTAssertEqual(p.dueDays(through: 140), [14, 28, 42, 72, 102, 132])
        XCTAssertNil(p.nextDay(after: day(1), completed: 2))
        XCTAssertEqual(p.nextDay(after: day(3), completed: 3), 14)
        XCTAssertEqual(p.nextDay(after: day(50), completed: 6), 72)
    }

    func testFormOrderIsALatinSquare() {
        // Within a person every form comes up once per cycle; across people the starting form varies.
        let people = (0..<24).map { "user-\($0)" }
        for person in people {
            XCTAssertEqual(Set((0..<6).map { BenchmarkPlanner.form(forSession: $0, userSeed: person) }).count, 6)
            XCTAssertEqual(Set((0..<3).map { BenchmarkPlanner.championForm(forSession: $0, userSeed: person) }).count, 3)
        }
        XCTAssertGreaterThan(Set(people.map { BenchmarkPlanner.form(forSession: 0, userSeed: $0) }).count, 3)
    }

    func testReliableImprovement() {
        // Dresler-like jump (26 → 62 of 72 ≈ 11 → 26 of 30) is clearly reliable; +2 words is not.
        XCTAssertTrue(Improvement.isReliable(baseline: 11, latest: 26, norms: Improvement.wordRecall))
        XCTAssertFalse(Improvement.isReliable(baseline: 11, latest: 13, norms: Improvement.wordRecall))
    }

    func testPersonalNorms() {
        XCTAssertNil(Improvement.personal(baselines: [10, 11], prior: Improvement.wordRecall))
        // A steady person (10, 11, 10) gets a tighter band than the textbook; a noisy one (6, 14, 10) a wider one.
        let steady = Improvement.personal(baselines: [10, 11, 10], prior: Improvement.wordRecall)!
        let noisy = Improvement.personal(baselines: [6, 14, 10], prior: Improvement.wordRecall)!
        let priorSEM = ReliableChange.sem(sd: 4, reliability: 0.8)
        XCTAssertEqual(steady.baseline, 31.0 / 3, accuracy: 1e-9)
        XCTAssertLessThan(steady.sem, priorSEM)
        XCTAssertGreaterThan(noisy.sem, priorSEM)
        XCTAssertLessThan(steady.threshold, noisy.threshold)
        XCTAssertTrue(Improvement.isReliable(latest: 16, personal: steady))
        XCTAssertFalse(Improvement.isReliable(latest: 16, personal: noisy))
        // Practice gain never goes negative, even when the baseline drifted down.
        XCTAssertGreaterThanOrEqual(Improvement.personal(baselines: [14, 12, 10], prior: Improvement.wordRecall)!.expectedGain, 0)
    }

    func testChampionSchedule() {
        XCTAssertTrue(ChampionTest.isDue(courseDay: 1, taken: 0, daysSinceLast: nil))
        XCTAssertFalse(ChampionTest.isDue(courseDay: 20, taken: 1, daysSinceLast: 19))
        XCTAssertTrue(ChampionTest.isDue(courseDay: 42, taken: 1, daysSinceLast: 41))
        XCTAssertFalse(ChampionTest.isDue(courseDay: 42, taken: 2, daysSinceLast: 10))
        XCTAssertTrue(ChampionTest.isDue(courseDay: 42, taken: 2, daysSinceLast: 30))
        XCTAssertTrue(ChampionTest.delayedDue(daysSinceTest: 1))
        XCTAssertFalse(ChampionTest.delayedDue(daysSinceTest: 2))
    }

    func testListReviewPicksTheMostOverdueCheck() {
        let lists = [ListReview.List(seed: "a", size: 10, day: 0), ListReview.List(seed: "b", size: 12, day: 2)]
        XCTAssertNil(ListReview.due(lists: lists, done: [], today: 2))                           // day 1 is Dawn Recall's
        XCTAssertEqual(ListReview.due(lists: lists, done: [], today: 3), .init(seed: "a", size: 10, offset: 3))
        XCTAssertEqual(ListReview.due(lists: lists, done: [], today: 5), .init(seed: "a", size: 10, offset: 3))
        XCTAssertEqual(ListReview.due(lists: lists, done: ["a#3"], today: 5), .init(seed: "b", size: 12, offset: 3))
        XCTAssertEqual(ListReview.due(lists: lists, done: ["a#3", "b#3"], today: 7), .init(seed: "a", size: 10, offset: 7))
        XCTAssertNil(ListReview.due(lists: lists, done: ["a#3", "b#3"], today: 6))
        XCTAssertEqual(ListReview.due(lists: lists, done: [], today: 21), .init(seed: "b", size: 12, offset: 7))  // 12 days late
        XCTAssertEqual(ListReview.due(lists: lists, done: ["b#7"], today: 21), .init(seed: "a", size: 10, offset: 21))
        XCTAssertNil(ListReview.due(lists: lists, done: [], today: 40))
        let curve = ListReview.curve([(0, 0.9), (1, 0.8), (1, 0.6), (7, 0.5)])
        XCTAssertEqual(curve.map(\.offset), [0, 1, 7])
        XCTAssertEqual(curve[1].mean, 0.7, accuracy: 1e-9)
    }
}

final class VaultImportTests: XCTestCase {
    func testSeparatorsAndComments() {
        let cards = VaultImport.parse("# vocab\nhola;hello\nmerci\tthank you\nuno, one, first\n\nbad line")
        XCTAssertEqual(cards, [.init(prompt: "hola", answer: "hello"), .init(prompt: "merci", answer: "thank you"),
                               .init(prompt: "uno", answer: "one, first")])
    }

    func testCloze() {
        let cards = VaultImport.parse("The {{c::hippocampus}} binds {{c::episodes}}")
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0], .init(prompt: "The […] binds episodes", answer: "hippocampus"))
        XCTAssertEqual(cards[1], .init(prompt: "The hippocampus binds […]", answer: "episodes"))
    }

    func testStarterPacks() {
        XCTAssertEqual(VaultImport.majorPegs.count, 100)
        XCTAssertEqual(VaultImport.majorPegs[71].answer, "cat")
        XCTAssertEqual(VaultImport.capitals.count, 30)
    }
}

final class SpriteTests: XCTestCase {
    func testEveryStashItemHasASprite() {
        for (_, name) in Stimuli.stashItems {
            guard let art = Sprites.stashItems[name] else { return XCTFail("no sprite for \(name)") }
            XCTAssertEqual(art.width, 12, name)
            XCTAssertEqual(art.height, 12, name)
            for row in art.rows { for ch in row where ch != "." { XCTAssertNotNil(art.palette[ch], "\(name): colour \(ch)") } }
        }
    }

    func testRoomPropsHaveSpritesAndGrowWithStage() {
        for atelier in [false, true] {
            var previous = 0
            for stage in 0...5 {
                let props = RoomScene.props(atelier: atelier, stage: stage)
                XCTAssertGreaterThanOrEqual(props.count, previous)
                previous = props.count
                for p in props {
                    guard let art = Sprites.sceneProps[p.key] else { return XCTFail("no sprite for \(p.key)") }
                    for row in art.rows { XCTAssertEqual(row.count, art.width, p.key); for ch in row where ch != "." { XCTAssertNotNil(art.palette[ch], "\(p.key): colour \(ch)") } }
                }
            }
            XCTAssertEqual(RoomScene.props(atelier: atelier, stage: 0).count, 1)
            XCTAssertNil(RoomScene.next(atelier: atelier, stage: 5))
            XCTAssertNotNil(RoomScene.next(atelier: atelier, stage: 0))
        }
        XCTAssertEqual(RoomScene.props(atelier: false, stage: 5).count, 7)
        XCTAssertEqual(RoomScene.props(atelier: true, stage: 5).count, 8)
    }

    func testPalaceMapSnakesSoNeighboursTouch() {
        let map = PalaceMap(count: 10)
        XCTAssertEqual(map.tiles.map(\.column), [0, 1, 2, 3, 3, 2, 1, 0, 0, 1])
        XCTAssertEqual(map.tiles.map(\.row), [0, 0, 0, 0, 1, 1, 1, 1, 2, 2])
        for (a, b) in zip(map.tiles, map.tiles.dropFirst()) {
            XCTAssertEqual(abs(a.row - b.row) + abs(a.column - b.column), 1, "stop \(b.index) is not next to \(a.index)")
        }
        XCTAssertEqual(map.width, 332)
        XCTAssertEqual(map.height, 266)
        XCTAssertEqual(map.scroll(toward: 0, viewport: 190), 0)
        XCTAssertEqual(map.scroll(toward: 9, viewport: 190), 76)
        XCTAssertEqual(PalaceMap(count: 0).height, 0)
    }
}
