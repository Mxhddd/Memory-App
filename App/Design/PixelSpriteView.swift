import SwiftUI
import MemoryCore

/// Draws a `PixelArt` crisply at any size (integer-ish blocks, no smoothing).
struct PixelSpriteView: View {
    let art: PixelArt

    var body: some View {
        Canvas { context, size in
            let w = CGFloat(art.width), h = CGFloat(art.height)
            guard w > 0, h > 0 else { return }
            let scale = min(size.width / w, size.height / h)
            let ox = (size.width - w * scale) / 2
            let oy = (size.height - h * scale) / 2
            art.forEachPixel { x, y, rgb in
                // +0.5 overlap hides hairline seams between blocks
                let rect = CGRect(x: ox + CGFloat(x) * scale, y: oy + CGFloat(y) * scale,
                                  width: scale + 0.5, height: scale + 0.5)
                context.fill(Path(rect), with: .color(Color(hex: rgb)))
            }
        }
        .aspectRatio(CGFloat(max(art.width, 1)) / CGFloat(max(art.height, 1)), contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A 7×7 rune glyph from `Stimuli.rune`.
struct RuneView: View {
    let rune: [[Bool]]
    var color: Color

    var body: some View {
        Canvas { context, size in
            let n = CGFloat(rune.count)
            let scale = min(size.width, size.height) / (n + 2)
            let o = (min(size.width, size.height) - n * scale) / 2
            for (y, row) in rune.enumerated() {
                for (x, on) in row.enumerated() where on {
                    let rect = CGRect(x: o + CGFloat(x) * scale, y: o + CGFloat(y) * scale, width: scale + 0.5, height: scale + 0.5)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Rune symbol")
    }
}
