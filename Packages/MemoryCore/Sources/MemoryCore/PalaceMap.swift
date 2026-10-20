import Foundation

/// Walkable palace map: stops snake through rows of `columns` tiles (left→right, then right→left),
/// so consecutive stops are always neighbours. The canvas engine's `PalaceMap.layout` matches this.
public struct PalaceMap: Equatable, Sendable {
    public struct Tile: Equatable, Sendable {
        public let index: Int, row: Int, column: Int
        public let x: Double, y: Double
        public var centerX: Double { x + tileSize / 2 }
        public var centerY: Double { y + tileSize / 2 }
        let tileSize: Double
    }

    public let tiles: [Tile]
    public let columns: Int
    public let tile: Double
    public let rowHeight: Double
    public let width: Double
    public let height: Double

    public init(count: Int, columns: Int = 4, tile: Double = 74, gapX: Double = 12, gapY: Double = 22) {
        let cols = max(columns, 1)
        tiles = (0..<max(count, 0)).map { i in
            let row = i / cols, k = i % cols
            let col = row % 2 == 0 ? k : cols - 1 - k
            return Tile(index: i, row: row, column: col, x: Double(col) * (tile + gapX), y: Double(row) * (tile + gapY), tileSize: tile)
        }
        self.columns = cols
        self.tile = tile
        rowHeight = tile + gapY
        width = Double(cols) * tile + Double(cols - 1) * gapX
        let rows = tiles.last.map { $0.row + 1 } ?? 0
        height = rows == 0 ? 0 : Double(rows) * tile + Double(rows - 1) * gapY
    }

    /// Vertical scroll that keeps the current stop's row centred in a viewport of height `viewport`.
    public func scroll(toward current: Int, viewport: Double) -> Double {
        guard !tiles.isEmpty else { return 0 }
        let t = tiles[min(max(current, 0), tiles.count - 1)]
        return max(0, min(height - viewport, t.centerY - viewport / 2))
    }
}
