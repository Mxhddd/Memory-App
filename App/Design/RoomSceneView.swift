import SwiftUI
import MemoryCore

/// The illustrated Den / Gallery that fills in as you train (`DenGrowth` stage 0…5).
/// Laid out in a 390×300 point space from `RoomScene` and scaled to the available width.
struct RoomSceneView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var stage: Int
    var mood: MascotMood = .idle

    private var atelier: Bool { theme.id == .gildedAtelier }

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / RoomScene.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: atelier ? [Color(hex: 0xE9DEC4), Color(hex: 0xEFE6D0)]
                                               : [Color(hex: 0x2A2042), Color(hex: 0x241A38), Color(hex: 0x1F1730)],
                               startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: atelier ? [Color(hex: 0xE2D3B1), Color(hex: 0xEBDDBE)] : [Color(hex: 0x1D1630), Color(hex: 0x17121F)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 52 * k)
                    .offset(y: 248 * k)
                if RoomScene.hasFairyLights(atelier: atelier, stage: stage) { FairyLights(scale: k, animate: !reduceMotion) }
                if RoomScene.hasChandelierGlow(atelier: atelier, stage: stage) {
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFE08A).opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 75 * k))
                        .frame(width: 150 * k, height: 150 * k)
                        .offset(x: 120 * k, y: -40 * k)
                }
                rug(k)
                ForEach(RoomScene.props(atelier: atelier, stage: stage), id: \.key) { p in
                    if let art = Sprites.sceneProps[p.key] {
                        PixelSpriteView(art: art)
                            .frame(width: p.width * k, height: p.height * k)
                            .offset(x: p.x * k, y: p.y * k)
                            .zIndex(Double(p.z))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Ellipse().fill(.black.opacity(0.28))
                    .frame(width: 90 * k, height: 12 * k)
                    .offset(x: 150 * k, y: 250 * k)
                    .zIndex(2)
                MascotView(mood: mood, size: 120 * k)
                    .offset(x: 135 * k, y: 136 * k)
                    .zIndex(2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(RoomScene.size.width / RoomScene.size.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func rug(_ k: CGFloat) -> some View {
        Group {
            if atelier {
                Ellipse().fill(Color(hex: 0xC0563B))
                    .overlay(Ellipse().inset(by: 2 * k).stroke(Color(hex: 0xD9A441), lineWidth: 2 * k))
                    .overlay(Ellipse().inset(by: 8 * k).stroke(Color(hex: 0xD9A441), lineWidth: 1 * k))
                    .frame(width: 230 * k, height: 30 * k)
                    .offset(x: 80 * k, y: 238 * k)
            } else {
                Ellipse().fill(Color(hex: 0x3A2550))
                    .overlay(Ellipse().inset(by: 2.5 * k).stroke(Color(hex: 0x4E3268), lineWidth: 5 * k))
                    .frame(width: 250 * k, height: 34 * k)
                    .offset(x: 70 * k, y: 236 * k)
            }
        }
    }

    private var accessibilityText: String {
        let place = atelier ? "The gallery" : "The den"
        if let next = RoomScene.next(atelier: atelier, stage: stage) {
            return "\(place) at stage \(stage) of 5; next to appear: \(next)"
        }
        return "\(place), fully furnished"
    }
}

private struct FairyLights: View {
    let scale: CGFloat
    let animate: Bool
    @State private var glow = false
    private let colors: [Color] = [Color(hex: 0xFFE08A), Color(hex: 0xF4A7C6), Color(hex: 0x9FE3C8)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: 0x3A2D52)).frame(height: 2 * scale).offset(y: 30 * scale)
            ForEach(0..<13, id: \.self) { i in
                Rectangle()
                    .fill(colors[i % 3])
                    .frame(width: 6 * scale, height: 6 * scale)
                    .shadow(color: colors[i % 3], radius: 5 * scale)
                    .opacity(glow && i % 2 == 0 ? 0.55 : 1)
                    .offset(x: CGFloat(8 + i * 30) * scale, y: CGFloat(33 + (i % 2) * 3) * scale)
            }
        }
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
