import SwiftUI
import AVFoundation
import MemoryCore

// MARK: Background

struct ThemedBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.backgroundTop, theme.background], startPoint: .top, endPoint: .bottom)
            if theme.id == .midnightRaccoon {
                StarField().opacity(0.55)
            }
        }
        .ignoresSafeArea()
    }
}

/// Deterministic little pixel stars for the raccoon theme.
struct StarField: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 42)
            for _ in 0..<38 {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height * 0.6
                let s: CGFloat = rng.unit() < 0.2 ? 3 : 2
                context.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(Color(hex: 0xFFF4D6)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Surfaces

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

// MARK: Cards

/// One soft surface, no outline: depth comes from tone (Den) or a soft lift (Atelier).
struct ThemedCard: ViewModifier {
    @Environment(\.theme) private var theme
    var raised = false

    func body(content: Content) -> some View {
        content
            .padding(theme.largeTargets ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.shape().fill(raised ? theme.raised : theme.surface))
            .shadow(color: theme.pixelBorders ? .clear : Color(hex: 0x1E2A44).opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

extension View {
    func themedCard(raised: Bool = false) -> some View { modifier(ThemedCard(raised: raised)) }
}

// MARK: Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.bodyEmphasis)
            .foregroundStyle(theme.onPrimary)
            .frame(maxWidth: .infinity, minHeight: theme.minTouch)
            .padding(.horizontal, 16)
            .background(theme.pill.fill(theme.primary.opacity(isEnabled ? 1 : 0.4)))
            .shadow(color: theme.pixelBorders ? .clear : theme.primary.opacity(0.22), radius: 11, x: 0, y: 10)
            .offset(y: configuration.isPressed && theme.pixelBorders ? 2 : 0)
            .scaleEffect(configuration.isPressed && !theme.pixelBorders ? 0.98 : 1)
            .contentShape(theme.pill)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.bodyEmphasis)
            .foregroundStyle(theme.pixelBorders ? theme.text : theme.primary)
            .frame(maxWidth: .infinity, minHeight: theme.minTouch)
            .padding(.horizontal, 16)
            .background(theme.pill.fill(theme.pixelBorders ? theme.raised : theme.primary.opacity(0.08)))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(theme.pill)
    }
}

/// Big tappable answer tile used by all games.
struct ChoiceButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var state: ChoiceState = .idle

    enum ChoiceState { case idle, correct, wrong, selected }

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = {
            switch state {
            case .idle: return theme.surface
            case .selected: return theme.accent.opacity(0.45)
            case .correct: return theme.success.opacity(0.5)
            case .wrong: return theme.primary.opacity(0.35)
            }
        }()
        return configuration.label
            .font(theme.bodyEmphasis)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: theme.minTouch + 8)
            .padding(8)
            .background(theme.shape(step: 6, radius: 18).fill(fill))
            .overlay(theme.shape(step: 6, radius: 18).stroke(theme.pixelBorders || state != .idle ? .clear : theme.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(theme.shape(step: 6, radius: 18))
    }
}

// MARK: Mascot

enum MascotMood { case idle, happy, sleepy, studying }

struct MascotView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var mood: MascotMood = .idle
    var size: CGFloat = 120
    @State private var bob = false

    var body: some View {
        let art: PixelArt = {
            switch mood {
            case .idle: return theme.mascotIdle
            case .happy: return theme.mascotHappy
            case .sleepy: return theme.mascotSleep
            case .studying: return theme.mascotStudy
            }
        }()
        PixelSpriteView(art: art)
            .frame(width: size, height: size)
            .offset(y: bob ? -3 : 3)
            .overlay(alignment: .topTrailing) {
                if mood == .sleepy {
                    Text("z z")
                        .font(theme.display(24))
                        .foregroundStyle(theme.accent)
                        .offset(x: 10, y: -12)
                        .accessibilityHidden(true)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

struct SpeechBubble: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(theme.body)
            .foregroundStyle(theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .themedCard(raised: true)
    }
}

struct SectionTitle: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(theme.display(26))
            .foregroundStyle(theme.text)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressPips: View {
    @Environment(\.theme) private var theme
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                theme.shape(step: 2, radius: 4)
                    .fill(i < done ? theme.primary : theme.raised)
                    .frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(done) of \(total) done")
    }
}

/// Read instructions aloud (audio + text, essential for the older user).
struct ReadAloudButton: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Button {
            Speech.shared.say(text)
        } label: {
            Label("Read aloud", systemImage: "speaker.wave.2.fill")
                .font(theme.caption.weight(.semibold))
                .foregroundStyle(theme.text)
                .frame(minHeight: 44)
        }
    }
}

// MARK: Feedback

@MainActor
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
    }
}

@MainActor
enum SFX {
    enum Sound: String { case correct, gentle, levelup, shiny, bell, tap }

    /// Which look's voice to use: chiptune for the Den, plucked strings and bells for the Atelier.
    static var theme: ThemeID = .midnightRaccoon { didSet { if oldValue != theme { players = [:] } } }
    private static var players: [Sound: AVAudioPlayer] = [:]
    static var enabled: Bool { UserDefaults.standard.object(forKey: "sfxEnabled") as? Bool ?? true }

    static func play(_ sound: Sound) {
        guard enabled else { return }
        // .ambient: respects the silent switch and mixes with music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        if players[sound] == nil, let url = url(for: sound) {
            players[sound] = try? AVAudioPlayer(contentsOf: url)
        }
        players[sound]?.currentTime = 0
        players[sound]?.play()
    }

    private static func url(for sound: Sound) -> URL? {
        let suffix = theme == .gildedAtelier ? "atelier" : "den"
        return Bundle.main.url(forResource: "\(sound.rawValue)-\(suffix)", withExtension: "wav")
            ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
    }
}

enum Haptic {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
