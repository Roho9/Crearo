import SwiftUI

// The persistent world. A procedural "clay" blob companion standing in a small grove, built
// entirely from primitive meshes (no art assets) so it runs anywhere. This is the whole app's
// backdrop — the opening sequence and every panel are drawn on top of it.

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

/// Hosts the world: ground + a soft grove + the clay companion, with a gentle idle bob/sway.
final class BlobStageController {
    let arView: ARView
    private let character: Entity
    private var idle: Cancellable?
    private let start = Date()

    init(clay: UIColor = BlobCharacter.defaultClay) {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        // Dark dusk fill so the first frames don't flash white before Metal/RealityKit init.
        let sky = UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
        arView.backgroundColor = sky
        arView.environment.background = .color(sky)
        character = BlobCharacter.make(clay: clay)
        buildScene()
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

        // Warm key light.
        let key = DirectionalLight()
        key.light.intensity = 2400
        key.light.color = UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1)
        let keyAnchor = AnchorEntity(world: SIMD3(2.5, 4, 3))
        keyAnchor.addChild(key)
        key.look(at: .zero, from: SIMD3(2.5, 4, 3), relativeTo: nil)
        world.addChild(keyAnchor)

        // Mossy ground the companion stands on.
        let ground = ModelEntity(
            mesh: .generatePlane(width: 40, depth: 40),
            materials: [SimpleMaterial(color: UIColor(red: 0.16, green: 0.22, blue: 0.18, alpha: 1), isMetallic: false)]
        )
        world.addChild(ground)

        // Soft trees set BEHIND the companion (negative z) so nothing occludes it and it stays
        // the clear focal point — the world reads as a grove around and behind the figure.
        let treeSpots: [SIMD3<Float>] = [
            SIMD3(-3.4, 0, -2.8), SIMD3(3.2, 0, -2.4), SIMD3(-1.7, 0, -4.4),
            SIMD3(1.9, 0, -4.1), SIMD3(-4.3, 0, -1.6), SIMD3(4.4, 0, -1.8),
            SIMD3(0.2, 0, -5.4), SIMD3(2.8, 0, -5.7)
        ]
        for spot in treeSpots { world.addChild(Self.makeTree(at: spot)) }

        world.addChild(character)
        arView.scene.addAnchor(world)

        // Idle: a few millimetres of breathing + a slow sway, so it feels alive.
        idle = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            guard let self else { return }
            let t = Float(Date().timeIntervalSince(self.start))
            self.character.position.y = sin(t * 1.5) * 0.025
            self.character.orientation = simd_quatf(angle: sin(t * 0.6) * 0.14, axis: SIMD3(0, 1, 0))
        }
    }

    private static func makeTree(at p: SIMD3<Float>) -> Entity {
        let bark = SimpleMaterial(color: UIColor(red: 0.32, green: 0.24, blue: 0.20, alpha: 1), roughness: 1, isMetallic: false)
        let leaf = SimpleMaterial(color: UIColor(red: 0.24, green: 0.42, blue: 0.30, alpha: 1), roughness: 1, isMetallic: false)
        let trunk = ModelEntity(mesh: .generateBox(size: SIMD3(0.18, 1.2, 0.18), cornerRadius: 0.05), materials: [bark])
        trunk.position = SIMD3(0, 0.6, 0)
        let canopy = ModelEntity(mesh: .generateSphere(radius: 0.62), materials: [leaf])
        canopy.position = SIMD3(0, 1.5, 0)
        let tree = Entity()
        tree.addChild(trunk); tree.addChild(canopy)
        tree.position = p
        return tree
    }

    func setClay(_ color: UIColor) {
        let mat = SimpleMaterial(color: color, roughness: 0.95, isMetallic: false)
        character.children.compactMap { $0 as? ModelEntity }.forEach { $0.model?.materials = [mat] }
    }
}

/// SwiftUI host for the world.
struct BlobStage: UIViewRepresentable {
    var clay: UIColor = BlobCharacter.defaultClay

    func makeUIView(context: Context) -> ARView {
        let controller = BlobStageController(clay: clay)
        context.coordinator.controller = controller
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var controller: BlobStageController? }
}

#else
/// Fallback for platforms without RealityKit (e.g. Linux preview builds).
struct BlobStage: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.16),
                                Color(red: 0.05, green: 0.06, blue: 0.09)],
                       startPoint: .top, endPoint: .bottom)
    }
}
#endif
