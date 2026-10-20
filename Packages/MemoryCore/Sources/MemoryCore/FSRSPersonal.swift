import Foundation

/// One graded review, as the Vault logs it.
public struct ReviewEvent: Sendable {
    public var cardID: String
    public var date: Date
    public var rating: Rating
    /// FSRS's predicted recall probability at the moment of review (0 for a new card).
    public var retrievability: Double

    public init(cardID: String, date: Date, rating: Rating, retrievability: Double = 0) {
        self.cardID = cardID
        self.date = date
        self.rating = rating
        self.retrievability = retrievability
    }
}

/// Fits FSRS to one person. The four initial stabilities (w0–w3: how long a brand-new card
/// lasts after Again / Hard / Good / Easy) vary most between people, and can be estimated
/// from a small log — the same "pretrain" step the FSRS optimizer starts with: for each first
/// rating, the stability that best explains whether the card was recalled at its first
/// review on a later day (maximum likelihood, shrunk toward the defaults).
public enum FSRSPersonal {
    /// Below this the defaults are better than anything we could fit.
    public static let minimumReviews = 50
    /// A first rating needs this many follow-ups before its own stability is fitted.
    public static let minimumPerRating = 4
    /// Pull toward the default stability, in log-space. FSRS's power-law forgetting curve makes
    /// recall depend only weakly on stability, so a light pull is enough to stop one lucky
    /// recall from swinging the fit while letting a real log speak.
    public static let priorWeight = 0.25

    public struct FirstReview: Equatable, Sendable {
        public var rating: Rating
        public var days: Int
        public var recalled: Bool
    }

    /// For each card: its first rating and the outcome of its first review on a later day.
    public static func firstIntervals(_ events: [ReviewEvent]) -> [FirstReview] {
        var byCard: [String: [ReviewEvent]] = [:]
        for e in events { byCard[e.cardID, default: []].append(e) }
        var out: [FirstReview] = []
        for id in byCard.keys.sorted() {
            let list = byCard[id]!.sorted { $0.date < $1.date }
            guard let first = list.first,
                  let next = list.first(where: { FSRSScheduler.wholeDays(from: first.date, to: $0.date) >= 1 }) else { continue }
            out.append(FirstReview(rating: first.rating, days: FSRSScheduler.wholeDays(from: first.date, to: next.date),
                                   recalled: next.rating != .again))
        }
        return out
    }

    /// The stability that maximises the likelihood of the observed recalls, penalised by its
    /// log-distance from `prior`. A grid in log-space keeps it simple and deterministic.
    public static func fitStability(_ samples: [FirstReview], prior: Double, decay: Double = FSRSScheduler.defaultDecay) -> Double {
        guard !samples.isEmpty else { return prior }
        let factor = pow(0.9, -1 / decay) - 1
        let lnPrior = log(prior)
        var best = prior, bestLoss = Double.infinity
        var lnS = log(0.05)
        while lnS <= log(365) + 1e-9 {
            let s = exp(lnS)
            var loss = priorWeight * (lnS - lnPrior) * (lnS - lnPrior)
            for x in samples {
                let r = min(max(pow(1 + factor * Double(x.days) / s, -decay), 1e-6), 1 - 1e-6)
                loss -= x.recalled ? log(r) : log(1 - r)
            }
            if loss < bestLoss { bestLoss = loss; best = s }
            lnS += 0.01
        }
        return best
    }

    /// Personal parameters (the defaults with w0–w3 refitted), or nil until there's enough data.
    public static func pretrain(_ events: [ReviewEvent], base: [Double] = FSRSScheduler.defaultParameters) -> [Double]? {
        guard events.count >= minimumReviews else { return nil }
        let firsts = firstIntervals(events)
        var w = base
        var fitted = false
        for rating in Rating.allCases {
            let samples = firsts.filter { $0.rating == rating }
            guard samples.count >= minimumPerRating else { continue }
            w[rating.rawValue - 1] = min(max(fitStability(samples, prior: base[rating.rawValue - 1], decay: base[20]), 0.01), 100)
            fitted = true
        }
        guard fitted else { return nil }
        // A better first answer can't make a card fade faster.
        for i in 1...3 { w[i] = max(w[i], w[i - 1]) }
        return w
    }

    public struct TrueRetention: Equatable, Sendable {
        /// Reviews of cards last seen on an earlier day.
        public var reviews: Int
        public var recalled: Int
        /// What actually happened…
        public var rate: Double
        /// …and what FSRS expected (mean predicted recall for those same reviews).
        public var predicted: Double
    }

    /// How often you really remembered cards that came back on a later day, against FSRS's forecast.
    public static func trueRetention(_ events: [ReviewEvent]) -> TrueRetention? {
        var last: [String: Date] = [:]
        var n = 0, ok = 0, predicted = 0.0
        for e in events.sorted(by: { $0.date < $1.date }) {
            if let prev = last[e.cardID], FSRSScheduler.wholeDays(from: prev, to: e.date) >= 1 {
                n += 1
                if e.rating != .again { ok += 1 }
                predicted += e.retrievability
            }
            last[e.cardID] = e.date
        }
        guard n > 0 else { return nil }
        return TrueRetention(reviews: n, recalled: ok, rate: Double(ok) / Double(n), predicted: predicted / Double(n))
    }

    public struct RetentionPoint: Equatable, Sendable {
        public var retention: Double
        /// Review effort per card per year (a lapse costs more: it has to be relearned).
        public var workload: Double
        /// Average chance of recalling a card on any day of the year.
        public var knowledge: Double
    }

    public struct RetentionAdvice: Equatable, Sendable {
        public var suggested: Double
        public var points: [RetentionPoint]
    }

    public static let retentionRange: [Double] = (0...10).map { 0.85 + Double($0) / 100 }
    static let lapseCost = 2.5

    /// Simulates a year of reviewing with these parameters at each target from 85 % to 95 %
    /// and suggests the one with the least effort per unit of knowledge kept — FSRS's
    /// "minimum recommended retention", restricted to a range that still feels reliable.
    public static func adviseRetention(parameters: [Double] = FSRSScheduler.defaultParameters,
                                       cards: Int = 200, days: Int = 365) -> RetentionAdvice {
        let points = retentionRange.map { target -> RetentionPoint in
            let s = FSRSScheduler(parameters: parameters, desiredRetention: target, enableFuzzing: false)
            var rng = SeededRandom(seed: 2024)   // same random draws for every target
            var cost = 0.0, memory = 0.0
            for _ in 0..<cards {
                let first: Rating = rng.unit() < 0.2 ? .again : .good
                var stability = s.initialStability(first)
                var difficulty = s.initialDifficulty(first, clamp: true)
                cost += first == .again ? lapseCost : 1
                var day = 0
                while day < days {
                    let interval = s.nextInterval(stability)
                    for t in 0..<min(interval, days - day) {
                        memory += s.retrievability(elapsedDays: Double(t), stability: stability)
                    }
                    day += interval
                    if day >= days { break }
                    let r = s.retrievability(elapsedDays: Double(interval), stability: stability)
                    let rating: Rating = rng.unit() < r ? .good : .again
                    cost += rating == .again ? lapseCost : 1
                    stability = s.nextStability(difficulty: difficulty, stability: stability, retrievability: r, rating: rating)
                    difficulty = s.nextDifficulty(difficulty, rating)
                }
            }
            return RetentionPoint(retention: target, workload: cost / Double(cards), knowledge: memory / Double(cards * days))
        }
        let best = points.min { $0.workload / $0.knowledge < $1.workload / $1.knowledge }!
        return RetentionAdvice(suggested: best.retention, points: points)
    }
}
