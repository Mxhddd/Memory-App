import WidgetKit
import SwiftUI
import MemoryCore

// The ONE app extension (a free Apple ID can only afford one more App ID): every widget,
// Control Center control and the Live Activity live in this bundle.

@main
struct MemoryGardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrailWidget()
        FlashcardWidget()
        RemindersWidget()
        LockScreenWidget()
        QuestLiveActivity()
        StartTrainingControl()
        ReviewCardControl()
        ReminderDoneControl()
    }
}

// MARK: Snapshot timeline (written by the app)

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let isPlaceholder: Bool
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads timelines whenever something changes. As a fallback, refresh hourly and
        // add an entry just after midnight so yesterday's progress never lingers.
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(30)
        let entries = [entry(at: now), entry(at: midnight)]
        completion(Timeline(entries: entries, policy: .after(min(now.addingTimeInterval(3600), midnight))))
    }

    private func entry(at date: Date) -> SnapshotEntry {
        guard var s = SharedStore.readSnapshot() else {
            return SnapshotEntry(date: date, snapshot: .placeholder, isPlaceholder: true)
        }
        if !Calendar.current.isDate(s.updatedAt, inSameDayAs: date) {
            // A new day the app hasn't seen yet: show a fresh, unstarted trail.
            s.questDone = 0
            s.questComplete = false
            s.steps = s.steps.map { WidgetSnapshot.Step(title: $0.title, symbol: $0.symbol, done: false) }
            s.reminders = s.reminders.filter { $0.time > date }
        }
        return SnapshotEntry(date: date, snapshot: s, isPlaceholder: false)
    }
}

extension WidgetSnapshot {
    var theme: Theme { Theme.forID(ThemeID(rawValue: themeRaw) ?? .midnightRaccoon) }
    var atelier: Bool { themeRaw == ThemeID.gildedAtelier.rawValue }
    /// Days until the SideStore signature expires, when it's getting close (≤ 2 days).
    var refreshSoon: Int? {
        guard let expiry = signatureExpiry else { return nil }
        let days = Int(expiry.timeIntervalSinceNow / 86_400)
        return days <= 2 ? max(0, days) : nil
    }
}

enum WidgetLinks {
    static let quest = URL(string: "memorygarden://quest")!
    static let today = URL(string: "memorygarden://today")!
    static let review = URL(string: "memorygarden://review")!
    static let reminders = URL(string: "memorygarden://reminders")!
    static func card(_ id: UUID) -> URL { URL(string: "memorygarden://card/\(id.uuidString)")! }
}

// MARK: Shared pieces

/// The growing room, drawn statically for widgets (props from `RoomScene`, no animation).
struct WidgetRoom: View {
    let theme: Theme
    let stage: Int
    var happy = false

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / RoomScene.size.width
            let atelier = theme.id == .gildedAtelier
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: atelier ? [Color(hex: 0xE9DEC4), Color(hex: 0xEFE6D0)] : [Color(hex: 0x2A2042), Color(hex: 0x1F1730)],
                               startPoint: .top, endPoint: .bottom)
                (atelier ? Color(hex: 0xE2D3B1) : Color(hex: 0x1D1630))
                    .frame(height: 52 * k).offset(y: 248 * k)
                Ellipse().fill(atelier ? Color(hex: 0xC0563B) : Color(hex: 0x3A2550))
                    .frame(width: 240 * k, height: 32 * k).offset(x: 75 * k, y: 237 * k)
                ForEach(RoomScene.props(atelier: atelier, stage: stage), id: \.key) { p in
                    if let art = Sprites.sceneProps[p.key] {
                        PixelSpriteView(art: art).frame(width: p.width * k, height: p.height * k).offset(x: p.x * k, y: p.y * k)
                    }
                }
                PixelSpriteView(art: happy ? theme.mascotHappy : theme.mascotIdle)
                    .frame(width: 120 * k, height: 120 * k).offset(x: 135 * k, y: 136 * k)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(RoomScene.size.width / RoomScene.size.height, contentMode: .fit)
    }
}

/// A row of stepping stones: diamonds in the Den, dots in the Atelier.
struct StoneRow: View {
    let steps: [Bool]
    let theme: Theme
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: size * 0.6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, done in
                Group {
                    if theme.pixelBorders {
                        Rectangle().fill(done ? theme.primary : theme.raised).rotationEffect(.degrees(45)).frame(width: size * 0.75, height: size * 0.75)
                    } else {
                        Circle().fill(done ? theme.primary : theme.raised)
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(steps.filter { $0 }.count) of \(steps.count) steps done")
    }
}

/// Background shared by the Home Screen widgets.
struct WidgetBackdrop: View {
    let theme: Theme
    var body: some View {
        LinearGradient(colors: [theme.backgroundTop, theme.background], startPoint: .top, endPoint: .bottom)
    }
}
