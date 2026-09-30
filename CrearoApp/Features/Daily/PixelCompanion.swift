import SwiftUI

/// The existing entry point now draws Crearo's folded-paper courier. The little scarf, unequal
/// ribbon ears and hinged leaf wing make it recognisable at a glance without a raster asset.
struct PixelCompanion: View {
    var vitality: Double = 0.5
    var celebrate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30,
                                    paused: reduceMotion || scenePhase != .active)) { timeline in
                Canvas { context, size in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let scale = min(size.height / 184, size.width / 175)
                    let bob = reduceMotion ? 0 : sin(time * 1.5) * 1.8 * scale
                    PaperTheatreArt.companion(context,
                                              center: CGPoint(x: size.width / 2, y: size.height * 0.94 - bob),
                                              scale: scale, vitality: vitality, time: time,
                                              celebrate: celebrate, still: reduceMotion)
                }
            }
            PaperGrainView(opacity: 0.035)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(celebrate ? "Your paper companion is smiling and celebrating" : "Your friendly paper companion")
    }
}
