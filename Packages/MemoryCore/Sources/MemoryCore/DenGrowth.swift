import Foundation

/// The den grows with *consistency* (days practised), never with scores — effort is rewarded.
public enum DenGrowth {
    public static func stage(activeDaysLast28: Int) -> Int {
        switch activeDaysLast28 {
        case ..<1: return 0
        case 1..<4: return 1
        case 4..<9: return 2
        case 9..<15: return 3
        case 15..<21: return 4
        default: return 5
        }
    }
}

/// Where each room prop sits, in a 390×300 point scene. The canvas engine's `scene()` uses the same table.
public enum RoomScene {
    public struct Prop: Equatable, Sendable {
        public let key: String
        public let x: Double, y: Double, width: Double, height: Double
        public let z: Int
        public let label: String
    }

    public static let size = (width: 390.0, height: 300.0)

    private struct Entry { let key: String; let minStage: Int; let x, y, w, h: Double; let label: String; let z: Int }

    private static let den: [Entry] = [
        Entry(key: "den-window", minStage: 0, x: 22, y: 92, w: 88, h: 79, label: "Night window with the moon", z: 1),
        Entry(key: "den-candles", minStage: 5, x: 36, y: 150, w: 60, h: 35, label: "Candles on the sill", z: 2),
        Entry(key: "den-shelf", minStage: 2, x: 296, y: 70, w: 70, h: 85, label: "Bookshelf", z: 1),
        Entry(key: "den-poster", minStage: 4, x: 228, y: 66, w: 50, h: 55, label: "Skull poster", z: 1),
        Entry(key: "den-lamp", minStage: 1, x: 250, y: 172, w: 50, h: 75, label: "Pink lamp", z: 3),
        Entry(key: "den-plant", minStage: 3, x: 304, y: 184, w: 60, h: 65, label: "Potted plant", z: 3),
        Entry(key: "den-cushion", minStage: 5, x: 72, y: 232, w: 65, h: 25, label: "Cushion", z: 3),
    ]

    private static let atelier: [Entry] = [
        Entry(key: "at-window", minStage: 0, x: 22, y: 90, w: 84, h: 84, label: "Arched window", z: 1),
        Entry(key: "at-chandelier", minStage: 4, x: 160, y: -4, w: 70, h: 45, label: "Brass chandelier", z: 1),
        Entry(key: "at-frame-e", minStage: 1, x: 292, y: 54, w: 60, h: 55, label: "Green landscape painting", z: 1),
        Entry(key: "at-frame-m", minStage: 3, x: 230, y: 70, w: 50, h: 50, label: "Small portrait", z: 1),
        Entry(key: "at-frame-v", minStage: 3, x: 282, y: 124, w: 70, h: 50, label: "Night harbour painting", z: 1),
        Entry(key: "at-palm", minStage: 2, x: 24, y: 184, w: 60, h: 65, label: "Palm in an urn", z: 3),
        Entry(key: "at-easel", minStage: 4, x: 298, y: 172, w: 70, h: 75, label: "Easel with a canvas", z: 3),
        Entry(key: "at-bust", minStage: 5, x: 96, y: 174, w: 50, h: 75, label: "Marble bust", z: 3),
    ]

    private static let denNext = ["a lamp", "a bookshelf", "a plant", "a poster and fairy lights", "a cushion and candles"]
    private static let atelierNext = ["a painting", "a palm", "two more paintings", "an easel and a chandelier", "a marble bust"]

    /// Props visible at a growth stage (0…5), back to front.
    public static func props(atelier: Bool, stage: Int) -> [Prop] {
        let s = min(max(stage, 0), 5)
        return (atelier ? Self.atelier : den)
            .filter { s >= $0.minStage }
            .map { Prop(key: $0.key, x: $0.x, y: $0.y, width: $0.w, height: $0.h, z: $0.z, label: $0.label) }
            .sorted { $0.z < $1.z }
    }

    /// What arrives at the next stage, or nil when the room is fully furnished.
    public static func next(atelier: Bool, stage: Int) -> String? {
        let s = min(max(stage, 0), 5)
        return s >= 5 ? nil : (atelier ? atelierNext : denNext)[s]
    }

    public static func hasFairyLights(atelier: Bool, stage: Int) -> Bool { !atelier && stage >= 4 }
    public static func hasChandelierGlow(atelier: Bool, stage: Int) -> Bool { atelier && stage >= 4 }
}
