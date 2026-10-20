import SwiftUI
import MemoryCore
#if canImport(UIKit)
import UIKit
#endif

/// Two themes, one codebase. Each phone's profile picks one; all game logic and scoring is shared.
enum ThemeID: String, CaseIterable, Codable, Identifiable {
    case midnightRaccoon
    case gildedAtelier

    var id: String { rawValue }
}

struct Theme {
    let id: ThemeID

    // Colours (all text/background pairs checked for ≥ 4.5:1 contrast — see docs/DESIGN.md)
    let background: Color
    let backgroundTop: Color
    let surface: Color
    let raised: Color
    let primary: Color
    let onPrimary: Color
    let accent: Color
    let text: Color
    let secondaryText: Color
    let success: Color
    /// "Not quite" feedback — always distinct from `success` and paired with an icon.
    let danger: Color
    let outline: Color
    let ornament: Color
    let colorScheme: ColorScheme

    // Typography
    let displayFontName: String     // pixel (raccoon) or serif display (atelier) — headings ≥ 24 pt only
    let fallbackDesign: Font.Design

    // Shape & feel
    let cornerRadius: CGFloat
    let pixelBorders: Bool
    let largeTargets: Bool          // roomier cards & buttons (Atelier)

    // Mascot
    let mascotIdle: PixelArt
    let mascotHappy: PixelArt
    let mascotSleep: PixelArt
    let mascotStudy: PixelArt

    let copy: ThemeCopy

    /// Display face for headings. Never used below 24 pt; scales with Dynamic Type.
    func display(_ size: CGFloat = 30) -> Font {
        let s = max(size, 24)
        if Self.fontAvailable(displayFontName) {
            return .custom(displayFontName, size: s, relativeTo: .title)
        }
        return .system(size: s, weight: .bold, design: fallbackDesign)
    }

    /// Body copy is always the system font so Dynamic Type & Bold Text work everywhere.
    var body: Font { largeTargets ? .title3 : .body }
    var bodyEmphasis: Font { (largeTargets ? Font.title3 : .body).weight(.semibold) }
    var caption: Font { largeTargets ? .body : .subheadline }
    var minTouch: CGFloat { largeTargets ? 60 : 48 }

    static func fontAvailable(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: name, size: 12) != nil
        #else
        return false
        #endif
    }

    static func forID(_ id: ThemeID) -> Theme {
        switch id {
        case .midnightRaccoon: return .midnightRaccoon
        case .gildedAtelier: return .gildedAtelier
        }
    }
}

extension Theme {
    /// Cute-goth pixel world for the girlfriend: lilac/ink/bubblegum, Mochi the raccoon.
    static let midnightRaccoon = Theme(
        id: .midnightRaccoon,
        background: Color(hex: 0x17121F),
        backgroundTop: Color(hex: 0x2A2042),
        surface: Color(hex: 0x241D31),
        raised: Color(hex: 0x2F2640),
        primary: Color(hex: 0xF4A7C6),
        onPrimary: Color(hex: 0x17121F),
        accent: Color(hex: 0xB9A3E3),
        text: Color(hex: 0xFFF4D6),
        secondaryText: Color(hex: 0xCFC3E6),
        success: Color(hex: 0x9FE3C8),
        danger: Color(hex: 0xFF8FA3),
        outline: Color(hex: 0x0B0810),
        ornament: Color(hex: 0xFFE08A),
        colorScheme: .dark,
        displayFontName: "PixelifySansMG-SemiBold",
        fallbackDesign: .monospaced,
        cornerRadius: 4,
        pixelBorders: true,
        largeTargets: false,
        mascotIdle: Sprites.mochiIdle,
        mascotHappy: Sprites.mochiHappy,
        mascotSleep: Sprites.mochiSleep,
        mascotStudy: Sprites.mochiStudy,
        copy: .raccoon
    )

    /// Elegant, calm and highly legible for Mom: ivory paper, ink-blue text, emerald & brass.
    static let gildedAtelier = Theme(
        id: .gildedAtelier,
        background: Color(hex: 0xF7F1E3),
        backgroundTop: Color(hex: 0xEFE6D0),
        surface: Color(hex: 0xFFFBF2),
        raised: Color(hex: 0xF1E8D4),
        primary: Color(hex: 0x1F5C4A),
        onPrimary: Color(hex: 0xFFFBF2),
        accent: Color(hex: 0x1E2A44),
        text: Color(hex: 0x1E2A44),
        secondaryText: Color(hex: 0x4A5368),
        success: Color(hex: 0x1F5C4A),
        danger: Color(hex: 0xA8442F),           // terracotta: ≥ 4.9:1 on every Atelier surface
        outline: Color(hex: 0xB08D3C),          // decorative brass (borders only)
        ornament: Color(hex: 0x7A5C17),         // text-safe brass: ≥ 5.1:1 on every Atelier surface
        colorScheme: .light,
        displayFontName: "CormorantGaramondMG-SemiBold",
        fallbackDesign: .serif,
        cornerRadius: 22,
        pixelBorders: false,
        largeTargets: true,
        mascotIdle: Sprites.professor,
        mascotHappy: Sprites.professor,
        mascotSleep: Sprites.professor,
        mascotStudy: Sprites.professor,
        copy: .atelier
    )
}

/// Theme-specific names and voice. Wording follows the general-wellness guardrail:
/// "memory training", "brain fitness", "track your practice" — never diagnostic language.
struct ThemeCopy {
    let appTitle: String
    let questTitle: String
    let denTitle: String
    let shinyName: String
    let realmNames: [RealmTask: String]
    let realmBlurbs: [RealmTask: String]
    let celebrations: [String]
    let napLine: String
    let eveningSession: String
    let morningSession: String

    func realmName(_ t: RealmTask) -> String { realmNames[t] ?? t.rawValue }
    func realmBlurb(_ t: RealmTask) -> String { realmBlurbs[t] ?? "" }

    func greeting(name: String, mascot: String, hour: Int) -> String {
        switch hour {
        case 5..<12: return "Morning, \(name). \(mascot) is up early for you."
        case 12..<17: return "Hi \(name)! \(mascot) saved you a snack."
        case 17..<22: return "Evening, \(name). \(eveningSession) time?"
        default: return "Late night, \(name). \(mascot) is keeping watch."
        }
    }

    static let raccoon = ThemeCopy(
        appTitle: "Midnight Den",
        questTitle: "Tonight's Training",
        denTitle: "Progress",
        shinyName: "shinies",
        realmNames: [
            .routeWalk: "Den Walk",
            .wordSprint: "Midnight Sprint",
            .sprintRetention: "Dawn Recall",
            .numberSprint: "Number Heist",
            .dualNBack: "Firefly n-back",
            .complexSpan: "Moon Maths Span",
            .sequences: "Firefly Sequences",
            .faceName: "Night Market Regulars",
            .ancientRunes: "Ancient Runes",
            .stash: "Mochi's Stash",
            .wordRecall: "Benchmark · Word Recall",
            .digitSpan: "Benchmark · Digit Span",
            .championTest: "Champion Trial",
            .championDelayed: "Champion Trial · next day",
            .listReview: "Echo Recall",
        ],
        realmBlurbs: [
            .routeWalk: "Walk your palace until it's automatic.",
            .wordSprint: "Place words along your palace, recall in order.",
            .sprintRetention: "What survived the night?",
            .numberSprint: "Digits → Major-system pictures.",
            .dualNBack: "Positions + sounds, n steps back.",
            .complexSpan: "Letters to keep while doing sums.",
            .sequences: "Follow the fireflies in order.",
            .faceName: "Hook names onto faces.",
            .ancientRunes: "Link symbols to meanings.",
            .stash: "Where did Mochi hide everything?",
            .wordRecall: "30 words, any method. Your progress yardstick.",
            .digitSpan: "How many digits can you hold?",
            .championTest: "The 72-word test memory champions take.",
            .championDelayed: "What stayed after 24 hours?",
            .listReview: "An older list: what is still there?",
        ],
        celebrations: ["Shiny get!", "Mochi is so proud", "Brain sparkle", "Den got cozier", "Paws up!"],
        napLine: "Mochi took a nap. The den is right where you left it.",
        eveningSession: "Night Shift",
        morningSession: "Dawn Recall"
    )

    static let atelier = ThemeCopy(
        appTitle: "Gilded Atelier",
        questTitle: "Today's Training",
        denTitle: "Progress",
        shinyName: "gilded seals",
        realmNames: [
            .routeWalk: "Walk the Gallery",
            .wordSprint: "Word Sprint",
            .sprintRetention: "Morning Recall",
            .numberSprint: "Number Sprint",
            .dualNBack: "Dual n-back",
            .complexSpan: "Operation Span",
            .sequences: "Constellations",
            .faceName: "Salon Portraits",
            .ancientRunes: "Old Scripts",
            .stash: "Cabinet of Curiosities",
            .wordRecall: "Benchmark · Word Recall",
            .digitSpan: "Benchmark · Digit Span",
            .championTest: "Champion test",
            .championDelayed: "Champion test · next day",
            .listReview: "Revisit a list",
        ],
        realmBlurbs: [
            .routeWalk: "Walk your palace until it's automatic.",
            .wordSprint: "Place words along your palace, recall in order.",
            .sprintRetention: "What remained overnight?",
            .numberSprint: "Digits become Major-system pictures.",
            .dualNBack: "Positions and sounds, n steps back.",
            .complexSpan: "Hold letters while checking sums.",
            .sequences: "Retrace the stars in order.",
            .faceName: "Hook names onto faces.",
            .ancientRunes: "Link symbols to meanings.",
            .stash: "Where was each treasure placed?",
            .wordRecall: "30 words, any method. Your yardstick.",
            .digitSpan: "How many digits can you hold?",
            .championTest: "The 72-word test memory champions take.",
            .championDelayed: "What remained after a day?",
            .listReview: "An older list: what remains?",
        ],
        celebrations: ["Beautifully done", "Well remembered", "Splendid", "Sharp as ever"],
        napLine: "The atelier waited patiently. Welcome back.",
        eveningSession: "Evening study",
        morningSession: "Morning recall"
    )
}

// MARK: Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .midnightRaccoon
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
