import SwiftUI

// Touch controls over the world: a virtual joystick to move, and a contextual action button
// (Chop / Fight) that appears when you're near something. Plus a 2D weather overlay (rain/fog).

struct WorldControls: View {
    @ObservedObject var controller: WorldController

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Joystick { controller.moveInput = $0 }
                Spacer()
                if let action = controller.nearbyAction {
                    Button { controller.interact() } label: {
                        VStack(spacing: 3) {
                            Image(systemName: action.icon).font(.system(size: 22, weight: .bold))
                            Text(action.label).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.night)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(action == .fight ? Color(red: 0.85, green: 0.42, blue: 0.36) : Theme.ember))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: controller.nearbyAction)
    }
}

private struct Joystick: View {
    var onChange: (SIMD2<Float>) -> Void
    @State private var thumb: CGSize = .zero
    private let radius: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(Theme.panel.opacity(0.5))
                .overlay(Circle().strokeBorder(Theme.ember.opacity(0.3), lineWidth: 1))
            Circle().fill(Theme.candle.opacity(0.9)).frame(width: 50, height: 50).offset(thumb)
        }
        .frame(width: radius * 2, height: radius * 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    var t = g.translation
                    let len = sqrt(t.width * t.width + t.height * t.height)
                    if len > radius { t.width = t.width / len * radius; t.height = t.height / len * radius }
                    thumb = t
                    onChange(SIMD2(Float(t.width / radius), Float(t.height / radius)))
                }
                .onEnded { _ in thumb = .zero; onChange(.zero) }
        )
    }
}

struct WeatherOverlay: View {
    let weather: Weather
    var body: some View {
        ZStack {
            if weather == .fog {
                LinearGradient(colors: [.clear, Color(white: 0.8).opacity(0.30)], startPoint: .top, endPoint: .bottom)
            }
            if weather == .rain { RainView() }
        }
    }
}

private struct RainView: View {
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                var rng = SeededRandom(seed: 7)
                for _ in 0..<90 {
                    let x = rng.next() * size.width
                    let speed = 320 + rng.next() * 260
                    let len = 12 + rng.next() * 10
                    let y = (CGFloat(t) * speed + rng.next() * size.height)
                        .truncatingRemainder(dividingBy: size.height + 40) - 20
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - 2, y: y + len))
                    ctx.stroke(p, with: .color(.white.opacity(0.22)), lineWidth: 1)
                }
            }
        }
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return CGFloat(state % 10000) / 10000
    }
}
