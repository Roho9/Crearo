import SwiftUI

/// Oddworks uses printed signage and saturated architectural colour, rather than paper cards.
enum AtelierStyle {
    static let ink = Color(red: 0.055, green: 0.06, blue: 0.10)
    static let surface = Color(red: 0.095, green: 0.10, blue: 0.16)
    static let chalk = Color(red: 0.95, green: 0.94, blue: 1)
    static let muted = Color(red: 0.68, green: 0.69, blue: 0.78)
    static let acid = Color(red: 0.89, green: 1, blue: 0.34)
    static let coral = Color(red: 1, green: 0.45, blue: 0.36)
    static let cobalt = Color(red: 0.27, green: 0.25, blue: 0.96)
    static let lilac = Color(red: 0.72, green: 0.65, blue: 0.94)
    static let line = Color.white.opacity(0.16)

    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default).width(.condensed)
    }
    static let caption = Font.system(.caption, design: .monospaced).weight(.medium)
}

struct AtelierActionStyle: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 18)
            .foregroundStyle(secondary ? AtelierStyle.chalk : AtelierStyle.ink)
            .background(secondary ? AtelierStyle.surface : enabled ? AtelierStyle.acid : AtelierStyle.muted)
            .overlay { Rectangle().strokeBorder(secondary ? AtelierStyle.line : .clear, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.78 : enabled ? 1 : 0.62)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AtelierRule: View {
    var body: some View { Rectangle().fill(AtelierStyle.line).frame(height: 1).accessibilityHidden(true) }
}
