import SwiftUI

// The living world: a procedural clay world you move through. Built from primitive meshes only
// (no art assets). Walkable clay companion, a Faceless follower, leafy trees you can chop, Greyed
// enemies you can fight, grass, and a dynamic sky (day/night, sun, moon, clouds; rain/fog overlay).
//
// Theme made literal: only what was made has colour — world saturation rises with `vitality`.
// See docs/WORLD_AND_STORY.md.

enum WorldAction: Equatable {
    case chop, fight
    var label: String { self == .chop ? "Chop" : "Fight" }
    var icon: String { self == .chop ? "leaf.fill" : "burst.fill" }
}

enum Weather: Equatable { case clear, cloudy, fog, rain }

#if canImport(RealityKit) && canImport(UIKit)
import RealityKit
import UIKit
import Combine

// MARK: - Clay blob rig (limbs hang from shoulder/hip joints so they connect AND can swing)

struct BlobRig {
    let root: Entity
    let torso: Entity
    let limbs: [Entity]          // [leftArm, rightArm, leftLeg, rightLeg]
}

enum BlobBuilder {
    static func make(clay: UIColor, scale: Float = 1) -> BlobRig {
        let mat = SimpleMaterial(color: clay, roughness: 0.95, isMetallic: false)
        let root = Entity()
        root.scale = SIMD3(repeating: scale)

        let torso = Entity()
        let torsoMesh = ModelEntity(mesh: .generateBox(size: SIMD3(0.50, 0.74, 0.32), cornerRadius: 0.16), materials: [mat])
        torsoMesh.position = SIMD3(0, 0.96, 0)
        torso.addChild(torsoMesh)
        let head = ModelEntity(mesh: .generateSphere(radius: 0.24), materials: [mat])
        head.position = SIMD3(0, 1.55, 0)
        torso.addChild(head)
        root.addChild(torso)

        func limb(_ size: SIMD3<Float>, at joint: SIMD3<Float>) -> Entity {
            let j = Entity()
            j.position = joint
            let m = ModelEntity(mesh: .generateBox(size: size, cornerRadius: min(size.x, size.z) / 2), materials: [mat])
            m.position = SIMD3(0, -size.y / 2, 0)        // hang below the joint
            j.addChild(m)
            let cap = ModelEntity(mesh: .generateSphere(radius: size.x * 0.85), materials: [mat])  // shoulder/hip
            j.addChild(cap)
            root.addChild(j)
            return j
        }
        let leftArm  = limb(SIMD3(0.15, 0.50, 0.15), at: SIMD3(-0.26, 1.20, 0))
        let rightArm = limb(SIMD3(0.15, 0.50, 0.15), at: SIMD3( 0.26, 1.20, 0))
        let leftLeg  = limb(SIMD3(0.17, 0.55, 0.17), at: SIMD3(-0.12, 0.62, 0))
        let rightLeg = limb(SIMD3(0.17, 0.55, 0.17), at: SIMD3( 0.12, 0.62, 0))
        return BlobRig(root: root, torso: torso, limbs: [leftArm, rightArm, leftLeg, rightLeg])
    }
}

// MARK: - World controller

@MainActor
final class WorldController: ObservableObject {
    let arView: ARView
    @Published var nearbyAction: WorldAction?
    @Published var weather: Weather = .clear
    var moveInput: SIMD2<Float> = .zero          // joystick, components in -1...1
    var onGather: ((Int) -> Void)?

    private let scene = AnchorEntity(world: .zero)
    private var player: BlobRig!
    private var follower: BlobRig!
    private var characterModel: Entity?       // imported USDZ, if any
    private var characterNormalizer: Entity?  // wrapper we scale/offset once the model is in-scene
    private var needsCharacterNormalize = false
    private var characterYawOffset: Float = 0 // rotate the model if it faces the wrong way
    private var camera = PerspectiveCamera()
    private var sun = ModelEntity()
    private var moon = ModelEntity()
    private var sunLight = DirectionalLight()
    private var clouds: [Entity] = []
    private var grass: [ModelEntity] = []
    private var trees: [(entity: Entity, pos: SIMD3<Float>, chopped: Bool)] = []
    private var enemy: Entity?
    private var enemyPos = SIMD3<Float>(4, 0, -3)
    private var painted: [(ModelEntity, UIColor)] = []   // desaturated toward grey at low vitality

    private var vitality: Float = 0.15
    private var dayTime: Float = 0.30                     // 0...1, 0.25 ≈ noon
    private var walkPhase: Float = 0
    private var followerPhase: Float = 0
    private var swing: Float = 0                          // chop/fight arm-swing impulse
    private var facing: Float = .pi                       // yaw, radians
    private var weatherTimer: Float = 0
    private var last = Date()

    private let skyDay = UIColor(red: 0.40, green: 0.52, blue: 0.70, alpha: 1)
    private let skyNight = UIColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1)
    private static let grey = UIColor(red: 0.42, green: 0.43, blue: 0.46, alpha: 1)

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = skyNight
        build()
        arView.scene.addAnchor(scene)
        sceneSub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] e in
            self?.tick(Float(e.deltaTime))
        }
        applyVitality()
    }
    private var sceneSub: Cancellable?

    // MARK: build

    private func build() {
        let cameraAnchor = Entity()
        cameraAnchor.addChild(camera)
        scene.addChild(cameraAnchor)

        sunLight.light.intensity = 2400
        scene.addChild(sunLight)

        // Sun & moon as glowing (unlit) spheres.
        sun = ModelEntity(mesh: .generateSphere(radius: 0.9), materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.92, blue: 0.6, alpha: 1))])
        moon = ModelEntity(mesh: .generateSphere(radius: 0.6), materials: [UnlitMaterial(color: UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1))])
        scene.addChild(sun); scene.addChild(moon)

        // Ground.
        let groundBase = UIColor(red: 0.18, green: 0.30, blue: 0.20, alpha: 1)
        let ground = ModelEntity(mesh: .generatePlane(width: 60, depth: 60), materials: [SimpleMaterial(color: groundBase, isMetallic: false)])
        painted.append((ground, groundBase))
        scene.addChild(ground)

        // Grass blades scattered in a patch around the player.
        let bladeBase = UIColor(red: 0.30, green: 0.52, blue: 0.30, alpha: 1)
        for _ in 0..<140 {
            let blade = ModelEntity(mesh: .generateBox(size: SIMD3(0.04, Float.random(in: 0.14...0.26), 0.012)),
                                    materials: [SimpleMaterial(color: bladeBase, isMetallic: false)])
            let a = Float.random(in: 0..<2 * .pi), r = Float.random(in: 0.6...7)
            blade.position = SIMD3(cos(a) * r, 0.1, sin(a) * r)
            blade.orientation = simd_quatf(angle: Float.random(in: 0..<2 * .pi), axis: SIMD3(0, 1, 0))
            painted.append((blade, bladeBase))
            grass.append(blade)
            scene.addChild(blade)
        }

        // Leafy trees (clustered canopy) you can chop.
        let spots: [SIMD3<Float>] = [
            SIMD3(-3.6, 0, -2.8), SIMD3(3.4, 0, -2.2), SIMD3(-1.8, 0, -5.0),
            SIMD3(2.2, 0, -4.6), SIMD3(-4.6, 0, -0.8), SIMD3(4.8, 0, -1.2), SIMD3(0.4, 0, -6.2)
        ]
        for s in spots {
            let t = makeTree()
            t.position = s
            trees.append((t, s, false))
            scene.addChild(t)
        }

        // The player: the imported clay character if present, else the procedural blob. The model
        // keeps its authored transform; a normalizer wrapper is scaled to world size on the first
        // frame (once it's anchored and its world bounds are valid — see tick()).
        if let model = try? Entity.load(named: "blob_character") {
            let normalizer = Entity()
            normalizer.addChild(model)
            let torso = Entity(); torso.addChild(normalizer)
            let root = Entity(); root.addChild(torso)
            player = BlobRig(root: root, torso: torso, limbs: [])
            characterModel = model
            characterNormalizer = normalizer
            needsCharacterNormalize = true
        } else {
            player = BlobBuilder.make(clay: BlobCharacterPalette.clay)
        }
        scene.addChild(player.root)

        // A Faceless follower — smaller, paler.
        follower = BlobBuilder.make(clay: UIColor(red: 0.66, green: 0.66, blue: 0.64, alpha: 1), scale: 0.55)
        follower.root.position = SIMD3(0.8, 0, 1.0)
        scene.addChild(follower.root)

        // A Greyed enemy (a Mimic) to fight.
        enemy = makeEnemy()
        enemy?.position = enemyPos
        if let enemy { scene.addChild(enemy) }
    }

    private func makeTree() -> Entity {
        let barkBase = UIColor(red: 0.36, green: 0.26, blue: 0.20, alpha: 1)
        let leafBase = UIColor(red: 0.24, green: 0.46, blue: 0.30, alpha: 1)
        let tree = Entity()
        let trunk = ModelEntity(mesh: .generateBox(size: SIMD3(0.22, 1.3, 0.22), cornerRadius: 0.06), materials: [SimpleMaterial(color: barkBase, isMetallic: false)])
        trunk.position = SIMD3(0, 0.65, 0)
        painted.append((trunk, barkBase))
        tree.addChild(trunk)
        // Canopy: a cluster of leaf clumps so it reads as foliage, not one ball.
        let clumps: [SIMD3<Float>] = [SIMD3(0, 1.55, 0), SIMD3(-0.32, 1.35, 0.1), SIMD3(0.34, 1.38, -0.08), SIMD3(0.05, 1.42, 0.34), SIMD3(-0.1, 1.42, -0.32)]
        for (i, c) in clumps.enumerated() {
            let leaf = ModelEntity(mesh: .generateSphere(radius: i == 0 ? 0.5 : 0.36), materials: [SimpleMaterial(color: leafBase, isMetallic: false)])
            leaf.position = c
            painted.append((leaf, leafBase))
            tree.addChild(leaf)
        }
        return tree
    }

    private func makeEnemy() -> Entity {
        let rig = BlobBuilder.make(clay: UIColor(red: 0.34, green: 0.34, blue: 0.37, alpha: 1), scale: 0.9)
        // a single dull eye so it reads as a creature
        let eye = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: UIColor(red: 0.9, green: 0.85, blue: 0.6, alpha: 1))])
        eye.position = SIMD3(0, 1.5, 0.22)
        rig.root.addChild(eye)
        return rig.root
    }

    // MARK: per-frame update

    private func tick(_ dtRaw: Float) {
        let dt = min(dtRaw, 1.0 / 20)
        let t = Float(Date().timeIntervalSince(last))

        normalizeCharacterIfNeeded()

        // Movement.
        let move = SIMD3<Float>(moveInput.x, 0, moveInput.y)
        let speed = simd_length(move)
        if speed > 0.05 {
            let dir = move / speed
            facing = atan2(dir.x, dir.z)
            player.root.position += dir * min(speed, 1) * 2.2 * dt
            walkPhase += dt * 9
        } else {
            walkPhase += dt * 2
        }
        player.root.orientation = simd_quatf(angle: facing, axis: SIMD3(0, 1, 0))

        // Walk / idle animation: swing limbs from their joints, bob the torso.
        let moving = speed > 0.05
        let amp: Float = moving ? 0.6 : 0.04
        let s = sin(walkPhase)
        if player.limbs.count >= 4 {                              // procedural blob: swing the limbs
            player.limbs[0].orientation = simd_quatf(angle:  s * amp, axis: SIMD3(1, 0, 0)) // L arm
            player.limbs[1].orientation = simd_quatf(angle: -s * amp, axis: SIMD3(1, 0, 0)) // R arm
            player.limbs[2].orientation = simd_quatf(angle: -s * amp, axis: SIMD3(1, 0, 0)) // L leg
            player.limbs[3].orientation = simd_quatf(angle:  s * amp, axis: SIMD3(1, 0, 0)) // R leg
        }
        player.torso.position.y = moving ? abs(sin(walkPhase)) * 0.04 : sin(t * 1.4) * 0.02

        // Chop/fight: a quick right-arm swing impulse (procedural blob) or a whole-body lean (USDZ).
        if swing > 0 {
            swing = max(0, swing - dt * 3)
            if player.limbs.count >= 2 {
                player.limbs[1].orientation = simd_quatf(angle: -1.5 * swing, axis: SIMD3(1, 0, 0))
            } else {
                player.torso.orientation = simd_quatf(angle: -0.4 * swing, axis: SIMD3(1, 0, 0))
            }
        }

        // Camera follows from a fixed angle behind.
        let target = player.root.position + SIMD3(0, 0.85, 0)
        let camPos = player.root.position + SIMD3(0, 1.8, 3.6)
        camera.position = camPos
        camera.look(at: target, from: camPos, relativeTo: nil)

        // Faceless follower trails the player, walking when it has ground to cover.
        let fTarget = player.root.position + SIMD3(sin(facing + 2.4) * 1.1, 0, cos(facing + 2.4) * 1.1)
        let fOld = follower.root.position
        follower.root.position += (fTarget - fOld) * min(1, dt * 2.4)
        let fSpeed = simd_length(follower.root.position - fOld) / max(dt, 0.0001)
        let fMoving = fSpeed > 0.25
        let fd = player.root.position - follower.root.position
        if simd_length(fd) > 0.2 { follower.root.orientation = simd_quatf(angle: atan2(fd.x, fd.z), axis: SIMD3(0, 1, 0)) }
        followerPhase += dt * (fMoving ? 9 : 2)
        let fAmp: Float = fMoving ? 0.5 : 0.03
        let fs = sin(followerPhase)
        follower.limbs[0].orientation = simd_quatf(angle:  fs * fAmp, axis: SIMD3(1, 0, 0))
        follower.limbs[1].orientation = simd_quatf(angle: -fs * fAmp, axis: SIMD3(1, 0, 0))
        follower.limbs[2].orientation = simd_quatf(angle: -fs * fAmp, axis: SIMD3(1, 0, 0))
        follower.limbs[3].orientation = simd_quatf(angle:  fs * fAmp, axis: SIMD3(1, 0, 0))
        follower.torso.position.y = fMoving ? abs(sin(followerPhase)) * 0.03 : sin(t * 1.8) * 0.02

        // Enemy drifts slowly toward the player when far, idles when near.
        if let enemy {
            let toP = player.root.position - enemy.position
            let d = simd_length(toP)
            if d > 1.4 { enemy.position += (toP / max(d, 0.001)) * 0.6 * dt }
            enemy.orientation = simd_quatf(angle: atan2(toP.x, toP.z), axis: SIMD3(0, 1, 0))
            enemy.position.y = sin(t * 2 + 1) * 0.03
        }

        updateSky(dt)
        updateClouds(dt)
        swayGrass(t)
        updateNearby()
    }

    /// Once the imported model is anchored, scale its wrapper so the character is ~1.7 units tall,
    /// with feet on the ground and centered. Measuring in the player's space respects the asset's
    /// own authored scale (the local-space measurement at load time did not).
    private func normalizeCharacterIfNeeded() {
        guard needsCharacterNormalize, let model = characterModel, let norm = characterNormalizer else { return }
        let b = model.visualBounds(relativeTo: player.root)
        guard b.extents.y > 0.0001 else { return }   // bounds not ready yet; try next frame
        let s = 1.7 / b.extents.y
        norm.scale = SIMD3(repeating: s)
        norm.orientation = simd_quatf(angle: characterYawOffset, axis: SIMD3(0, 1, 0))
        let b2 = model.visualBounds(relativeTo: player.root)   // after scaling
        norm.position = SIMD3(-b2.center.x, -b2.min.y, -b2.center.z)
        needsCharacterNormalize = false
    }

    private func updateNearby() {
        let p = player.root.position
        var action: WorldAction?
        if let enemy, enemy.isEnabled, simd_length(enemy.position - p) < 2.2 { action = .fight }
        else if trees.contains(where: { !$0.chopped && simd_length($0.pos - p) < 2.2 }) { action = .chop }
        if action != nearbyAction { nearbyAction = action }
    }

    // MARK: sky / weather

    private func updateSky(_ dt: Float) {
        dayTime += dt / 1800                         // 30-min full cycle: ~15 min day + ~15 min night
        if dayTime > 1 { dayTime -= 1 }
        let ang = dayTime * 2 * .pi
        let elev = sin(ang)                          // >0 day, <0 night
        let day = max(0, elev)

        sun.position = SIMD3(cos(ang) * 10, elev * 8, -14)
        moon.position = SIMD3(-cos(ang) * 10, -elev * 8, -14)
        // Keep each body strictly above the horizon so it never shows through the ground.
        sun.isEnabled = elev > 0.02
        moon.isEnabled = elev < -0.02

        sunLight.light.intensity = (0.12 + day * 0.9) * 2600
        sunLight.look(at: .zero, from: day > 0 ? sun.position : moon.position, relativeTo: nil)
        let warm = UIColor(red: 1, green: 0.74, blue: 0.45, alpha: 1)
        sunLight.light.color = Self.blend(warm, .white, t: CGFloat(day))

        var sky = Self.blend(skyNight, skyDay, t: CGFloat(day))
        // dusk/dawn warmth near the horizon
        if elev > -0.25 && elev < 0.35 { sky = Self.blend(sky, UIColor(red: 0.65, green: 0.4, blue: 0.3, alpha: 1), t: 0.35) }
        // fog washes the sky pale; vitality greys it
        if weather == .fog { sky = Self.blend(sky, UIColor(red: 0.7, green: 0.72, blue: 0.74, alpha: 1), t: 0.5) }
        sky = Self.blend(sky, Self.grey, t: CGFloat((1 - vitality) * 0.5))
        arView.environment.background = .color(sky)
        arView.backgroundColor = sky

        // Cycle weather occasionally.
        weatherTimer += dt
        if weatherTimer > 22 {
            weatherTimer = 0
            weather = [.clear, .clear, .cloudy, .fog, .rain].randomElement() ?? .clear
        }
    }

    private func updateClouds(_ dt: Float) {
        if clouds.isEmpty && weather != .clear { spawnClouds() }
        for c in clouds {
            c.position.x += dt * 0.4
            if c.position.x > 16 { c.position.x = -16 }
            c.isEnabled = weather != .clear
        }
        if weather == .clear { for c in clouds { c.isEnabled = false } }
    }

    private func spawnClouds() {
        for _ in 0..<5 {
            let cloud = Entity()
            for _ in 0..<4 {
                let puff = ModelEntity(mesh: .generateSphere(radius: Float.random(in: 0.5...0.9)),
                                       materials: [UnlitMaterial(color: UIColor(white: 0.85, alpha: 1))])
                puff.position = SIMD3(Float.random(in: -1...1), Float.random(in: -0.2...0.2), Float.random(in: -0.4...0.4))
                cloud.addChild(puff)
            }
            cloud.position = SIMD3(Float.random(in: -16...16), Float.random(in: 6...8), Float.random(in: -16 ... -8))
            clouds.append(cloud)
            scene.addChild(cloud)
        }
    }

    private func swayGrass(_ t: Float) {
        for (i, blade) in grass.enumerated() {
            let sway = sin(t * 1.6 + Float(i)) * 0.08 + (weather == .rain ? 0.12 : 0)
            blade.orientation = simd_quatf(angle: sway, axis: SIMD3(0, 0, 1))
        }
    }

    // MARK: actions

    func interact() {
        guard let action = nearbyAction else { return }
        switch action {
        case .chop:
            swing = 1
            let p = player.root.position
            if let idx = trees.firstIndex(where: { !$0.chopped && simd_length($0.pos - p) < 2.2 }) {
                trees[idx].chopped = true
                let tree = trees[idx].entity
                // topple + sink
                var fall = Transform(matrix: tree.transformMatrix(relativeTo: scene))
                fall.rotation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0)) * fall.rotation
                fall.translation.y -= 0.3
                tree.move(to: fall, relativeTo: scene, duration: 0.6, timingFunction: .easeOut)
                onGather?(Int.random(in: 2...4))
            }
        case .fight:
            swing = 1
            guard let enemy else { return }
            // recoil + dissolve, then respawn elsewhere
            var t = Transform(matrix: enemy.transformMatrix(relativeTo: scene))
            t.scale = SIMD3(repeating: 0.01)
            enemy.move(to: t, relativeTo: scene, duration: 0.4, timingFunction: .easeIn)
            onGather?(Int.random(in: 3...6))
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                let a = Float.random(in: 0..<2 * .pi)
                enemy.position = SIMD3(cos(a) * 6, 0, sin(a) * 6)
                enemy.transform.scale = SIMD3(repeating: 0.9)
            }
            nearbyAction = nil
        }
    }

    // MARK: vitality

    func setVitality(_ level: Float) {
        let c = max(0, min(1, level))
        guard abs(c - vitality) > 0.001 else { return }
        vitality = c
        applyVitality()
    }

    private func applyVitality() {
        let t = CGFloat(1 - vitality)
        for (e, base) in painted {
            e.model?.materials = [SimpleMaterial(color: Self.blend(base, Self.grey, t: t), isMetallic: false)]
        }
    }

    private static func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let u = max(0, min(1, t))
        return UIColor(red: ar + (br - ar) * u, green: ag + (bg - ag) * u, blue: ab + (bb - ab) * u, alpha: 1)
    }
}

enum BlobCharacterPalette {
    static let clay = UIColor(red: 0.82, green: 0.79, blue: 0.73, alpha: 1)
}

/// SwiftUI host that renders the shared world controller's ARView.
struct WorldStage: UIViewRepresentable {
    let controller: WorldController
    func makeUIView(context: Context) -> ARView { controller.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#else
final class WorldController: ObservableObject {
    @Published var nearbyAction: WorldAction?
    @Published var weather: Weather = .clear
    var moveInput: SIMD2<Float> = .zero
    var onGather: ((Int) -> Void)?
    func setVitality(_ level: Float) {}
    func interact() {}
}
struct WorldStage: View {
    let controller: WorldController
    var body: some View {
        LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.16), Color(red: 0.05, green: 0.06, blue: 0.09)],
                       startPoint: .top, endPoint: .bottom)
    }
}
#endif
