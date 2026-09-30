import SwiftUI

/// A few fixed printing flecks and paper fibres. Geometry is generated once, not on every frame.
/// Texture is an overlay, so text and controls can keep their clean, high-contrast surfaces.
struct PaperGrainView: View {
    var tint: Color = Theme.ink
    var opacity: Double = 0.045

    private struct Fibre {
        let x, y, length, tilt: CGFloat
    }

    private static let fibres: [Fibre] = (0..<128).map { index in
        // Stable integer arithmetic keeps the paper identical between launches.
        let a = (index * 73 + 19) % 997
        let b = (index * 191 + 61) % 991
        return Fibre(x: CGFloat(a) / 997, y: CGFloat(b) / 991,
                     length: CGFloat(2 + index % 5), tilt: CGFloat(index % 3 - 1))
    }

    var body: some View {
        Canvas { context, size in
            var fibres = Path()
            for fibre in Self.fibres {
                let point = CGPoint(x: fibre.x * size.width, y: fibre.y * size.height)
                fibres.move(to: point)
                fibres.addLine(to: CGPoint(x: point.x + fibre.length, y: point.y + fibre.tilt))
            }
            context.stroke(fibres, with: .color(tint.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 0.65, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Reusable illustrated stage for the level overview. Only the companion moves; the paper scenery
/// remains still. The preview has no camera shake or constant particle loop.
struct PaperTheatreStageView: View {
    let levelTitle: String
    let vitality: Double
    var celebrate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var target: PaperSceneTarget { .from(levelTitle) }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let context = PaperTheatreArt.stageContext(context, size: size)
                PaperTheatreArt.landscape(context, target: target)
                PaperTheatreArt.target(context, kind: target, progress: celebrate ? 1 : 0,
                                       center: CGPoint(x: 430, y: 260), scale: 0.92)
                PaperTheatreArt.foreground(context)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30,
                                    paused: reduceMotion || scenePhase != .active)) { timeline in
                Canvas { context, size in
                    let context = PaperTheatreArt.stageContext(context, size: size)
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let bob = reduceMotion ? 0 : sin(time * 1.5) * 1.5
                    PaperTheatreArt.companion(context, center: CGPoint(x: 180, y: 268 - bob),
                                              scale: 0.88, vitality: vitality, time: time,
                                              celebrate: celebrate, still: reduceMotion)
                }
            }
            PaperGrainView(opacity: 0.065)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paper theatre. \(levelTitle). Your companion \(celebrate ? "celebrates" : "waits") beside \(target.description).")
    }
}

enum PaperSceneTarget {
    case gap, tree, vines, door, creature, pond, cave, giant, statue, pedestal

    static func from(_ text: String) -> Self {
        let text = text.lowercased()
        // These chapter names don't contain the pictured obstacle. A bridge keeper is the
        // character receiving the invention, rather than the canyon used in the crossing level.
        if ["long list", "color thief", "colour thief", "keeper"].contains(where: text.contains) { return .creature }
        if ["gap", "canyon", "cross", "bridge"].contains(where: text.contains) { return .gap }
        if ["lantern", "tree", "light"].contains(where: text.contains) { return .tree }
        if ["vine", "tangle", "knot"].contains(where: text.contains) { return .vines }
        if ["door", "handle", "open"].contains(where: text.contains) { return .door }
        if ["giant", "sleep"].contains(where: text.contains) { return .giant }
        if ["grumble", "creature", "laugh", "keeper", "trade", "fizzle"].contains(where: text.contains) { return .creature }
        if ["pond", "riddle", "reflection", "water"].contains(where: text.contains) { return .pond }
        if ["echo", "cave", "sentence", "say"].contains(where: text.contains) { return .cave }
        if ["statue", "last bright", "stone"].contains(where: text.contains) { return .statue }
        return .pedestal
    }

    var description: String {
        switch self {
        case .gap: return "a gap between two paper cliffs"
        case .tree: return "a tree hung with little lanterns"
        case .vines: return "a tangled garden"
        case .door: return "three folded doors"
        case .creature: return "a small curious creature"
        case .pond: return "a rippled paper pond"
        case .cave: return "an echoing cave"
        case .giant: return "a sleepy gentle giant"
        case .statue: return "a quiet folded statue"
        case .pedestal: return "a little stage for a new idea"
        }
    }
}

enum PaperInvention {
    case kite, lantern, instrument, seed, vessel, tool, machine, folded

    static func from(_ name: String, action: SceneAction) -> Self {
        let name = name.lowercased()
        if ["wing", "kite", "balloon", "bird", "butterfly", "umbrella", "cloud", "glider"].contains(where: name.contains) { return .kite }
        if ["light", "lamp", "lantern", "star", "sun", "fire", "glow"].contains(where: name.contains) { return .lantern }
        if ["song", "music", "flute", "bell", "voice", "echo", "sound", "whistle", "drum"].contains(where: name.contains) { return .instrument }
        if ["seed", "flower", "plant", "root", "garden", "leaf", "tree"].contains(where: name.contains) { return .seed }
        if ["boat", "bowl", "cup", "basket", "shell", "bucket"].contains(where: name.contains) { return .vessel }
        if ["tool", "comb", "pencil", "key", "brush", "scissor", "needle"].contains(where: name.contains) { return .tool }
        if ["machine", "wheel", "clock", "engine", "robot", "bicycle"].contains(where: name.contains) { return .machine }
        switch action {
        case .fly: return .kite
        case .grow: return .seed
        case .strike, .solve: return .tool
        case .build: return .machine
        default: return .folded
        }
    }
}

/// Manually drawn cut paper silhouettes. All coordinates are in a 600 × 320 stage, with small
/// local coordinate systems for the actors. Strokes imply cut edges and printed registration.
enum PaperTheatreArt {
    static let cream = Color(red: 0.97, green: 0.91, blue: 0.79)
    static let paleSky = Color(red: 0.78, green: 0.84, blue: 0.80)
    static let distantHill = Color(red: 0.64, green: 0.73, blue: 0.64)
    static let middleHill = Color(red: 0.43, green: 0.59, blue: 0.48)
    static let gold = Color(red: 0.90, green: 0.70, blue: 0.34)
    static let clay = Color(red: 0.77, green: 0.47, blue: 0.31)
    static let earth = Color(red: 0.62, green: 0.43, blue: 0.31)

    static func stageContext(_ context: GraphicsContext, size: CGSize) -> GraphicsContext {
        var context = context
        context.scaleBy(x: size.width / 600, y: size.height / 320)
        return context
    }

    static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
            path.closeSubpath()
        }
    }

    static func paper(_ context: GraphicsContext, _ path: Path, color: Color,
                      shadow: CGFloat = 2, edge: Bool = true) {
        if shadow > 0 {
            context.fill(path.applying(CGAffineTransform(translationX: shadow, y: shadow + 1)),
                         with: .color(Theme.ink.opacity(0.12)))
        }
        context.fill(path, with: .color(color))
        if edge {
            context.stroke(path, with: .color(Theme.ink.opacity(0.19)),
                           style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        }
    }

    static func line(_ context: GraphicsContext, _ points: [(CGFloat, CGFloat)],
                     color: Color = Theme.ink, width: CGFloat = 1.5, opacity: Double = 0.6) {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { path.move(to: CGPoint(x: point.0, y: point.1)) }
            else { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
        }
        context.stroke(path, with: .color(color.opacity(opacity)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    static func local(_ context: GraphicsContext, at center: CGPoint, scale: CGFloat = 1,
                      angle: Double = 0) -> GraphicsContext {
        var context = context
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: .degrees(angle))
        context.scaleBy(x: scale, y: scale)
        return context
    }

    static func landscape(_ context: GraphicsContext, target: PaperSceneTarget) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 600, height: 320)), with: .color(cream))
        paper(context, polygon([(0, 0), (600, 0), (600, 221), (0, 223)]),
              color: paleSky, shadow: 0, edge: false)
        // A sun printed slightly off its ring gives a little handmade imperfection.
        context.stroke(Path(ellipseIn: CGRect(x: 58, y: 27, width: 62, height: 62)),
                       with: .color(clay.opacity(0.35)), lineWidth: 1)
        paper(context, Path(ellipseIn: CGRect(x: 61, y: 25, width: 59, height: 59)),
              color: gold, shadow: 0, edge: false)
        cloud(context, center: CGPoint(x: 255, y: 60), scale: 0.85)
        cloud(context, center: CGPoint(x: 521, y: 95), scale: 0.55)

        var hills = Path()
        hills.move(to: CGPoint(x: -10, y: 214))
        hills.addCurve(to: CGPoint(x: 241, y: 193), control1: CGPoint(x: 82, y: 110), control2: CGPoint(x: 155, y: 136))
        hills.addCurve(to: CGPoint(x: 609, y: 166), control1: CGPoint(x: 359, y: 98), control2: CGPoint(x: 467, y: 183))
        hills.addLine(to: CGPoint(x: 609, y: 321)); hills.addLine(to: CGPoint(x: -10, y: 321)); hills.closeSubpath()
        paper(context, hills, color: distantHill, shadow: 2)
        let middle = polygon([(-10, 239), (52, 214), (98, 219), (154, 201), (205, 219),
                              (264, 210), (326, 228), (405, 200), (479, 217), (533, 201), (610, 210), (610, 322), (-10, 322)])
        paper(context, middle, color: middleHill, shadow: 3)
        paper(context, polygon([(-10, 277), (88, 250), (146, 264), (230, 248),
                                (334, 260), (424, 244), (512, 260), (610, 248), (610, 321), (-10, 321)]),
              color: cream, shadow: 3)
        // Tapered path recedes into the hill, rather than a horizontal game-platform stripe.
        paper(context, polygon([(239, 320), (400, 320), (333, 281), (321, 251),
                                (281, 218), (291, 252), (302, 284)]), color: clay.opacity(0.35), shadow: 0, edge: false)
        if target != .tree { sapling(context, center: CGPoint(x: 56, y: 253), scale: 0.70) }
        if target == .gap {
            paper(context, polygon([(243, 255), (267, 249), (267, 272), (281, 294), (290, 320),
                                    (411, 320), (414, 290), (435, 266), (442, 251), (460, 262), (439, 320), (243, 320)]),
                  color: earth, shadow: 0)
            paper(context, polygon([(278, 263), (303, 268), (388, 261), (420, 254), (403, 320), (306, 320)]),
                  color: Theme.ink.opacity(0.72), shadow: 0, edge: false)
            line(context, [(278, 280), (289, 291), (295, 307)], color: cream, opacity: 0.25)
            line(context, [(414, 276), (402, 291), (400, 308)], color: cream, opacity: 0.25)
        }
        // Quiet registration marks in the scenery reward a closer look.
        for index in 0..<7 {
            let x = CGFloat(26 + index * 79)
            line(context, [(x, 303), (x + 4, 295), (x + 7, 302)], color: middleHill, width: 1, opacity: 0.35)
        }
    }

    static func cloud(_ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        let context = local(context, at: center, scale: scale)
        var path = Path()
        path.move(to: CGPoint(x: -46, y: 13))
        path.addCurve(to: CGPoint(x: -18, y: -11), control1: CGPoint(x: -57, y: -6), control2: CGPoint(x: -32, y: -17))
        path.addCurve(to: CGPoint(x: 19, y: -16), control1: CGPoint(x: -15, y: -33), control2: CGPoint(x: 16, y: -37))
        path.addCurve(to: CGPoint(x: 47, y: 11), control1: CGPoint(x: 43, y: -23), control2: CGPoint(x: 61, y: 1))
        path.addLine(to: CGPoint(x: -46, y: 13)); path.closeSubpath()
        paper(context, path, color: cream.opacity(0.95), shadow: 2)
        line(context, [(-27, 3), (-3, 3)], color: earth, width: 0.8, opacity: 0.18)
    }

    static func foreground(_ context: GraphicsContext) {
        paper(context, polygon([(-5, 307), (29, 293), (55, 302), (79, 298), (114, 321), (-5, 321)]),
              color: Theme.moss, shadow: 0)
        paper(context, polygon([(492, 320), (529, 298), (551, 303), (574, 291), (607, 302), (607, 321)]),
              color: middleHill, shadow: 0)
        for (x, y) in [(CGFloat(47), CGFloat(290)), (566, 283)] {
            line(context, [(x, y + 20), (x + 1, y)], color: earth, width: 1.4)
            paper(context, polygon([(x + 1, y + 7), (x - 9, y + 1), (x - 12, y + 9), (x, y + 13)]), color: Theme.moss, shadow: 0)
            paper(context, polygon([(x + 1, y + 4), (x + 10, y - 2), (x + 13, y + 5), (x + 2, y + 10)]), color: gold, shadow: 0)
        }
    }

    static func companion(_ context: GraphicsContext, center: CGPoint, scale: CGFloat,
                          vitality: Double, time: Double, celebrate: Bool, still: Bool = false) {
        let context = local(context, at: center, scale: scale)
        let vitality = max(0, min(1, vitality))
        let bodyColor = Color(red: 0.83 + 0.12 * vitality, green: 0.77 + 0.08 * vitality, blue: 0.65 + 0.02 * vitality)
        let wingAngle = still ? 0 : sin(time * 1.5) * 2.5
        context.fill(Path(ellipseIn: CGRect(x: -48, y: -4, width: 105, height: 13)), with: .color(earth.opacity(0.18)))
        let wing = local(context, at: CGPoint(x: 19, y: -65), angle: wingAngle - (celebrate ? 9 : 0))
        paper(wing, polygon([(0, 0), (65, -63), (58, -5), (42, 21), (9, 31)]), color: Theme.moss, shadow: 3)
        paper(wing, polygon([(0, 0), (65, -63), (26, -5)]), color: middleHill, shadow: 0)
        line(wing, [(65, -63), (26, -5), (9, 31)], color: cream, width: 1, opacity: 0.40)
        // Two unequal ribbon ears and a small folded foot make a recognisable silhouette.
        paper(context, polygon([(-24, -109), (-28, -152), (-13, -162), (-2, -139), (-7, -110)]), color: bodyColor, shadow: 2)
        paper(context, polygon([(12, -113), (31, -142), (48, -132), (26, -102)]), color: Theme.ember, shadow: 2)
        line(context, [(-21, -147), (-13, -118)], color: earth, width: 1, opacity: 0.4)
        paper(context, polygon([(-29, -16), (-36, 0), (-11, 2), (-6, -15)]), color: earth, shadow: 1)
        paper(context, polygon([(15, -16), (12, 0), (35, 1), (31, -15)]), color: earth, shadow: 1)
        var body = Path()
        body.move(to: CGPoint(x: -37, y: -86))
        body.addCurve(to: CGPoint(x: 10, y: -121), control1: CGPoint(x: -43, y: -115), control2: CGPoint(x: -12, y: -127))
        body.addCurve(to: CGPoint(x: 44, y: -83), control1: CGPoint(x: 40, y: -121), control2: CGPoint(x: 46, y: -102))
        body.addCurve(to: CGPoint(x: 43, y: -26), control1: CGPoint(x: 43, y: -63), control2: CGPoint(x: 57, y: -43))
        body.addCurve(to: CGPoint(x: -37, y: -23), control1: CGPoint(x: 30, y: -7), control2: CGPoint(x: -31, y: -8))
        body.addCurve(to: CGPoint(x: -37, y: -86), control1: CGPoint(x: -57, y: -41), control2: CGPoint(x: -42, y: -68))
        body.closeSubpath()
        paper(context, body, color: bodyColor, shadow: 3)
        paper(context, polygon([(-35, -67), (42, -71), (44, -58), (-36, -53)]), color: Theme.ember, shadow: 1)
        paper(context, polygon([(22, -60), (41, -62), (50, -35), (34, -31)]), color: clay, shadow: 1)
        line(context, [(-23, -48), (-9, -35), (19, -34)], color: earth, width: 0.9, opacity: 0.28)
        line(context, [(20, -27), (30, -24)], color: earth, width: 0.8, opacity: 0.3)
        let arm = local(context, at: CGPoint(x: -35, y: -58), angle: celebrate ? 28 : -9)
        paper(arm, polygon([(0, 0), (-29, -8), (-34, 1), (-24, 8), (2, 11)]), color: bodyColor, shadow: 2)
        let blink = !still && time.truncatingRemainder(dividingBy: 6.4) < 0.12
        if blink || celebrate {
            line(context, [(-21, -87), (-16, -91), (-10, -86)], width: 2.4, opacity: 0.9)
            line(context, [(10, -86), (15, -90), (21, -86)], width: 2.4, opacity: 0.9)
        } else {
            context.fill(Path(ellipseIn: CGRect(x: -20, y: -92, width: 5.5, height: 8)), with: .color(Theme.ink))
            context.fill(Path(ellipseIn: CGRect(x: 12, y: -91, width: 5, height: 7.5)), with: .color(Theme.ink))
        }
        context.fill(Path(ellipseIn: CGRect(x: -30, y: -82, width: 12, height: 6)), with: .color(clay.opacity(0.35)))
        context.fill(Path(ellipseIn: CGRect(x: 20, y: -80, width: 11, height: 5)), with: .color(clay.opacity(0.35)))
        var smile = Path()
        smile.move(to: CGPoint(x: -6, y: -79))
        smile.addQuadCurve(to: CGPoint(x: 9, y: -79), control: CGPoint(x: 1, y: celebrate ? -66 : -73))
        context.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
    }

    static func sapling(_ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        let context = local(context, at: center, scale: scale)
        paper(context, polygon([(-6, 0), (-9, -69), (2, -103), (9, -64), (6, 0)]), color: earth)
        paper(context, polygon([(-7, -47), (-39, -70), (-51, -101), (-20, -90), (2, -57)]), color: middleHill)
        paper(context, polygon([(0, -67), (15, -111), (45, -119), (40, -88), (9, -53)]), color: Theme.moss)
        line(context, [(-7, -47), (-36, -87)], color: cream, width: 1, opacity: 0.3)
        line(context, [(4, -64), (32, -101)], color: cream, width: 1, opacity: 0.3)
    }

    static func target(_ context: GraphicsContext, kind: PaperSceneTarget, progress: Double,
                       center: CGPoint, scale: CGFloat = 1) {
        let context = local(context, at: center, scale: scale)
        let progress = CGFloat(max(0, min(1, progress)))
        switch kind {
        case .gap:
            // The bridge assembles from individual paper planks, never a generic particle burst.
            if progress > 0 {
                let bridge = local(context, at: CGPoint(x: -87, y: 5), scale: progress)
                line(bridge, [(-105, -28), (-65, -17), (0, -12), (62, -21)], color: earth, width: 3)
                line(bridge, [(-105, -4), (-65, 6), (0, 10), (62, 1)], color: earth, width: 3)
                for index in 0..<10 {
                    let x = CGFloat(index) * 17 - 104
                    let y = CGFloat(sin(Double(index) / 9 * .pi)) * 8
                    paper(bridge, polygon([(x, -7 + y), (x + 14, -6 + y), (x + 14, 8 + y), (x - 1, 7 + y)]), color: cream, shadow: 1)
                }
            }
        case .tree:
            paper(context, polygon([(-11, 0), (-16, -91), (-34, -137), (-24, -141), (-5, -110),
                                    (0, -171), (12, -174), (13, -116), (41, -145), (49, -137), (17, -91), (12, 0)]), color: earth)
            for (x, y, width, height) in [(CGFloat(-57), CGFloat(-160), CGFloat(63), CGFloat(63)), (4, -183, 67, 66), (29, -124, 56, 49), (-74, -106, 61, 49)] {
                paper(context, Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)), color: middleHill)
            }
            let lanterns: [(CGFloat, CGFloat)] = [(-47, -104), (-12, -132), (25, -156), (57, -85), (-38, -52)]
            for (x, y) in lanterns {
                line(context, [(x, y - 13), (x, y)], width: 1, opacity: 0.6)
                if progress > 0 {
                    context.fill(Path(ellipseIn: CGRect(x: x - 20, y: y - 10, width: 41, height: 39)), with: .color(gold.opacity(Double(progress) * 0.22)))
                }
                paper(context, polygon([(x - 7, y), (x + 7, y - 2), (x + 10, y + 12), (x, y + 18), (x - 9, y + 12)]),
                      color: progress > 0.4 ? gold : cream, shadow: 1)
                line(context, [(x, y + 2), (x, y + 13)], color: earth, width: 0.7, opacity: 0.45)
            }
        case .vines:
            for index in 0..<4 {
                let x = CGFloat(index * 28 - 48)
                var vine = Path()
                vine.move(to: CGPoint(x: x, y: 0))
                vine.addCurve(to: CGPoint(x: x + 8, y: -122),
                              control1: CGPoint(x: x - 45 * (1 - progress), y: -52),
                              control2: CGPoint(x: x + 49 * (1 - progress), y: -102))
                context.stroke(vine, with: .color(index.isMultiple(of: 2) ? Theme.moss : middleHill),
                               style: StrokeStyle(lineWidth: 8, lineCap: .round))
                for leaf in 0..<3 {
                    let y = CGFloat(-23 - leaf * 33)
                    paper(context, polygon([(x, y), (x - 24, y - 19), (x - 26, y - 4), (x + 2, y + 7)]), color: middleHill, shadow: 1)
                }
            }
            if progress > 0.5 {
                for index in 0..<4 {
                    let y = CGFloat(-20 - index * 25)
                    line(context, [(-48, y), (43, y - 3)], color: cream, width: 5, opacity: Double(progress))
                }
            }
        case .door:
            for index in 0..<3 {
                let x = CGFloat(index * 43 - 64)
                paper(context, polygon([(x, 0), (x, -100), (x + 9, -114), (x + 25, -114), (x + 35, -100), (x + 35, 0)]), color: earth, shadow: 2)
                let opening = index == 1 ? progress : 0
                paper(context, polygon([(x + 4, -3), (x + 4 + 14 * opening, -99 + 7 * opening),
                                        (x + 29, -99), (x + 30, -3)]), color: index == 1 ? Theme.ember : clay, shadow: 1)
                if index == 1, progress > 0.1 {
                    paper(context, polygon([(x + 4, -3), (x + 4, -101), (x - 20 * progress, -91), (x - 20 * progress, 7)]), color: Theme.ember, shadow: 2)
                }
                line(context, [(x + 11, -87), (x + 11, -15)], color: cream, width: 0.7, opacity: 0.25)
            }
        case .creature, .giant:
            let creature = local(context, at: .zero, scale: kind == .giant ? 1.22 : 0.9,
                                 angle: kind == .giant ? Double(-7 * (1 - progress)) : 0)
            context.fill(Path(ellipseIn: CGRect(x: -53, y: -4, width: 109, height: 11)), with: .color(earth.opacity(0.16)))
            paper(creature, polygon([(-41, -9), (-50, -49), (-38, -83), (-43, -111), (-17, -100),
                                     (5, -107), (33, -101), (48, -118), (51, -88), (63, -58), (53, -10), (20, -1), (-13, 0)]),
                  color: kind == .giant ? clay : Theme.magic)
            paper(creature, polygon([(-43, -12), (-57, -3), (-30, 2), (-20, -6)]), color: earth, shadow: 1)
            paper(creature, polygon([(28, -7), (30, 3), (61, 1), (51, -12)]), color: earth, shadow: 1)
            if progress > 0.35 {
                line(creature, [(-24, -57), (-18, -62), (-12, -56)], width: 2.2, opacity: 0.9)
                line(creature, [(15, -55), (21, -61), (27, -55)], width: 2.2, opacity: 0.9)
            } else {
                line(creature, [(-27, -66), (-13, -61)], width: 2.1, opacity: 0.9)
                line(creature, [(15, -62), (29, -68)], width: 2.1, opacity: 0.9)
                if kind != .giant {
                    creature.fill(Path(ellipseIn: CGRect(x: -22, y: -54, width: 5, height: 6)), with: .color(Theme.ink))
                    creature.fill(Path(ellipseIn: CGRect(x: 17, y: -53, width: 5, height: 6)), with: .color(Theme.ink))
                }
            }
            var mouth = Path()
            mouth.move(to: CGPoint(x: -9, y: -39))
            mouth.addQuadCurve(to: CGPoint(x: 12, y: -38), control: CGPoint(x: 2, y: -42 + 22 * progress))
            creature.stroke(mouth, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            paper(creature, polygon([(-30, -28), (-18, -19), (-23, -13), (-35, -21)]), color: cream.opacity(0.25), shadow: 0, edge: false)
        case .pond:
            paper(context, Path(ellipseIn: CGRect(x: -89, y: -29, width: 179, height: 57)), color: earth, shadow: 2)
            paper(context, Path(ellipseIn: CGRect(x: -79, y: -26, width: 157, height: 46)), color: Theme.sky, shadow: 0)
            for index in 0..<3 {
                let inset = CGFloat(index * 17)
                context.stroke(Path(ellipseIn: CGRect(x: -59 + inset, y: -17 + inset / 4, width: 113 - inset * 2, height: 23 - inset / 2)),
                               with: .color(cream.opacity(0.55 + Double(progress) * 0.3)), lineWidth: 1.2)
            }
            paper(context, polygon([(48, -14), (55, -20), (63, -13), (54, -10)]), color: Theme.moss, shadow: 0)
        case .cave:
            paper(context, polygon([(-77, 0), (-71, -100), (-34, -154), (27, -148), (72, -90), (77, 0)]), color: earth, shadow: 4)
            paper(context, polygon([(-49, 0), (-43, -67), (-22, -98), (19, -91), (42, -52), (47, 0)]), color: Theme.ink, shadow: 0)
            line(context, [(-62, -84), (-28, -128), (-2, -134)], color: cream, width: 1, opacity: 0.35)
            if progress > 0 {
                for index in 0..<3 {
                    var wave = Path()
                    let x = CGFloat(-19 + index * 14)
                    wave.move(to: CGPoint(x: x, y: -56))
                    wave.addQuadCurve(to: CGPoint(x: x, y: -21), control: CGPoint(x: x + 15, y: -36))
                    context.stroke(wave, with: .color(gold.opacity(Double(progress))), lineWidth: 2)
                }
            }
        case .statue:
            paper(context, polygon([(-43, 0), (-39, -16), (41, -17), (47, 0)]), color: earth)
            companion(context, center: CGPoint(x: 0, y: -18), scale: 0.72,
                      vitality: Double(progress), time: 1, celebrate: progress > 0.5, still: true)
        case .pedestal:
            paper(context, polygon([(-44, 0), (-36, -27), (33, -31), (47, -1)]), color: earth)
            paper(context, polygon([(-45, -29), (-37, -39), (35, -41), (44, -29), (8, -21)]), color: cream)
            let growth = CGFloat(0.45 + progress * 0.65)
            invention(context, kind: .seed, center: CGPoint(x: 0, y: -43), scale: growth, color: Theme.moss, progress: Double(progress))
        }
    }

    static func invention(_ context: GraphicsContext, kind: PaperInvention, center: CGPoint,
                          scale: CGFloat, color: Color, progress: Double = 1, angle: Double = 0) {
        let context = local(context, at: center, scale: scale, angle: angle)
        switch kind {
        case .kite:
            paper(context, polygon([(-51, -12), (-7, -49), (51, -9), (5, 34)]), color: color)
            paper(context, polygon([(-7, -49), (-5, -8), (-51, -12)]), color: cream, shadow: 0)
            paper(context, polygon([(-5, -8), (51, -9), (5, 34)]), color: color.opacity(0.62), shadow: 0)
            line(context, [(-7, -49), (-5, -8), (5, 34)], width: 0.8, opacity: 0.4)
            line(context, [(-5, -8), (5, 34), (-1, 52), (12, 68)], color: earth, width: 1)
            paper(context, polygon([(-1, 43), (-14, 42), (-8, 54), (6, 49), (17, 56), (18, 44)]), color: Theme.ember, shadow: 1)
        case .lantern:
            var handle = Path()
            handle.addArc(center: CGPoint(x: 0, y: -28), radius: 15, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(handle, with: .color(earth), lineWidth: 2.5)
            paper(context, polygon([(-27, -28), (23, -32), (31, 17), (7, 37), (-25, 22)]), color: color)
            paper(context, polygon([(-11, -25), (5, -27), (10, 27), (-7, 24)]), color: cream, shadow: 0)
            line(context, [(-24, -19), (26, -22)], width: 1, opacity: 0.35)
            line(context, [(-22, 15), (29, 11)], width: 1, opacity: 0.35)
        case .instrument:
            paper(context, polygon([(-43, 18), (35, -19), (45, -9), (-34, 31)]), color: color)
            for index in 0..<4 {
                context.fill(Path(ellipseIn: CGRect(x: CGFloat(-24 + index * 15), y: CGFloat(14 - index * 7), width: 5, height: 5)), with: .color(Theme.ink.opacity(0.75)))
            }
            for index in 0..<3 {
                let x = CGFloat(-16 + index * 22), y = CGFloat(-20 - (index % 2) * 14)
                line(context, [(x, y), (x, y - 17), (x + 8, y - 15)], color: color, width: 2, opacity: 0.9)
                context.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 2, width: 8, height: 5)), with: .color(color))
            }
        case .seed:
            let height = CGFloat(0.6 + max(0, min(1, progress)) * 0.4)
            let stem = local(context, at: .zero, scale: height)
            line(stem, [(0, 26), (-4, -6), (1, -36)], color: earth, width: 3, opacity: 0.9)
            paper(stem, polygon([(-4, 2), (-35, -15), (-33, -31), (-11, -22), (0, -2)]), color: color)
            paper(stem, polygon([(-3, -11), (13, -42), (36, -38), (23, -18)]), color: Theme.moss)
            paper(context, polygon([(-21, 21), (-3, 14), (22, 19), (15, 34), (-14, 35)]), color: clay)
            line(stem, [(2, -14), (26, -33)], color: cream, width: 1, opacity: 0.4)
        case .vessel:
            paper(context, polygon([(-52, -5), (-13, -23), (40, -17), (55, -4), (31, 24), (-30, 24)]), color: color)
            paper(context, polygon([(-52, -5), (-9, 3), (55, -4), (40, -17), (-13, -23)]), color: cream, shadow: 0)
            paper(context, polygon([(-13, -23), (-9, 3), (-33, -5)]), color: clay, shadow: 0)
            line(context, [(-23, 18), (25, 18)], color: cream, width: 1, opacity: 0.45)
        case .tool:
            paper(context, polygon([(-30, 29), (-40, 20), (11, -27), (17, -22)]), color: earth)
            paper(context, polygon([(7, -24), (4, -41), (15, -55), (36, -46), (29, -29), (16, -19)]), color: color)
            paper(context, polygon([(15, -55), (17, -36), (36, -46)]), color: cream, shadow: 0)
            line(context, [(-28, 20), (-14, 6)], color: cream, width: 1, opacity: 0.4)
        case .machine:
            paper(context, polygon([(-38, -27), (25, -32), (39, 13), (-35, 18)]), color: color)
            paper(context, polygon([(-38, -27), (-22, -41), (35, -42), (25, -32)]), color: cream, shadow: 1)
            for x in [CGFloat(-22), 24] {
                paper(context, Path(ellipseIn: CGRect(x: x - 12, y: 11, width: 25, height: 25)), color: earth, shadow: 1)
                context.fill(Path(ellipseIn: CGRect(x: x - 4, y: 19, width: 8, height: 8)), with: .color(cream))
            }
            paper(context, Path(ellipseIn: CGRect(x: -13, y: -17, width: 24, height: 24)), color: cream, shadow: 1)
            line(context, [(0, -13), (0, 3), (-8, -5), (8, -5)], color: earth, width: 1)
            line(context, [(25, -32), (31, -62), (43, -68)], width: 2)
            paper(context, polygon([(39, -70), (55, -78), (54, -63), (43, -63)]), color: gold, shadow: 1)
        case .folded:
            // An open-ended sculptural invention has folded wings, a stem and an asymmetric sail.
            paper(context, polygon([(-45, 9), (-19, -20), (0, -12), (31, -44), (47, -12), (18, 8), (4, 34)]), color: color)
            paper(context, polygon([(0, -12), (31, -44), (18, 8)]), color: cream, shadow: 0)
            paper(context, polygon([(-45, 9), (0, -12), (4, 34)]), color: color.opacity(0.55), shadow: 0)
            line(context, [(31, -44), (18, 8), (4, 34), (-7, 51)], color: earth, width: 1.2)
            paper(context, polygon([(-20, 48), (-7, 43), (6, 50), (-8, 55)]), color: earth, shadow: 1)
        }
    }

    /// Eight finite paper scraps settle within the stage, for a restrained final flourish.
    static func flourish(_ context: GraphicsContext, center: CGPoint, elapsed: Double) {
        guard elapsed >= 0, elapsed < 1.3 else { return }
        let fade = max(0, 1 - elapsed / 1.3)
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let distance = 13 + elapsed * Double(33 + index % 3 * 12)
            let point = CGPoint(x: center.x + cos(angle) * distance,
                                y: center.y - 32 + sin(angle) * distance + 31 * elapsed * elapsed)
            let scrap = local(context, at: point, angle: Double(index * 24) + elapsed * 70)
            paper(scrap, polygon([(-4, -2), (3, -4), (5, 3), (-2, 4)]),
                  color: Theme.rainbow[index % Theme.rainbow.count].opacity(fade), shadow: 0, edge: false)
        }
    }
}
