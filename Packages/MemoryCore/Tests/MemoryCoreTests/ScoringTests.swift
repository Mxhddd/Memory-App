import XCTest
@testable import MemoryCore

final class LearningCurveTests: XCTestCase {
    func testRecoversKnownCurve() {
        let truth = LearningCurveFit(asymptote: 0.9, rate: 0.6, day1: 0.4, sse: 0)
        let ys = (1...7).map { truth.predict(day: Double($0)) }
        let fit = LearningCurve.fit(ys)!
        XCTAssertEqual(fit.asymptote, 0.9, accuracy: 0.01)
        XCTAssertEqual(fit.rate, 0.6, accuracy: 0.02)
        XCTAssertLessThan(fit.sse, 1e-4)
    }

    func testAUCBounds() {
        XCTAssertEqual(LearningCurve.normalizedAUC([1, 1, 1, 1])!, 1, accuracy: 1e-12)
        XCTAssertEqual(LearningCurve.normalizedAUC([0, 0, 0])!, 0, accuracy: 1e-12)
        XCTAssertEqual(LearningCurve.normalizedAUC([0, 1])!, 0.5, accuracy: 1e-12)
    }

    func testPracticeGain() {
        XCTAssertEqual(LearningCurve.practiceGain([0.4, 0.5, 0.6, 0.6, 0.7, 0.8, 0.9])!, 0.4, accuracy: 1e-12)
        // Flat performance → no practice effect (the SWAN signature)
        XCTAssertEqual(LearningCurve.practiceGain([0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6])!, 0, accuracy: 1e-12)
    }
}

final class ReliableChangeTests: XCTestCase {
    func testSRBWorkedExampleFromPhilipsPaper() {
        // Predicted 107.42, observed 73.1, SEE 33.52 → z = −1.02 → "stable"
        let z = ReliableChange.srbZ(observed: 73.1, predicted: 107.42, see: 33.52)
        XCTAssertEqual(z, -1.02, accuracy: 0.005)
        XCTAssertGreaterThan(z, ReliableChange.threshold90)
    }

    func testJacobsonTruaxByHand() {
        // s = 10, r = 0.8 → SEM = 4.4721, S_diff = 6.3246; (40 − 50)/6.3246 = −1.5811
        XCTAssertEqual(ReliableChange.sem(sd: 10, reliability: 0.8), 4.4721, accuracy: 1e-4)
        XCTAssertEqual(ReliableChange.jacobsonTruax(x1: 50, x2: 40, sd: 10, reliability: 0.8), -1.5811, accuracy: 1e-4)
        // With an expected practice gain of +3, the same drop is more meaningful.
        XCTAssertEqual(ReliableChange.practiceAdjusted(x1: 50, x2: 40, expectedGain: 3, sd: 10, reliability: 0.8), -2.0555, accuracy: 1e-4)
    }

    func testShrinkage() {
        XCTAssertEqual(ReliableChange.shrunkExpectedGain(personal: [], prior: 0.05), 0.05)
        XCTAssertEqual(ReliableChange.shrunkExpectedGain(personal: [0.1, 0.1], prior: 0.0, priorWeight: 2), 0.05, accuracy: 1e-12)
    }
}

final class EWMATests: XCTestCase {
    func testAsymptoticLimit() {
        // λ = 0.2, L = 2.7: limit = −2.7·√(0.2/1.8) = −0.9
        XCTAssertEqual(EWMAChart().asymptoticLowerLimit, -0.9, accuracy: 1e-12)
    }

    func testSustainedDropBreachesButOneBadDayDoesNot() {
        var oneBad = EWMAChart()
        for _ in 0..<10 { oneBad.add(0) }
        oneBad.add(-3)
        XCTAssertFalse(oneBad.isBelowLimit)

        var sustained = EWMAChart()
        for _ in 0..<10 { sustained.add(0) }
        for _ in 0..<8 { sustained.add(-1.5) }
        XCTAssertTrue(sustained.isBelowLimit)
    }
}

final class RaschTests: XCTestCase {
    func testAbilityRisesWithSuccessAndTargetsSeventyFivePercent() {
        var a = RaschAbility(target: 0.75)
        let start = a.theta
        for _ in 0..<8 { a.record(difficulty: 0, correct: true) }
        XCTAssertGreaterThan(a.theta, start)
        let p = RaschAbility.probability(theta: a.theta, b: a.targetDifficulty)
        XCTAssertEqual(p, 0.75, accuracy: 1e-9)
    }
}

final class BanditTests: XCTestCase {
    func testLearnsBetterArm() {
        var bandit = ThompsonBandit(armIDs: ["morning", "evening"])
        for _ in 0..<40 {
            bandit.update(armID: "morning", reward: 1)
            bandit.update(armID: "evening", reward: 0)
        }
        var rng = SeededRandom(seed: 7)
        let picks = (0..<50).compactMap { _ in bandit.choose(using: &rng) }
        XCTAssertGreaterThan(picks.filter { $0 == "morning" }.count, 45)
    }

    func testPromptCapStillHolds() {
        var rng = SeededRandom(seed: 1)
        XCTAssertFalse(PromptPolicy().shouldPrompt(sentToday: 3, using: &rng))
    }
}

final class StimuliTests: XCTestCase {
    func testSpritesAreRectangularAndUsePaletteColours() {
        let all = [Sprites.mochiIdle, Sprites.mochiHappy, Sprites.mochiSleep, Sprites.professor] + Array(Sprites.trinkets.values)
        for art in all {
            XCTAssertTrue(art.rows.allSatisfy { $0.count == art.width })
            for ch in art.rows.joined() where ch != "." {
                XCTAssertNotNil(art.palette[ch], "missing palette entry \(ch)")
            }
        }
        XCTAssertEqual(Set(Sprites.trinketOrder), Set(Sprites.trinkets.keys))
    }

    func testDeterministicAlternateForms() {
        XCTAssertEqual(Stimuli.villagers(count: 6, seed: "b1").map(\.name), Stimuli.villagers(count: 6, seed: "b1").map(\.name))
        XCTAssertEqual(Stimuli.runeSet(count: 8, seed: "x").count, 8)
        let sigs = Stimuli.runeSet(count: 12, seed: "x").map(Stimuli.runeSignature)
        XCTAssertEqual(Set(sigs).count, 12)
    }

    func testRecognitionBoardHasNoTargetsAsFoils() {
        let targets = Stimuli.wordList(form: 0)
        let board = Stimuli.recognitionBoard(targets: targets, seed: "s")
        XCTAssertEqual(board.count, 24)
        XCTAssertEqual(Set(board).count, 24)
    }

    func testPortraitsAreValid() {
        for i in 0..<30 {
            let art = Stimuli.portrait(seed: "p\(i)")
            XCTAssertEqual(art.width, 12)
            for ch in art.rows.joined() { XCTAssertNotNil(art.palette[ch]) }
        }
    }

    func testAnswerMatching() {
        XCTAssertTrue(AnswerMatch.matches("Lantren", "lantern") == false) // transposition = 2 edits
        XCTAssertTrue(AnswerMatch.matches(" Pillow ", "pillow"))
        XCTAssertTrue(AnswerMatch.matches("candel", "candle") == false)
        XCTAssertTrue(AnswerMatch.matches("gardn", "garden"))
        XCTAssertFalse(AnswerMatch.matches("cat", "car"))
    }

    func testRunesAreNeverTooPlain() {
        for i in 0..<300 {
            XCTAssertTrue(Stimuli.isComplex(Stimuli.rune(seed: "r\(i)")), "rune r\(i) is too plain")
        }
    }
}
