import Foundation

/// Pixel art as text rows + a character→RGB palette. Rendered by the app with `Canvas`,
/// so sprites cost nothing to make and can be recoloured per theme.
public struct PixelArt: Equatable, Sendable {
    public var rows: [String]
    public var palette: [Character: UInt32]

    public init(rows: [String], palette: [Character: UInt32]) {
        self.rows = rows
        self.palette = palette
    }

    public var width: Int { rows.map(\.count).max() ?? 0 }
    public var height: Int { rows.count }

    /// Visits every opaque pixel.
    public func forEachPixel(_ body: (_ x: Int, _ y: Int, _ rgb: UInt32) -> Void) {
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                if let rgb = palette[ch] { body(x, y, rgb) }
            }
        }
    }

    public func recolored(_ overrides: [Character: UInt32]) -> PixelArt {
        PixelArt(rows: rows, palette: palette.merging(overrides) { _, new in new })
    }

    /// Mirror left↔right.
    public var flipped: PixelArt {
        PixelArt(rows: rows.map { String($0.reversed()) }, palette: palette)
    }
}
