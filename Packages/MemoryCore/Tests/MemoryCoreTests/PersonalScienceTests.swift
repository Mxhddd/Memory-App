import XCTest
@testable import MemoryCore

final class PersonalScienceTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Cards whose first rating was Good really last `trueStability` days; the fit should find it.
    private func syntheticLog(trueGood: Double, trueAgain: Double, cards: Int) -> [ReviewEvent] {
        var rng = SeededRandom("pretrain")
        let decay = FSRSScheduler.defaultDecay, factor = pow(0.9, -1 / decay) - 1
        var events: [ReviewEvent] = []
        for i in 0..<cards {
            let first: Rating = i % 4 == 0 ? .again : .good
            let s = first == .again ? trueAgain : trueGood
            let days = 1 + Int(rng.unit() * 20)
            let r = pow(1 + factor * Double(days) / s, -decay)
            let recalled = rng.unit() < r
            let start = t0.addingTimeInterval(Double(i) * 60)
            events.append(ReviewEvent(cardID: "c\(i)", date: start, rating: first))
            events.append(ReviewEvent(cardID: "c\(i)", date: start.addingTimeInterval(600), rating: .good))   // same-day step
            events.append(ReviewEvent(cardID: "c\(i)", date: start.addingTimeInterval(Double(days) * 86_400 + 30),
                                      rating: recalled ? .good : .again, retrievability: r))
        }
        return events
    }

    func testFirstIntervalsSkipSameDaySteps() {
        let firsts = FSRSPersonal.firstIntervals(syntheticLog(trueGood: 10, trueAgain: 1, cards: 8))
        XCTAssertEqual(firsts.count, 8)
        XCTAssertTrue(firsts.allSatisfy { $0.days >= 1 })
        XCTAssertEqual(firsts.filter { $0.rating == .again }.count, 2)
    }

    func testPretrainRecoversInitialStability() throws {
        let w = try XCTUnwrap(FSRSPersonal.pretrain(syntheticLog(trueGood: 20, trueAgain: 1.0, cards: 400)))
        XCTAssertEqual(w.count, 21)
        XCTAssertEqual(w[2], 20, accuracy: 7, "good stability fitted near the truth (default is 2.3)")
        XCTAssertEqual(w[0], 1.0, accuracy: 0.6)
        XCTAssertEqual(w[1], max(FSRSScheduler.defaultParameters[1], w[0]), accuracy: 1e-9, "unfitted ratings keep defaults")
        XCTAssertLessThanOrEqual(w[0], w[1]); XCTAssertLessThanOrEqual(w[1], w[2]); XCTAssertLessThanOrEqual(w[2], w[3])
        XCTAssertEqual(Array(w[4...]), Array(FSRSScheduler.defaultParameters[4...]))
    }

    func testPretrainNeedsEnoughReviews() {
        XCTAssertNil(FSRSPersonal.pretrain(syntheticLog(trueGood: 10, trueAgain: 1, cards: 10)))
    }

    func testFitShrinksTowardPriorWithLittleData() {
        let one = [FSRSPersonal.FirstReview(rating: .good, days: 30, recalled: true)]
        let s = FSRSPersonal.fitStability(one, prior: 2.3)
        XCTAssertGreaterThan(s, 2.3)
        XCTAssertLessThan(s, 30, "one lucky recall shouldn't jump all the way")
    }

    func testTrueRetention() throws {
        let e = [
            ReviewEvent(cardID: "a", date: t0, rating: .good),
            ReviewEvent(cardID: "a", date: t0.addingTimeInterval(300), rating: .good),             // same day: ignored
            ReviewEvent(cardID: "a", date: t0.addingTimeInterval(3 * 86_400), rating: .good, retrievability: 0.9),
            ReviewEvent(cardID: "b", date: t0, rating: .good),
            ReviewEvent(cardID: "b", date: t0.addingTimeInterval(2 * 86_400), rating: .again, retrievability: 0.8),
        ]
        let tr = try XCTUnwrap(FSRSPersonal.trueRetention(e))
        XCTAssertEqual(tr.reviews, 2)
        XCTAssertEqual(tr.recalled, 1)
        XCTAssertEqual(tr.rate, 0.5, accuracy: 1e-9)
        XCTAssertEqual(tr.predicted, 0.85, accuracy: 1e-9)
        XCTAssertNil(FSRSPersonal.trueRetention(Array(e.prefix(2))))
    }

    func testRetentionAdvice() {
        let advice = FSRSPersonal.adviseRetention(cards: 80, days: 365)
        XCTAssertEqual(advice.points.count, 11)
        XCTAssertTrue(FSRSPersonal.retentionRange.contains(advice.suggested))
        XCTAssertGreaterThan(advice.points.last!.workload, advice.points.first!.workload, "aiming higher costs more reviews")
        XCTAssertGreaterThan(advice.points.last!.knowledge, advice.points.first!.knowledge, "…and keeps more")
    }

    func testCalibration() throws {
        XCTAssertNil(Calibration.summary([Calibration.Point(predicted: 5, actual: 5, total: 10)]))
        let over = try XCTUnwrap(Calibration.summary((0..<3).map { _ in Calibration.Point(predicted: 9, actual: 5, total: 10) }))
        XCTAssertEqual(over.verdict, .overconfident)
        XCTAssertEqual(over.bias, 0.4, accuracy: 1e-9)
        let under = try XCTUnwrap(Calibration.summary([.init(predicted: 2, actual: 8, total: 10), .init(predicted: 4, actual: 7, total: 10), .init(predicted: 5, actual: 6, total: 10)]))
        XCTAssertEqual(under.verdict, .underconfident)
        let fine = try XCTUnwrap(Calibration.summary([.init(predicted: 6, actual: 7, total: 10), .init(predicted: 7, actual: 6, total: 10), .init(predicted: 30, actual: 40, total: 10)]))
        XCTAssertEqual(fine.verdict, .calibrated, "predictions and results are clamped to 0…1")
        XCTAssertEqual(fine.error, 0.2 / 3, accuracy: 1e-9)
    }

    func testEncodingPaceLadder() {
        XCTAssertEqual(EncodingPace.pace(kind: .wordSprint, accuracies: []), 6)
        XCTAssertEqual(EncodingPace.pace(kind: .wordSprint, accuracies: [0.95]), 5.4)
        XCTAssertEqual(EncodingPace.pace(kind: .wordSprint, accuracies: [0.95, 0.7]), 5.4, "steady accuracy keeps the pace")
        XCTAssertEqual(EncodingPace.pace(kind: .wordSprint, accuracies: [0.95, 0.4]), 6.2)
        XCTAssertEqual(EncodingPace.pace(kind: .wordSprint, accuracies: Array(repeating: 1, count: 30)), 3, "floor")
        XCTAssertEqual(EncodingPace.pace(kind: .numberSprint, accuracies: Array(repeating: 0, count: 30)), 4.5, "ceiling")
        XCTAssertEqual(Course.encodingSeconds(kind: .wordSprint, size: 20, pace: 4.4), 88)
        XCTAssertEqual(Course.encodingSeconds(kind: .wordSprint, size: 5, pace: 3), 45)
    }
}
