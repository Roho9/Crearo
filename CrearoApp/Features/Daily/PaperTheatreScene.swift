import SwiftUI
import SpriteKit
import Observation
import CrearoCore

/// SwiftUI owns this bridge for the presentation's lifetime. SpriteKit completes the vignette
/// in scene time, so backgrounding cannot make the score button race ahead of the action.
@MainActor @Observable
final class PaperTheatrePlayback {
    let scene = PaperTheatreScene()
    var completed = false
    var sceneUnavailable = false
    private var hasStarted = false

    func start(item: String, color: Color, action: SceneAction, target: String,
               region: ChallengeRegion, reduceMotion: Bool) {
        guard !hasStarted else { return }
        hasStarted = true
        scene.playback = self
        scene.stage(item: item, color: color, action: action, target: target,
                    region: region, reduceMotion: reduceMotion || completed)
    }

    func finishWithoutMotion() {
        scene.showFinalState()
        completed = true
    }

    func stop() {
        scene.tearDown()
        hasStarted = false
    }
}

/// A fixed paper stage uses aspectFit: a wider window never stretches the artwork or hides
/// the obstacle. The native SwiftUI controls and accessible narration stay outside the scene.
@MainActor
final class PaperTheatreScene: SKScene {
    private enum Layer {
        static let scenery: CGFloat = 0
        static let obstacle: CGFloat = 10
        static let companion: CGFloat = 20
        static let invention: CGFloat = 30
        static let scraps: CGFloat = 40
        static let foreground: CGFloat = 50
    }
    private enum PhysicsCategory {
        static let none: UInt32 = 0
        static let scrap: UInt32 = 1 << 0
        static let ground: UInt32 = 1 << 1
    }
    private enum ActionKey {
        static let vignette = "paper.vignette"
        static let reaction = "paper.reaction"
        static let resolve = "paper.resolve"
        static let fade = "paper.fade"
    }

    weak var playback: PaperTheatrePlayback?
    private let world = SKNode()
    private let stageCamera = SKCameraNode()
    private var companion = SKSpriteNode()
    private var obstacle = SKSpriteNode()
    private var invention = SKSpriteNode()
    private var textures: PaperTheatreTextures?
    private var action: SceneAction = .summon
    private var target: PaperSceneTarget = .pedestal
    private var reducedMotion = false
    private var isStaged = false
    private var isResolved = false
    private var availableScraps: [SKSpriteNode] = []
    private var activeScraps: [(node: SKSpriteNode, expiry: TimeInterval)] = []
    private var lastUpdateTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var lastInteraction: TimeInterval = -1
    private var stageID = UUID()

    override init() {
        super.init(size: CGSize(width: 600, height: 320))
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.97, green: 0.91, blue: 0.79, alpha: 1)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("PaperTheatreScene is created in code") }

    func stage(item: String, color: Color, action: SceneAction, target: String,
               region: ChallengeRegion, reduceMotion: Bool) {
        tearDown()
        self.action = action
        self.target = .from(target)
        reducedMotion = reduceMotion
        isStaged = true
        isResolved = false
        elapsed = 0
        lastUpdateTime = 0
        lastInteraction = -1
        textures = PaperTheatreTextures.make(item: item, color: color, action: action,
                                             target: self.target, region: region)
        guard let textures else {
            playback?.sceneUnavailable = true
            playback?.completed = true
            return
        }
        playback?.sceneUnavailable = false
        addChild(world)
        stageCamera.position = CGPoint(x: 300, y: 160)
        addChild(stageCamera)
        camera = stageCamera
        physicsWorld.gravity = CGVector(dx: 0, dy: -1.5)
        physicsWorld.speed = 1

        addSprite(textures.landscape, size: size, position: CGPoint(x: 300, y: 160), z: Layer.scenery)
        obstacle = addSprite(textures.targetFrames[0], size: CGSize(width: 380, height: 240),
                             position: point(449, 151), z: Layer.obstacle)
        companion = addSprite(textures.companion, size: CGSize(width: 164, height: 185),
                              position: point(180, 184.5), z: Layer.companion)
        invention = addSprite(textures.invention, size: CGSize(width: 150, height: 180),
                              position: point(264, 211), z: Layer.invention)
        invention.setScale(0.001)
        invention.alpha = 0
        addSprite(textures.foreground, size: size, position: CGPoint(x: 300, y: 160), z: Layer.foreground)

        if reduceMotion {
            showFinalState()
            playback?.completed = true
        } else {
            makePaperPool(texture: textures.scrap)
            addFloor()
            let currentStage = stageID
            // Upload the atlas before starting the timed sequence, rather than decoding
            // a new texture at each resolve frame. A dismissed presentation cannot restart.
            textures.atlas.preload { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.isStaged, self.stageID == currentStage,
                          !self.reducedMotion else { return }
                    self.playVignette()
                }
            }
        }
    }

    private func addFloor() {
        let floor = SKNode()
        floor.name = "paper.floor"
        floor.position = CGPoint(x: 300, y: 37)
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 700, height: 18))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.scrap
        body.contactTestBitMask = PhysicsCategory.none // No contact callbacks are needed.
        body.friction = 0.7
        floor.physicsBody = body
        world.addChild(floor)
    }

    private func playVignette() {
        guard let textures else { return }
        let reveal = SKAction.group([.fadeIn(withDuration: 0.3), eased(.scale(to: 0.78, duration: 0.5))])
        invention.run(.sequence([.wait(forDuration: 0.15), reveal, inventionAction()]), withKey: ActionKey.vignette)
        obstacle.run(.sequence([
            .wait(forDuration: 1.8),
            .animate(with: textures.targetFrames, timePerFrame: 1.35 / Double(textures.targetFrames.count),
                     resize: false, restore: false)
        ]), withKey: ActionKey.resolve)
        companion.run(companionAction(), withKey: ActionKey.vignette)
        run(.sequence([
            .wait(forDuration: 2.8),
            .run { [weak self] in self?.scatterPaper(at: CGPoint(x: 414, y: 164), count: 8) },
            .wait(forDuration: 1.6),
            .run { [weak self] in
                guard let self else { return }
                self.isResolved = true
                self.companion.texture = self.textures?.happyCompanion
                self.playback?.completed = true
            }
        ]), withKey: ActionKey.vignette)
    }

    private func inventionAction() -> SKAction {
        // These are directed movements of non-physics sprites. The paper scraps alone use
        // impulses, keeping the physics engine and the action system from fighting each other.
        switch action {
        case .strike:
            return .sequence([
                .group([eased(.move(to: point(250, 203), duration: 0.4)), .rotate(toAngle: 0.6, duration: 0.4)]),
                .group([eased(.move(to: point(405, 195), duration: 0.65)), .rotate(toAngle: -0.7, duration: 0.65)]),
                .group([eased(.move(to: point(359, 212), duration: 0.7)), .rotate(toAngle: -0.3, duration: 0.7)])
            ])
        case .build:
            invention.position = point(330, 197)
            invention.zRotation = 0.18
            return .sequence([.group([eased(.move(to: point(330, 221), duration: 1.3)),
                                     eased(.rotate(toAngle: 0, duration: 1.3))])])
        case .transform:
            invention.position = point(317, 193)
            return .sequence([.group([eased(.move(to: point(393, 193), duration: 1.65)),
                                     .rotate(toAngle: -0.23, duration: 1.65),
                                     .sequence([.scale(to: 0.94, duration: 0.8), .scale(to: 0.78, duration: 0.85)])])])
        case .summon:
            invention.position = point(327, 233)
            return eased(.move(to: point(327, 197), duration: 1.1))
        case .fly:
            invention.position = point(245, 183)
            let path = CGMutablePath()
            path.move(to: point(245, 183))
            path.addQuadCurve(to: point(440, 198), control: point(342, 79))
            return .group([eased(.follow(path, asOffset: false, orientToPath: false, duration: 1.9)),
                           .rotate(toAngle: -0.05, duration: 1.9)])
        case .grow:
            invention.position = point(329, 231)
            invention.setScale(0.47)
            return eased(.scale(to: 0.94, duration: 1.8))
        case .give:
            invention.position = point(242, 211)
            let path = CGMutablePath()
            path.move(to: point(242, 211))
            path.addQuadCurve(to: point(400, 222), control: point(321, 170))
            return eased(.follow(path, asOffset: false, orientToPath: false, duration: 1.9))
        case .solve:
            invention.position = point(253, 208)
            return .sequence([.group([eased(.move(to: point(405, 202), duration: 1.5)),
                                     .rotate(toAngle: -0.8, duration: 1.5)]),
                              .group([eased(.move(to: point(372, 208), duration: 0.6)),
                                      .rotate(toAngle: -0.44, duration: 0.6)])])
        case .explore:
            invention.position = point(273, 207)
            return .group([eased(.move(to: point(347, 207), duration: 1.8)),
                           .rotate(toAngle: -0.16, duration: 1.8)])
        }
    }

    private var crossesGap: Bool {
        target == .gap && [.build, .fly, .explore, .grow, .solve].contains(action)
    }

    private func companionAction() -> SKAction {
        let destination = crossesGap ? point(441, 184.5) :
            point(action == .give || action == .explore ? 297 : 180, 184.5)
        var actions: [SKAction] = [.wait(forDuration: crossesGap ? 2.3 : 1.05)]
        if crossesGap && action == .fly {
            let path = CGMutablePath()
            path.move(to: point(180, 184.5))
            path.addQuadCurve(to: destination, control: point(310, 43))
            actions.append(eased(.follow(path, asOffset: false, orientToPath: false, duration: 1.55)))
        } else {
            actions.append(eased(.move(to: destination, duration: 1.55)))
        }
        actions.append(.run { [weak self] in self?.companion.texture = self?.textures?.happyCompanion })
        actions.append(.sequence([.scaleX(to: 1.04, y: 0.96, duration: 0.13),
                                  .scaleX(to: 0.98, y: 1.03, duration: 0.19),
                                  .scale(to: 1, duration: 0.18)]))
        return .sequence(actions)
    }

    func showFinalState() {
        guard isStaged, let textures else { return }
        reducedMotion = true
        removeAllActions()
        world.children.forEach { $0.removeAllActions() }
        recycleAllPaper()
        world.childNode(withName: "paper.floor")?.removeFromParent()
        physicsWorld.speed = 0
        obstacle.texture = textures.targetFrames.last
        companion.texture = textures.happyCompanion
        companion.setScale(1)
        companion.position = crossesGap ? point(441, 184.5) :
            point(action == .give || action == .explore ? 297 : 180, 184.5)
        invention.alpha = 1
        invention.setScale(action == .grow ? 0.94 : 0.78)
        invention.zRotation = 0
        let final: CGPoint
        switch action {
        case .strike: final = point(359, 212)
        case .build: final = point(330, 221)
        case .transform: final = point(393, 193)
        case .summon: final = point(327, 197)
        case .fly: final = point(440, 198)
        case .grow: final = point(329, 231)
        case .give: final = point(400, 222)
        case .solve: final = point(372, 208)
        case .explore: final = point(347, 207)
        }
        invention.position = final
        isResolved = true
    }

    /// Optional delight, never a requirement for progressing or receiving a score. VoiceOver
    /// invokes this through the enclosing SwiftUI stage's named accessibility action.
    func celebrate() {
        guard !reducedMotion, isResolved, elapsed - lastInteraction > 0.35 else { return }
        lastInteraction = elapsed
        let hop = SKAction.sequence([
            eased(.moveBy(x: 0, y: 12, duration: 0.18)),
            eased(.moveBy(x: 0, y: -12, duration: 0.26))
        ])
        // Repeated taps replace the reaction instead of stacking a sequence of hops.
        guard companion.action(forKey: ActionKey.reaction) == nil else { return }
        companion.run(hop, withKey: ActionKey.reaction)
        scatterPaper(at: CGPoint(x: companion.position.x + 20, y: companion.position.y + 72), count: 6)
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        guard frame.contains(location) else { return }
        celebrate()
    }
    #endif

    private func makePaperPool(texture: SKTexture) {
        availableScraps = (0..<18).map { index in
            let scrap = SKSpriteNode(texture: texture, color: .clear, size: CGSize(width: 8, height: 10))
            scrap.name = "paper.scrap"
            scrap.zPosition = Layer.scraps
            scrap.color = [SKColor.systemOrange, .systemYellow, .systemGreen][index % 3]
            scrap.colorBlendFactor = 0.65
            let body = SKPhysicsBody(rectangleOf: CGSize(width: 6, height: 8))
            body.mass = 0.03
            body.categoryBitMask = PhysicsCategory.scrap
            body.collisionBitMask = PhysicsCategory.ground
            body.contactTestBitMask = PhysicsCategory.none
            body.restitution = 0.32
            body.friction = 0.65
            body.linearDamping = 1.4
            body.angularDamping = 0.8
            body.usesPreciseCollisionDetection = true
            scrap.physicsBody = body
            return scrap
        }
    }

    private func scatterPaper(at point: CGPoint, count: Int) {
        guard !reducedMotion else { return }
        for index in 0..<min(count, availableScraps.count) {
            let scrap = availableScraps.removeLast()
            scrap.removeAllActions()
            scrap.position = point
            scrap.alpha = 1
            scrap.zRotation = CGFloat(index) * 0.7
            world.addChild(scrap)
            let angle = CGFloat(index) / CGFloat(max(1, count - 1)) * .pi * 0.8 + .pi * 0.1
            scrap.physicsBody?.isDynamic = true
            scrap.physicsBody?.velocity = .zero
            scrap.physicsBody?.angularVelocity = CGFloat(index.isMultiple(of: 2) ? 3 : -3)
            scrap.physicsBody?.applyImpulse(CGVector(dx: cos(angle) * 0.027, dy: sin(angle) * 0.035))
            scrap.run(.sequence([.wait(forDuration: 1.7), .fadeOut(withDuration: 0.65)]), withKey: ActionKey.fade)
            activeScraps.append((scrap, elapsed + 2.4))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(max(0, currentTime - lastUpdateTime), 1.0 / 30.0)
        lastUpdateTime = currentTime
        elapsed += dt
        // Clamp the local lifetime clock after interruptions; SpriteKit owns motion/physics.
        for index in activeScraps.indices.reversed() {
            let entry = activeScraps[index]
            if elapsed >= entry.expiry || !frame.insetBy(dx: -80, dy: -80).contains(entry.node.position) {
                recycle(entry.node)
                activeScraps.remove(at: index)
            }
        }
    }

    private func recycle(_ scrap: SKSpriteNode) {
        scrap.removeAllActions()
        scrap.physicsBody?.velocity = .zero
        scrap.physicsBody?.angularVelocity = 0
        scrap.physicsBody?.isDynamic = false
        scrap.removeFromParent()
        availableScraps.append(scrap)
    }

    private func recycleAllPaper() {
        activeScraps.forEach { recycle($0.node) }
        activeScraps.removeAll()
    }

    func tearDown() {
        stageID = UUID()
        removeAllActions()
        world.children.forEach { $0.removeAllActions() }
        recycleAllPaper()
        world.removeAllChildren()
        removeAllChildren()
        availableScraps.removeAll()
        textures = nil
        physicsWorld.removeAllJoints()
        physicsWorld.contactDelegate = nil
        camera = nil
        isStaged = false
        lastUpdateTime = 0
    }

    override func willMove(from view: SKView) { tearDown() }

    @discardableResult
    private func addSprite(_ texture: SKTexture, size: CGSize, position: CGPoint, z: CGFloat) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: texture, color: .clear, size: size)
        sprite.position = position
        sprite.zPosition = z
        world.addChild(sprite)
        return sprite
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: 320 - y) }
    private func eased(_ action: SKAction) -> SKAction { action.timingMode = .easeInEaseOut; return action }
}

/// Bake the existing Canvas art once per presentation. The atlas batches related paper sprites;
/// no GraphicsContext paths, texture generation, or model inference run in the frame loop.
@MainActor
private final class PaperTheatreTextures {
    let atlas: SKTextureAtlas
    var landscape: SKTexture { atlas.textureNamed("landscape") }
    var foreground: SKTexture { atlas.textureNamed("foreground") }
    var companion: SKTexture { atlas.textureNamed("companion") }
    var happyCompanion: SKTexture { atlas.textureNamed("happy") }
    var invention: SKTexture { atlas.textureNamed("invention") }
    var scrap: SKTexture { atlas.textureNamed("scrap") }
    var targetFrames: [SKTexture] { (0..<9).map { atlas.textureNamed("target\($0)") } }

    private static let cache: NSCache<NSString, PaperTheatreTextures> = {
        let cache = NSCache<NSString, PaperTheatreTextures>()
        cache.countLimit = 2
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    private init(images: [String: Any]) { atlas = SKTextureAtlas(dictionary: images) }

    static func make(item: String, color: Color, action: SceneAction, target: PaperSceneTarget,
                     region: ChallengeRegion) -> PaperTheatreTextures? {
        let key = "\(region.rawValue)|\(target)|\(PaperInvention.from(item, action: action))|\(color)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        var images: [String: Any] = [:]
        var byteCost = 0
        func render(_ key: String, size: CGSize, draw: @escaping (GraphicsContext, CGSize) -> Void) {
            let view = Canvas(rendersAsynchronously: false) { context, size in draw(context, size) }
                .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1.5
            guard let image = renderer.cgImage else { return }
            byteCost += image.bytesPerRow * image.height
            #if canImport(UIKit)
            images[key] = UIImage(cgImage: image)
            #elseif canImport(AppKit)
            images[key] = NSImage(cgImage: image, size: size)
            #endif
        }
        render("landscape", size: CGSize(width: 600, height: 320)) { context, _ in
            PaperTheatreArt.landscape(context, target: target, region: region)
        }
        render("foreground", size: CGSize(width: 600, height: 320)) { context, _ in
            PaperTheatreArt.foreground(context, region: region)
        }
        for index in 0..<9 {
            render("target\(index)", size: CGSize(width: 380, height: 240)) { context, _ in
                PaperTheatreArt.target(context, kind: target, progress: Double(index) / 8,
                                      center: CGPoint(x: 190, y: 230), scale: 0.9)
            }
        }
        for happy in [false, true] {
            render(happy ? "happy" : "companion", size: CGSize(width: 164, height: 185)) { context, _ in
                PaperTheatreArt.companion(context, center: CGPoint(x: 82, y: 175), scale: 0.82,
                                          vitality: 0.95, time: 1, celebrate: happy, still: true)
            }
        }
        render("invention", size: CGSize(width: 150, height: 180)) { context, _ in
            PaperTheatreArt.invention(context, kind: .from(item, action: action), center: CGPoint(x: 75, y: 90),
                                      scale: 1, color: color)
        }
        render("scrap", size: CGSize(width: 8, height: 10)) { context, _ in
            PaperTheatreArt.paper(context, PaperTheatreArt.polygon([(0, 2), (6, 0), (8, 7), (2, 10)]),
                                  color: PaperTheatreArt.cream, shadow: 0, edge: false)
        }
        let required = Set(["landscape", "foreground", "companion", "happy", "invention", "scrap"] +
                           (0..<9).map { "target\($0)" })
        guard Set(images.keys) == required else { return nil }
        let textures = PaperTheatreTextures(images: images)
        cache.setObject(textures, forKey: key, cost: byteCost)
        return textures
    }
}
