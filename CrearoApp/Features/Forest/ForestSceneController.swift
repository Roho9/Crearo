#if canImport(RealityKit) && canImport(UIKit)
import RealityKit
import UIKit

// A minimal, cozy RealityKit diorama for the Mirrorwood — the MVP 3D stub (GDD §8, §11, TECH §4).
// Uses a non-AR ARView with a perspective camera. Built from primitive meshes only (box/plane/sphere)
// for maximum SDK compatibility and a tiny GPU budget. A production build swaps in the modular art kit,
// baked lighting, LODs, and a desaturation post-process for "the Grey".
final class ForestSceneController {
    let arView: ARView
    private let anchor = AnchorEntity(world: .zero)
    private var canopies: [ModelEntity] = []

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(Self.fogColor(corruption: 0))
        buildScene()
    }

    private func buildScene() {
        // Camera — cozy third-person framing.
        let camera = PerspectiveCamera()
        let camAnchor = AnchorEntity(world: SIMD3(0, 3.2, 7))
        camAnchor.addChild(camera)
        camera.look(at: SIMD3(0, 0.6, 0), from: SIMD3(0, 3.2, 7), relativeTo: nil)
        arView.scene.addAnchor(camAnchor)

        // Warm candlelight.
        let light = DirectionalLight()
        light.light.intensity = 1600
        light.light.color = UIColor(red: 1.0, green: 0.82, blue: 0.55, alpha: 1)
        let lightAnchor = AnchorEntity(world: SIMD3(3, 6, 4))
        lightAnchor.addChild(light)
        light.look(at: .zero, from: SIMD3(3, 6, 4), relativeTo: nil)
        arView.scene.addAnchor(lightAnchor)

        // Mossy ground.
        let ground = ModelEntity(
            mesh: .generatePlane(width: 24, depth: 24),
            materials: [SimpleMaterial(color: UIColor(red: 0.20, green: 0.28, blue: 0.22, alpha: 1), isMetallic: false)]
        )
        anchor.addChild(ground)

        // A ring of stylized trees.
        for i in 0..<12 {
            let angle = Float(i) / 12 * 2 * .pi
            let radius: Float = 3.2 + Float(i % 3)
            let tree = makeTree()
            tree.position = SIMD3(cos(angle) * radius, 0, sin(angle) * radius - 1)
            anchor.addChild(tree)
        }

        // The player — a small warm presence (the lantern-bearer).
        let player = ModelEntity(
            mesh: .generateBox(size: SIMD3(0.4, 0.9, 0.4), cornerRadius: 0.12),
            materials: [SimpleMaterial(color: UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1), isMetallic: false)]
        )
        player.position = SIMD3(0, 0.45, 0)
        anchor.addChild(player)

        // A glowing resource node.
        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.22),
            materials: [SimpleMaterial(color: UIColor(red: 0.98, green: 0.83, blue: 0.55, alpha: 1), isMetallic: false)]
        )
        glow.position = SIMD3(1.6, 0.25, 1.2)
        anchor.addChild(glow)

        arView.scene.addAnchor(anchor)
    }

    private func makeTree() -> ModelEntity {
        let trunk = ModelEntity(
            mesh: .generateBox(size: SIMD3(0.22, 1.2, 0.22), cornerRadius: 0.05),
            materials: [SimpleMaterial(color: UIColor(red: 0.35, green: 0.25, blue: 0.20, alpha: 1), isMetallic: false)]
        )
        trunk.position.y = 0.6
        let canopy = ModelEntity(
            mesh: .generateSphere(radius: 0.7),
            materials: [SimpleMaterial(color: UIColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1), isMetallic: false)]
        )
        canopy.position.y = 1.6
        canopies.append(canopy)
        let tree = ModelEntity()
        tree.addChild(trunk)
        tree.addChild(canopy)
        return tree
    }

    /// "The Grey": desaturate the scene toward conformity as corruption rises (GDD §8, §48).
    func setCorruption(_ level: Float) {
        let l = max(0, min(1, level))
        arView.environment.background = .color(Self.fogColor(corruption: l))
        // Fade canopies toward grey (a stand-in for the production desaturation post-process).
        let green = UIColor(red: 0.30, green: 0.50, blue: 0.35, alpha: 1)
        let grey = UIColor(red: 0.46, green: 0.47, blue: 0.50, alpha: 1)
        let blended = Self.blend(green, grey, t: CGFloat(l))
        for canopy in canopies {
            canopy.model?.materials = [SimpleMaterial(color: blended, isMetallic: false)]
        }
    }

    private static func fogColor(corruption: Float) -> UIColor {
        let l = CGFloat(max(0, min(1, corruption)))
        return UIColor(red: 0.12 + 0.22 * l, green: 0.13 + 0.21 * l, blue: 0.16 + 0.20 * l, alpha: 1)
    }

    private static func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t, green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t, alpha: 1)
    }
}
#endif
