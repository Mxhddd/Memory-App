import XCTest
@testable import MemoryCore

final class FSRS6Tests: XCTestCase {
    /// Expected values generated with py-fsrs 6.3.2 (Scheduler(enable_fuzzing=False)), reviewing
    /// each time exactly when the card falls due. Columns: rating, state, step, stability, difficulty, interval(s).
    let reference: [(Rating, CardState, Int?, Double, Double, TimeInterval)] = [
        (.good, .learning, 1, 2.3065, 2.118103970459016, 600),
        (.good, .review, nil, 2.3065, 2.111214235785395, 172_800),
        (.good, .review, nil, 10.971048263078135, 2.1043313908464483, 950_400),
        (.again, .relearning, 0, 1.53901253028147, 7.389975788014609, 600),
        (.good, .review, nil, 1.5718415897918614, 7.377814181523433, 172_800),
        (.easy, .review, nil, 7.870267819245711, 6.486830244144543, 691_200),
        (.hard, .review, nil, 16.127352845625936, 7.653022571649363, 1_382_400),
        (.good, .review, nil, 34.32316808962278, 7.640597918374552, 2_937_600),
        (.again, .relearning, 0, 2.394677611750222, 9.209708949000708, 600),
        (.again, .relearning, 0, 0.8027313765857881, 9.725465074812517, 600),
        (.good, .review, nil, 0.8557298288106621, 9.710967979034542, 86_400),
        (.good, .review, nil, 1.5361105195983475, 9.696485380352346, 172_800),
    ]

    func testMatchesPyFSRSReferenceHistory() {
        let scheduler = FSRSScheduler(enableFuzzing: false)
        let start = Date(timeIntervalSince1970: 1_767_258_000) // 2026-01-01 09:00 UTC
        var card = FSRSCard(due: start)
        var now = start
        for (i, row) in reference.enumerated() {
            if i > 0 { now = card.due }
            card = scheduler.review(card, rating: row.0, at: now)
            XCTAssertEqual(card.state, row.1, "state at review \(i)")
            XCTAssertEqual(card.step, row.2, "step at review \(i)")
            XCTAssertEqual(card.stability!, row.3, accuracy: 1e-9, "stability at review \(i)")
            XCTAssertEqual(card.difficulty!, row.4, accuracy: 1e-9, "difficulty at review \(i)")
            XCTAssertEqual(card.due.timeIntervalSince(now), row.5, accuracy: 1e-6, "interval at review \(i)")
        }
    }

    func testRetrievabilityIsNinetyPercentAtStability() {
        let s = FSRSScheduler()
        for stability in [0.5, 1, 3.3, 10, 100] {
            XCTAssertEqual(s.retrievability(elapsedDays: stability, stability: stability), 0.9, accuracy: 1e-12)
        }
    }

    func testIntervalEqualsStabilityAtNinetyPercent() {
        let s = FSRSScheduler(desiredRetention: 0.9)
        XCTAssertEqual(s.nextInterval(20), 20)
        XCTAssertEqual(s.nextInterval(47.4), 47)
    }

    func testHigherRetentionGivesShorterIntervals() {
        // py-fsrs: desired_retention=0.92 → [1, 2, 7, 35]
        let s = FSRSScheduler(desiredRetention: 0.92)
        XCTAssertEqual([1.0, 3.3, 10.0, 47.5].map { s.nextInterval($0) }, [1, 2, 7, 35])
    }

    func testFuzzStaysNearInterval() {
        let s = FSRSScheduler(enableFuzzing: true)
        var card = FSRSCard(state: .review, stability: 30, difficulty: 5, due: Date(), lastReview: Date().addingTimeInterval(-30 * 86_400))
        card = s.review(card, rating: .good, at: Date(), random: { 0.5 })
        let days = card.due.timeIntervalSinceNow / 86_400
        XCTAssertGreaterThan(days, 20)
    }
}

final class ErrorlessTests: XCTestCase {
    func testLadderGraduatesAfterAllRungs() {
        var session = ErrorlessSession<String>()
        let t0 = Date(timeIntervalSince1970: 0)
        session.present("aunt", at: t0)
        XCTAssertTrue(session.due(at: t0.addingTimeInterval(29)).isEmpty)
        XCTAssertEqual(session.due(at: t0.addingTimeInterval(30)), ["aunt"])
        var t = t0.addingTimeInterval(30)
        for gap in [60.0, 120, 240] {
            XCTAssertFalse(session.record("aunt", recalled: true, at: t))
            t = t.addingTimeInterval(gap)
            XCTAssertEqual(session.due(at: t), ["aunt"])
        }
        XCTAssertTrue(session.record("aunt", recalled: true, at: t))
        XCTAssertTrue(session.isFinished)
    }

    func testMissRestartsLadderAndCountsPresentation() {
        var session = ErrorlessSession<Int>()
        let t0 = Date(timeIntervalSince1970: 0)
        session.present(1, at: t0)
        session.record(1, recalled: true, at: t0.addingTimeInterval(30))
        session.record(1, recalled: false, at: t0.addingTimeInterval(90))
        XCTAssertEqual(session.items[0].rung, 0)
        XCTAssertEqual(session.items[0].presentations, 2)
        XCTAssertEqual(session.secondsUntilNext(from: t0.addingTimeInterval(90))!, 30, accuracy: 1e-9)
    }
}
