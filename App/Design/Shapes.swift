import SwiftUI

// Shared by the app and the widget extension.

/// Rectangle with two-step pixel corners: the Den's answer to rounded corners.
struct PixelCornerShape: Shape {
    var step: CGFloat = 8

    func path(in r: CGRect) -> Path {
        let n = min(step, r.width / 4, r.height / 4), h = n / 2
        var p = Path()
        p.addLines([
            CGPoint(x: r.minX, y: r.minY + n), CGPoint(x: r.minX + h, y: r.minY + n), CGPoint(x: r.minX + h, y: r.minY + h),
            CGPoint(x: r.minX + n, y: r.minY + h), CGPoint(x: r.minX + n, y: r.minY),
            CGPoint(x: r.maxX - n, y: r.minY), CGPoint(x: r.maxX - n, y: r.minY + h), CGPoint(x: r.maxX - h, y: r.minY + h),
            CGPoint(x: r.maxX - h, y: r.minY + n), CGPoint(x: r.maxX, y: r.minY + n),
            CGPoint(x: r.maxX, y: r.maxY - n), CGPoint(x: r.maxX - h, y: r.maxY - n), CGPoint(x: r.maxX - h, y: r.maxY - h),
            CGPoint(x: r.maxX - n, y: r.maxY - h), CGPoint(x: r.maxX - n, y: r.maxY),
            CGPoint(x: r.minX + n, y: r.maxY), CGPoint(x: r.minX + n, y: r.maxY - h), CGPoint(x: r.minX + h, y: r.maxY - h),
            CGPoint(x: r.minX + h, y: r.maxY - n), CGPoint(x: r.minX, y: r.maxY - n),
        ])
        p.closeSubpath()
        return p
    }
}

/// The theme's surface shape: stepped pixel corners (Den) or soft continuous corners (Atelier).
struct ThemeShape: Shape {
    var pixel: Bool
    var step: CGFloat = 8
    var radius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        pixel ? PixelCornerShape(step: step).path(in: rect)
              : RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

extension Theme {
    /// Surface shape at a given size class: `step` for the Den, `radius` for the Atelier.
    func shape(step: CGFloat = 8, radius: CGFloat = 28) -> ThemeShape { ThemeShape(pixel: pixelBorders, step: step, radius: radius) }
    /// Pill for buttons and chips.
    var pill: ThemeShape { ThemeShape(pixel: pixelBorders, step: 6, radius: 999) }
    var hairline: Color { pixelBorders ? Color(hex: 0x2E2640) : Color(hex: 0xE4D9C1) }
}
