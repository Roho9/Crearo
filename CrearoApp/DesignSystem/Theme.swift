import SwiftUI

// The art-direction "color = creativity, grey = the enemy" rule, expressed as a tiny design system
// (GDD §7–8). Warm pools of light carved out of desaturated fog.

enum Theme {
    // Warm, alive
    static let ember = Color(red: 0.95, green: 0.55, blue: 0.25)
    static let candle = Color(red: 0.98, green: 0.83, blue: 0.55)
    static let moss = Color(red: 0.45, green: 0.62, blue: 0.42)
    static let magic = Color(red: 0.50, green: 0.45, blue: 0.85)

    // The Grey (the anti-creative force)
    static let fog = Color(red: 0.30, green: 0.32, blue: 0.36)
    static let grey = Color(red: 0.46, green: 0.47, blue: 0.50)

    // Surfaces
    static let night = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let panel = Color(red: 0.15, green: 0.16, blue: 0.20)
    static let ink = Color(red: 0.86, green: 0.86, blue: 0.90)

    static let title = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let heading = Font.system(.title2, design: .serif).weight(.semibold)
    static let body = Font.system(.body, design: .serif)
}

/// A warm, candlelit card.
struct HearthCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.ember.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

/// A glowing pill used for resources, marks, and tags.
struct GlowTag: View {
    let text: String
    var color: Color = Theme.candle
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.16)))
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
            .foregroundStyle(color)
    }
}
