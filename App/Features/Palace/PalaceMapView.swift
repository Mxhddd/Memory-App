import SwiftUI
import MemoryCore

/// Your palace as a little floor plan: each stop is a room tile on a snaking path, and the
/// mascot walks to the current stop. Used while placing words, recalling them, walking the
/// route, and as a live preview in the palace editor.
struct PalaceMapView: View {
    enum Mark { case placed, correct, missed }

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stops: [String]
    var current: Int = 0
    var marks: [Int: Mark] = [:]
    var labels: [Int: String] = [:]
    /// Route walk: names of stops you haven't reached yet stay hidden.
    var hideAhead = false
    var walker = true
    /// Visible height; taller maps scroll to keep the current stop in view.
    var viewport: CGFloat = 200

    private static let reference: CGFloat = 332
    private static let walkerHeadroom: CGFloat = 18

    var body: some View {
        let map = PalaceMap(count: stops.count)
        let k = Self.reference / CGFloat(max(map.width, 1))
        let cur = min(max(current, 0), max(stops.count - 1, 0))
        let fullHeight = CGFloat(map.height) * k + Self.walkerHeadroom + 4
        let view = min(viewport, fullHeight)
        let scroll = CGFloat(map.scroll(toward: cur, viewport: Double((view - Self.walkerHeadroom) / k))) * k

        ZStack(alignment: .topLeading) {
            path(map, upTo: map.tiles.count - 1, k: k)
                .stroke(theme.hairline, style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 2, lineCap: .round, dash: theme.pixelBorders ? [6, 6] : [2, 6]))
            path(map, upTo: cur, k: k)
                .stroke(theme.primary, style: StrokeStyle(lineWidth: theme.pixelBorders ? 4 : 2, lineCap: .round, dash: theme.pixelBorders ? [6, 6] : [2, 6]))
            ForEach(map.tiles, id: \.index) { t in
                tile(t, current: cur, size: CGFloat(map.tile) * k)
                    .offset(x: CGFloat(t.x) * k, y: CGFloat(t.y) * k)
            }
            if walker, let t = map.tiles[safe: cur] {
                MascotView(mood: .idle, size: 40)
                    .offset(x: CGFloat(t.x + map.tile) * k - 30, y: CGFloat(t.y) * k - Self.walkerHeadroom)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: cur)
            }
        }
        .frame(width: Self.reference, height: CGFloat(map.height) * k, alignment: .topLeading)
        .offset(y: Self.walkerHeadroom - scroll)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: scroll)
        .frame(width: Self.reference, height: view, alignment: .topLeading)
        .clipped()
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Palace map: stop \(cur + 1) of \(stops.count)" + (hideAhead ? "" : ", \(stops[safe: cur] ?? "")"))
    }

    private func path(_ map: PalaceMap, upTo last: Int, k: CGFloat) -> Path {
        var p = Path()
        for t in map.tiles.prefix(max(0, last + 1)) {
            let pt = CGPoint(x: CGFloat(t.centerX) * k, y: CGFloat(t.centerY) * k)
            if t.index == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    private func tile(_ t: PalaceMap.Tile, current: Int, size: CGFloat) -> some View {
        let isCurrent = t.index == current
        let mark = marks[t.index]
        let hidden = hideAhead && t.index >= current && mark != .correct
        let fill: Color = {
            if isCurrent { return theme.pixelBorders ? Color(hex: 0x3B2E55) : .white }
            switch mark {
            case .correct: return theme.success.opacity(theme.pixelBorders ? 0.16 : 0.10)
            case .missed: return theme.danger.opacity(theme.pixelBorders ? 0.18 : 0.12)
            default: return theme.pixelBorders ? theme.surface : theme.raised
            }
        }()
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(t.index + 1)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isCurrent ? theme.primary : theme.secondaryText.opacity(0.8))
            Spacer(minLength: 0)
            Text(hidden ? "?" : stops[t.index])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isCurrent ? theme.text : theme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text(labels[t.index] ?? " ")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(mark == .missed ? theme.danger : mark == .correct ? theme.success : theme.ornament)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 6, leading: 5, bottom: 5, trailing: 5))
        .frame(width: size, height: size)
        .background(theme.shape(step: 6, radius: 18).fill(fill))
        .overlay(theme.shape(step: 6, radius: 18).stroke(isCurrent && !theme.pixelBorders ? theme.primary : .clear, lineWidth: 2))
        .animation(.easeInOut(duration: 0.3), value: isCurrent)
    }
}
