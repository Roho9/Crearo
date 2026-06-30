import SwiftUI

// The persistent world. A procedural "clay" companion standing in a grove, built entirely from
// primitive meshes (no art assets). This is the whole app's backdrop; the opening sequence and
// every panel draw on top of it.
//
// Core theme made literal: ONLY WHAT WAS MADE HAS COLOUR. The world's saturation is driven by a
// `vitality` level (your creativity / companion brightness), so making things visibly relights the
// grey — the feedback IS the art, never a number (see docs/WORLD_AND_STORY.md).

#if canImport(RealityKit) && canImport(UIKit)
import RealityKit
import UIKit
import Combine

/// Assembles the blob from primitives: rounded head, pill body, stubby limbs, matte clay shading.
enum BlobCharacter {
    static let defaultClay = UIColor(red: 0.82, green: 0.79, blue: 0.73, alpha: 1)

    static func make(clay: UIColor = defaultClay) -> Entity {
        let mat = SimpleMaterial(color: clay, roughness: 0.95, isMetallic: false)
        let root = Entity()

        func part(_ size: SIMD3<Float>, corner: Float, at p: SIMD3<Float>) -> ModelEntity {
            let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: corner), materials: [mat])
            e.position = p
            return e
        }

        root.addChild(part(SIMD3(0.46, 0.72, 0.30), corner: 0.15, at: SIMD3(0, 0.95, 0)))   // torso
        let head = ModelEntity(mesh: .generateSphere(radius: 0.23), materials: [mat])
        head.position = SIMD3(0, 1.47, 0)
        root.addChild(head)
        for side in [Float(-1), Float(1)] {
            root.addChild(part(SIMD3(0.14, 0.52, 0.14), corner: 0.07, at: SIMD3(side * 0.33, 0.96, 0)))  // arm
            root.addChild(part(SIMD3(0.17, 0.56, 0.17), corner: 0.08, at: SIMD3(side * 0.13, 0.30, 0)))  // leg
        }
        return root
    }
}

/// Hosts the world: ground + grove + the clay companion, with a gentle idle bob and a
/// grey-to-colour `vitality` that rises as the player makes things.
final class BlobStageController {
    let arView: ARView
    private let character: Entity
    private var idle: Cancellable?
    private let start = Date()

    // Environment pieces whose colour is desaturated toward grey at low vitality.
    private struct Painted { let entity: ModelEntity; let base: UIColor }
    private var painted: [Painted] = []
    private let skyAlive = UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
    private let skyGrey  = UIColor(red: 0.33, green: 0.34, blue: 0.37, alpha: 1)
    private static let grey = UIColor(red: 0.42, green: 0.43, blue: 0.46, alpha: 1)
    private var vitality: Float = 0.15

    init(clay: UIColor = BlobCharacter.defaultClay) {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.backgroundColor = skyGrey
        arView.environment.background = .color(skyGrey)
        character = BlobCharacter.make(clay: clay)
        buildScene()
        applyVitality()
    }

    private func buildScene() {
        let world = AnchorEntity(world: .zero)

        // Cozy third-person framing on the companion (full figure, slight downward angle).
        let camera = PerspectiveCamera()
        let camPos = SIMD3<Float>(0, 1.2, 3.4)
        let camAnchor = AnchorEntity(world: camPos)
        camAnchor.addChild(camera)
        camera.look(at: SIMD3(0, 0.85, 0), from: camPos, relativeTo: nil)
        world.addChild(camAnchor)

        let key = DirectionalLight()
        key.light.intensity = 2400
        key.light.color = UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1)
        let keyAnchor = AnchorEntity(world: SIMD3(2.5, 4, 3))
        keyAnchor.addChild(key)
        key.look(at: .zero, from: SIMD3(2.5, 4, 3), relativeTo: nil)
        world.addChild(keyAnchor)

        // Mossy ground the companion stands on.
        let groundBase = UIColor(red: 0.18, green: 0.30, blue: 0.20, alpha: 1)
        let ground = ModelEntity(mesh: .generatePlane(width: 40, depth: 40),
                                 materials: [SimpleMaterial(color: groundBase, isMetallic: false)])
        painted.append(Painted(entity: ground, base: groundBase))
        world.addChild(ground)

        // Soft trees BEHIND the companion so nothing occludes it and it stays the focal point.
        let treeSpots: [SIMD3<Float>] = [
            SIMD3(-3.4, 0, -2.8), SIMD3(3.2, 0, -2.4), SIMD3(-1.7, 0, -4.4),
            SIMD3(1.9, 0, -4.1), SIMD3(-4.3, 0, -1.6), SIMD3(4.4, 0, -1.8),
            SIMD3(0.2, 0, -5.4), SIMD3(2.8, 0, -5.7)
        ]
        for spot in treeSpots { world.addChild(makeTree(at: spot)) }

        world.addChild(character)
        arView.scene.addAnchor(world)

        idle = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            guard let self else { return }
            let t = Float(Date().timeIntervalSince(self.start))
            self.character.position.y = sin(t * 1.5) * 0.025
            self.character.orientation = simd_quatf(angle: sin(t * 0.6) * 0.14, axis: SIMD3(0, 1, 0))
        }
    }

    private func makeTree(at p: SIMD3<Float>) -> Entity {
        let barkBase = UIColor(red: 0.36, green: 0.26, blue: 0.20, alpha: 1)
        let leafBase = UIColor(red: 0.26, green: 0.48, blue: 0.32, alpha: 1)
        let trunk = ModelEntity(mesh: .generateBox(size: SIMD3(0.18, 1.2, 0.18), cornerRadius: 0.05),
                                materials: [SimpleMaterial(color: barkBase, isMetallic: false)])
        trunk.position = SIMD3(0, 0.6, 0)
        let canopy = ModelEntity(mesh: .generateSphere(radius: 0.62),
                                 materials: [SimpleMaterial(color: leafBase, isMetallic: false)])
        canopy.position = SIMD3(0, 1.5, 0)
        painted.append(Painted(entity: trunk, base: barkBase))
        painted.append(Painted(entity: canopy, base: leafBase))
        let tree = Entity()
        tree.addChild(trunk); tree.addChild(canopy)
        tree.position = p
        return tree
    }

    /// 0 = fully grey (the Greying), 1 = full colour. Drives the world's saturation.
    func setVitality(_ level: Float) {
        let clamped = max(0, min(1, level))
        guard abs(clamped - vitality) > 0.001 else { return }
        vitality = clamped
        applyVitality()
    }

    private func applyVitality() {
        let t = CGFloat(1 - vitality)   // how much grey
        for p in painted {
            let c = Self.blend(p.base, Self.grey, t: t)
            p.entity.model?.materials = [SimpleMaterial(color: c, isMetallic: false)]
        }
        let sky = Self.blend(skyAlive, skyGrey, t: t)
        arView.environment.background = .color(sky)
        arView.backgroundColor = sky
    }

    func setClay(_ color: UIColor) {
        let mat = SimpleMaterial(color: color, roughness: 0.95, isMetallic: false)
        character.children.compactMap { $0 as? ModelEntity }.forEach { $0.model?.materials = [mat] }
    }

    private static func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t, alpha: 1)
    }
}

/// SwiftUI host for the world. `vitality` (0…1) relights the grey as the player creates.
struct BlobStage: UIViewRepresentable {
    var vitality: Float = 0.15

    func makeUIView(context: Context) -> ARView {
        let controller = BlobStageController()
        controller.setVitality(vitality)
        context.coordinator.controller = controller
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller?.setVitality(vitality)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var controller: BlobStageController? }
}

#else
/// Fallback for platforms without RealityKit (e.g. Linux preview builds).
struct BlobStage: View {
    var vitality: Float = 0.15
    var body: some View {
        LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.16),
                                Color(red: 0.05, green: 0.06, blue: 0.09)],
                       startPoint: .top, endPoint: .bottom)
    }
}
#endif
