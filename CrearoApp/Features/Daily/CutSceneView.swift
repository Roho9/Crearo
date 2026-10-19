import SwiftUI
import CrearoCore
import SpriteKit

// A finite paper-theatre vignette stages the chosen action and the actual obstacle. Inventions
// map to bounded silhouettes; the caption supplies the detail that a hand-authored stage cannot.
enum SceneAction: String {
    case strike, build, transform, summon, fly, grow, give, solve, explore

    static func from(_ text: String) -> SceneAction {
        SceneAction(rawValue: text.lowercased()) ?? .summon
    }

    var travels: Bool { self == .strike || self == .fly || self == .give }
}

struct CutSceneView: View {
    let item: String
    let colorName: String
    let action: SceneAction
    let target: String
    let outcome: String
    var region: ChallengeRegion = .prism
    var onContinue: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var playback = PaperTheatrePlayback()

    private var completed: Bool { playback.completed }
    private var color: Color { Self.color(colorName) }

    private var sceneContent: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("YOUR IDEA, IN MOTION")
                    .font(.caption.weight(.semibold)).tracking(2)
                    .foregroundStyle(Theme.grey)
                Text(item)
                    .font(Theme.title).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(actionCaption)
                    .font(.subheadline).foregroundStyle(Theme.grey)
                    .multilineTextAlignment(.center)
            }

            Group {
                if playback.sceneUnavailable {
                    // If rasterisation cannot prepare textures (for example under memory
                    // pressure), the authored static stage and score remain available.
                    Canvas { context, size in
                        let context = PaperTheatreArt.stageContext(context, size: size)
                        let kind = PaperSceneTarget.from(target)
                        PaperTheatreArt.landscape(context, target: kind, region: region)
                        PaperTheatreArt.target(context, kind: kind, progress: 1,
                                              center: CGPoint(x: 449, y: 261), scale: 0.9)
                        PaperTheatreArt.companion(context, center: CGPoint(x: 180, y: 267),
                                                  scale: 0.82, vitality: 0.95, time: 1,
                                                  celebrate: true, still: true)
                        PaperTheatreArt.invention(context, kind: .from(item, action: action),
                                                  center: CGPoint(x: 330, y: 211), scale: 0.78, color: color)
                        PaperTheatreArt.foreground(context, region: region)
                    }
                } else {
                    SpriteView(scene: playback.scene,
                               isPaused: scenePhase != .active,
                               preferredFramesPerSecond: completed || reduceMotion ? 30 : 60,
                               options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
                               debugOptions: Self.diagnostics)
                }
            }
            .aspectRatio(600.0 / 320.0, contentMode: .fit)
            .overlay { PaperGrainView(opacity: 0.065).allowsHitTesting(false) }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Paper theatre: \(item) helps your companion with \(target). \(outcome)")
            .accessibilityAction(named: Text("Celebrate with your companion")) { playback.scene.celebrate() }

            if completed && !reduceMotion && !playback.sceneUnavailable {
                Text("Tap the stage to give your companion a cheer.")
                    .font(.caption).foregroundStyle(Theme.grey)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 14) {
                Text(completed || reduceMotion ? outcome : "Your companion puts the idea to work…")
                    .font(Theme.heading).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(completed || reduceMotion ? "See my creativity score" : "Skip to my score", action: onContinue)
                    .buttonStyle(PaperPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 600)
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        ScrollView { sceneContent }
        .background(PaperPageBackground())
        .onAppear {
            playback.start(item: item, color: color, action: action, target: target,
                           region: region, reduceMotion: reduceMotion)
        }
        .onDisappear { playback.stop() }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { playback.finishWithoutMotion() }
        }
    }

    // Enable with the launch argument -PaperTheatreDiagnostics in a Debug build. Production
    // never shows diagnostic UI, while device profiling can inspect FPS, draw and node counts.
    private static var diagnostics: SpriteView.DebugOptions {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PaperTheatreDiagnostics") ?
            [.showsFPS, .showsNodeCount, .showsDrawCount, .showsPhysics] : []
        #else
        []
        #endif
    }

    private var actionCaption: String {
        switch action {
        case .strike: return "A little courage meets \(target)."
        case .build: return "Piece by piece, a new possibility takes shape."
        case .transform: return "An ordinary obstacle becomes something unexpected."
        case .summon: return "A new invention arrives on the paper stage."
        case .fly: return "A new way forward catches the air."
        case .grow: return "A small idea takes root."
        case .give: return "A thoughtful offering changes the scene."
        case .solve: return "Your invention finds a way through."
        case .explore: return "Your companion follows a new possibility."
        }
    }

    static func color(_ name: String) -> Color {
        let name = name.lowercased()
        if name.contains("red") || name.contains("coral") { return Theme.ember }
        if name.contains("orange") { return PaperTheatreArt.clay }
        if name.contains("yellow") || name.contains("gold") || name.contains("sunny") { return Theme.sun }
        if name.contains("green") || name.contains("lime") { return Theme.moss }
        if ["blue", "teal", "cyan", "sky"].contains(where: name.contains) { return Theme.sky }
        if ["purple", "violet", "grape"].contains(where: name.contains) { return Theme.magic }
        if ["pink", "rose", "magenta"].contains(where: name.contains) { return Theme.berry }
        if name.contains("white") || name.contains("silver") { return PaperTheatreArt.cream }
        // Swift's hashValue is randomised across launches. Use a stable palette index instead.
        let seed = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % 997 }
        return Theme.rainbow[seed % Theme.rainbow.count]
    }
}
