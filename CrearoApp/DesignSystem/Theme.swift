import SwiftUI

// Bright, playful design system. Colour is joy; a clean light canvas with vivid, friendly accents.
// Names are kept stable (night = the background, candle = headline accent, etc.) so views don't
// need rewiring, but the values are now fun and colourful rather than dark.

enum Theme {
    // Vivid, friendly accents
    static let ember  = Color(red: 1.00, green: 0.45, blue: 0.35)   // coral (primary button / streak)
    static let candle = Color(red: 0.58, green: 0.32, blue: 0.86)   // grape (headlines)
    static let moss   = Color(red: 0.27, green: 0.78, blue: 0.47)   // green
    static let magic  = Color(red: 0.60, green: 0.40, blue: 0.96)   // purple
    static let sky    = Color(red: 0.26, green: 0.66, blue: 0.98)   // blue
    static let berry  = Color(red: 1.00, green: 0.42, blue: 0.64)   // pink
    static let sun    = Color(red: 1.00, green: 0.80, blue: 0.28)   // yellow

    // Neutrals
    static let fog  = Color(red: 0.62, green: 0.60, blue: 0.70)
    static let grey = Color(red: 0.52, green: 0.50, blue: 0.60)     // secondary text

    // Surfaces (light & cheerful)
    static let night = Color(red: 0.98, green: 0.97, blue: 1.00)    // page background (light)
    static let panel = Color(red: 0.95, green: 0.94, blue: 1.00)    // cards
    static let ink   = Color(red: 0.16, green: 0.13, blue: 0.26)    // primary text

    // Rounded, friendly type
    static let title   = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let heading = Font.system(.title2, design: .rounded).weight(.bold)
    static let body    = Font.system(.body, design: .rounded)

    /// The full accent rainbow, handy for pixel scenes and variety.
    static let rainbow: [Color] = [ember, sun, moss, sky, magic, berry]
}

/// A soft, cheerful card.
struct HearthCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.magic.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

/// A bright pill used for stats and tags.
struct GlowTag: View {
    let text: String
    var color: Color = Theme.magic
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.18)))
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
            .foregroundStyle(color)
    }
}
