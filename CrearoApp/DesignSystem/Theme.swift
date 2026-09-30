import SwiftUI

// An uncoated-paper palette for Crearo's little theatre. Stable names keep the wider app in tune
// with the daily game. Saturated colour belongs to the artwork and the one primary action.
enum Theme {
    static let ember  = Color(red: 0.66, green: 0.25, blue: 0.17)
    static let candle = Color(red: 0.20, green: 0.26, blue: 0.23)
    static let moss   = Color(red: 0.27, green: 0.42, blue: 0.32)
    static let magic  = Color(red: 0.35, green: 0.36, blue: 0.52)
    static let sky    = Color(red: 0.24, green: 0.42, blue: 0.52)
    static let berry  = Color(red: 0.57, green: 0.27, blue: 0.33)
    static let sun    = Color(red: 0.55, green: 0.37, blue: 0.10)

    static let fog   = Color(red: 0.75, green: 0.72, blue: 0.64)
    static let grey  = Color(red: 0.40, green: 0.39, blue: 0.34)
    static let edge  = Color(red: 0.73, green: 0.68, blue: 0.56)
    static let night = Color(red: 0.95, green: 0.92, blue: 0.85)
    static let paper = Color(red: 0.98, green: 0.95, blue: 0.88)
    static let panel = Color(red: 1.00, green: 0.98, blue: 0.93)
    static let ink   = Color(red: 0.18, green: 0.22, blue: 0.20)

    static let title   = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let heading = Font.system(.title2, design: .serif).weight(.semibold)
    static let body    = Font.system(.body)
    static let rainbow: [Color] = [ember, sun, moss, sky, magic, berry]
}

/// A static paper ground. Grain carries the tactile feeling without moving behind readable text.
struct PaperPageBackground: View {
    var body: some View {
        Theme.night
            .overlay(PaperGrainView(opacity: 0.028))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct PaperCardSurface: View {
    var color: Color = Theme.panel
    var cornerRadius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .overlay {
                PaperGrainView(opacity: 0.035)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.edge.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: Theme.ink.opacity(0.06), radius: 0, x: 0, y: 3)
            .accessibilityHidden(true)
    }
}

struct HearthCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .background(PaperCardSurface())
    }
}

struct GlowTag: View {
    let text: String
    var color: Color = Theme.magic
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.08)))
            .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 1))
            .foregroundStyle(color)
    }
}

/// Paper has a small amount of give. A press settles the button into its shadow, with no extra
/// movement when Reduce Motion is enabled. Native button semantics and disabled state are kept.
struct PaperPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? Theme.ember : Theme.grey)
                    .overlay {
                        PaperGrainView(tint: .white, opacity: 0.08)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .shadow(color: Theme.ink.opacity(isEnabled ? 0.17 : 0.08),
                            radius: 0, x: 0, y: configuration.isPressed ? 0 : 3)
            }
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct PaperSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(minHeight: 24)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PaperCardSurface(color: configuration.isPressed ? Theme.night : Theme.panel,
                                         cornerRadius: 13))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
