import SwiftUI

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
    var onContinue: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()
    @State private var completed = false
    private let duration: Double = 4.4

    private var sceneTarget: PaperSceneTarget { .from(target) }
    private var invention: PaperInvention { .from(item, action: action) }
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

            ZStack {
                Canvas { context, size in
                    PaperTheatreArt.landscape(PaperTheatreArt.stageContext(context, size: size),
                                              target: sceneTarget)
                }
                TimelineView(.animation(minimumInterval: 1.0 / 60,
                                        paused: completed || reduceMotion || scenePhase != .active)) { timeline in
                    Canvas { context, size in
                        let time = completed || reduceMotion ? duration : max(0, min(duration, timeline.date.timeIntervalSince(start)))
                        draw(PaperTheatreArt.stageContext(context, size: size), time: time)
                    }
                }
                Canvas { context, size in
                    PaperTheatreArt.foreground(PaperTheatreArt.stageContext(context, size: size))
                }
                PaperGrainView(opacity: 0.065)
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Paper theatre: \(item) helps your companion with \(target). \(outcome)")

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
        .task {
            start = Date()
            if reduceMotion { completed = true; return }
            do {
                try await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                completed = true
            } catch {
                // Dismissal cancels the task; it must not update a later presentation.
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { completed = true }
        }
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

    private func draw(_ context: GraphicsContext, time: Double) {
        let appear = eased(time, from: 0.15, to: 0.85)
        let act = eased(time, from: 1.05, to: 2.55)
        let resolve = eased(time, from: 1.8, to: 3.15)
        let settle = eased(time, from: 2.75, to: 3.75)
        let crossing = sceneTarget == .gap && [.build, .fly, .explore, .grow, .solve].contains(action)
        let heroTravel = crossing ? eased(time, from: 2.3, to: 3.85) :
            (action == .give || action == .explore ? act * 0.45 : 0)
        let heroX = 180 + 261 * heroTravel
        let heroY = crossing && action == .fly ? 266 - sin(heroTravel * .pi) * 71 : 267
        let breathe = completed || reduceMotion ? 0 : sin(time * 2) * 1.2

        PaperTheatreArt.target(context, kind: sceneTarget, progress: resolve,
                              center: CGPoint(x: 449, y: 261), scale: 0.9)
        PaperTheatreArt.companion(context, center: CGPoint(x: heroX, y: heroY + breathe),
                                  scale: 0.82, vitality: 0.95, time: time + 1,
                                  celebrate: resolve > 0.8, still: completed || reduceMotion)
        guard appear > 0 else { return }

        let point: CGPoint
        var angle: Double = 0
        var scale = CGFloat(appear) * 0.78
        switch action {
        case .strike:
            // Anticipation first, one clean swing, then a short return to rest.
            let windup = eased(time, from: 0.7, to: 1.05)
            point = CGPoint(x: 264 - 14 * windup + 151 * act - 46 * settle,
                            y: 203 - sin(act * .pi) * 40 + 9 * settle)
            angle = -36 * windup + 75 * act - 22 * settle
        case .build:
            point = CGPoint(x: 330, y: 226 - 5 * settle)
            angle = -9 * (1 - act)
            // Three cut paper parts join the silhouette and then stop moving.
            if act < 1 {
                for index in 0..<3 {
                    let offset = CGFloat(index - 1) * 42 * CGFloat(1 - act)
                    let part = PaperTheatreArt.local(context, at: CGPoint(x: 330 + offset, y: 179 + CGFloat(act * 35)), angle: Double(index - 1) * 20 * (1 - act))
                    PaperTheatreArt.paper(part, PaperTheatreArt.polygon([(-8, -6), (8, -6), (7, 7), (-7, 6)]),
                                          color: color.opacity(1 - act), shadow: 1)
                }
            }
        case .transform:
            point = CGPoint(x: 317 + act * 76, y: 193 - sin(act * .pi) * 28)
            angle = -18 + act * 31
            scale *= 1 + CGFloat(sin(act * .pi)) * 0.18
        case .summon:
            point = CGPoint(x: 327, y: 233 - 41 * appear + 5 * settle)
            angle = -8 * (1 - appear)
        case .fly:
            point = CGPoint(x: 245 + 195 * act, y: 183 - sin(act * .pi) * 52 + 15 * settle)
            angle = -12 + 21 * act - 6 * settle
            PaperTheatreArt.line(context, [(CGFloat(heroX + 24), CGFloat(heroY - 47)), (point.x, point.y + 19)],
                                 color: PaperTheatreArt.earth, width: 1, opacity: 0.65)
        case .grow:
            point = CGPoint(x: 329, y: 231)
            scale *= 0.6 + CGFloat(act) * 0.6
        case .give:
            point = CGPoint(x: 242 + act * 158, y: 211 - sin(act * .pi) * 19 + settle * 11)
            angle = -12 * (1 - act)
        case .solve:
            point = CGPoint(x: 253 + act * 152 - settle * 33, y: 208 - sin(act * .pi) * 10)
            angle = 46 * eased(time, from: 1.75, to: 2.45) - settle * 21
        case .explore:
            point = CGPoint(x: 273 + act * 74, y: 207 - sin(act * .pi) * 14)
            angle = act * 9
        }
        PaperTheatreArt.invention(context, kind: invention, center: point, scale: scale,
                                  color: color, progress: act, angle: angle)
        if !reduceMotion {
            PaperTheatreArt.flourish(context, center: CGPoint(x: 416, y: 153), elapsed: time - 2.8)
        }
    }

    private func eased(_ time: Double, from start: Double, to end: Double) -> Double {
        let value = max(0, min(1, (time - start) / (end - start)))
        return value * value * (3 - 2 * value)
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
