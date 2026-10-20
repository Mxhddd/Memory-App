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
        let benchmark = Set((0..<WordBank.benchmarkForms).flatMap { WordBank.benchmarkForm($0) })
        XCTAssertEqual(benchmark.count, WordBank.benchmarkForms * WordBank.benchmarkFormSize)
        XCTAssertTrue(benchmark.isDisjoint(with: Set(WordBank.sprintPool)))
        XCTAssertGreaterThanOrEqual(WordBank.sprintPool.count, 100)
        XCTAssertEqual(Set(WordBank.all).count, WordBank.all.count)
    }
}

final class BenchmarkTests: XCTestCase {
    func testSchedule() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Karachi")!
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        let p = BenchmarkPlanner(start: start, calendar: cal)
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: start)! }
        XCTAssertTrue(p.isDue(on: start, lastCompleted: nil))
        XCTAssertFalse(p.isDue(on: day(5), lastCompleted: day(0)))
        XCTAssertTrue(p.isDue(on: day(14), lastCompleted: day(0)))
        XCTAssertTrue(p.isDue(on: day(16), lastCompleted: day(0)))   // missed day 14 → still due
        XCTAssertFalse(p.isDue(on: day(20), lastCompleted: day(15)))
        XCTAssertEqual(p.dueDays(through: 140), [0, 14, 28, 42, 72, 102, 132])
    }

    func testReliableImprovement() {
        // Dresler-like jump (26 → 62 of 72 ≈ 11 → 26 of 30) is clearly reliable; +2 words is not.
        XCTAssertTrue(Improvement.isReliable(baseline: 11, latest: 26, norms: Improvement.wordRecall))
        XCTAssertFalse(Improvement.isReliable(baseline: 11, latest: 13, norms: Improvement.wordRecall))
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
}
