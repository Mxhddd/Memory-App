import Foundation

/// Metamemory: how well you can tell how much you'll remember. Before recall you guess your
/// score; comparing guesses with results shows whether you over- or under-estimate yourself.
/// Accurate judgments of learning help people decide what to study again.
public enum Calibration {
    public struct Point: Equatable, Sendable {
        public var predicted: Double   // fraction of items you expected to recall
        public var actual: Double      // fraction you did recall
        public init(predicted: Int, actual: Int, total: Int) {
            let n = Double(max(total, 1))
            self.predicted = min(max(Double(predicted) / n, 0), 1)
            self.actual = min(max(Double(actual) / n, 0), 1)
        }
    }

    public enum Verdict: String, Sendable { case overconfident, underconfident, calibrated }

    public struct Summary: Equatable, Sendable {
        public var count: Int
        /// Mean (predicted − actual): positive = you expect more than you get.
        public var bias: Double
        /// Mean |predicted − actual|.
        public var error: Double
        public var verdict: Verdict
    }

    /// Guesses within this many percentage points on average count as well calibrated.
    public static let tolerance = 0.10
    public static let minimumPoints = 3

    public static func summary(_ points: [Point]) -> Summary? {
        guard points.count >= minimumPoints else { return nil }
        let n = Double(points.count)
        let bias = points.reduce(0) { $0 + $1.predicted - $1.actual } / n
        let error = points.reduce(0) { $0 + abs($1.predicted - $1.actual) } / n
        let verdict: Verdict = bias > tolerance ? .overconfident : bias < -tolerance ? .underconfident : .calibrated
        return Summary(count: points.count, bias: bias, error: error, verdict: verdict)
    }
}
