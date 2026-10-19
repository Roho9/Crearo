import SwiftUI
import UIKit
import RealityKit
import Combine
import simd

/// The iOS 17 renderer for Oddworks. SwiftUI owns readable task text and accessible
/// controls; this view owns only the visible world and a bounded demonstration rig.
struct AtelierSceneView: View {
    let chapter: Int
    let parts: [String]
    let selectedSocket: Int
    let attemptID: UUID?
    let isTesting: Bool
    let didPass: Bool?
    let onSocketTap: (Int) -> Void
    let onTestFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var assetNotice: String?

    var body: some View {
        AtelierRealitySurface(chapter: chapter, parts: parts, selectedSocket: selectedSocket,
                              attemptID: attemptID, isTesting: isTesting, didPass: didPass,
                              reduceMotion: reduceMotion, isActive: scenePhase == .active,
                              onSocketTap: onSocketTap, onTestFinished: onTestFinished,
                              onAssetNotice: { assetNotice = $0 })
            .overlay(alignment: .bottomLeading) {
                if let assetNotice {
                    Text(assetNotice)
                        .font(.caption2).foregroundStyle(.white)
                        .padding(8).background(.black.opacity(0.8))
                        .padding(8).allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Oddworks three-dimensional workshop. Three mechanism sockets.")
            .accessibilityHint("Use the numbered socket buttons below the scene to choose a position.")
    }
}

private struct AtelierRealitySurface: UIViewRepresentable {
    let chapter: Int
    let parts: [String]
    let selectedSocket: Int
    let attemptID: UUID?
    let isTesting: Bool
    let didPass: Bool?
    let reduceMotion: Bool
    let isActive: Bool
    let onSocketTap: (Int) -> Void
    let onTestFinished: () -> Void
    let onAssetNotice: (String?) -> Void

    func makeCoordinator() -> AtelierCoordinator { AtelierCoordinator() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(AtelierGeometry.ink)
        // The graphic look uses geometry, paint and one shadow source. Expensive camera
        // post-processing is intentionally absent, including on older supported phones.
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-OddworksDiagnostics") {
            view.debugOptions = [.showStatistics, .showPhysics]
        }
        #endif
        context.coordinator.install(in: view)
        context.coordinator.synchronize(self)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.synchronize(self)
    }

    static func dismantleUIView(_ view: ARView, coordinator: AtelierCoordinator) {
        coordinator.dismantle()
    }
}

@MainActor
private final class AtelierCoordinator: NSObject {
    private enum Collision {
        static let socket = CollisionGroup(rawValue: 1 << 1)
        static let floor = CollisionGroup(rawValue: 1 << 2)
        static let marble = CollisionGroup(rawValue: 1 << 3)
        static let motor = CollisionGroup(rawValue: 1 << 4)
    }

    private weak var view: ARView?
    private let anchor = AnchorEntity(world: .zero)
    private let world = Entity()
    private let camera = PerspectiveCamera()
    private let character = Entity()
    private let fallbackWorld = Entity()
    private let fallbackCharacter = Entity()
    private let socketRoot = Entity()
    private let mechanismRoot = Entity()
    private let rigRoot = Entity()
    private let goalRoot = Entity()
    private var goalElements: [String: Entity] = [:]
    private var goalAccent: PointLight?
    private var selectionRings: [Entity] = []
    private var mechanisms: [Entity] = []
    private var prototypes: [String: Entity] = [:]
    private var updateSubscription: (any Cancellable)?
    private var assetLoads: Set<AnyCancellable> = []
    private var loadGeneration = UUID()
    private var loadedAssets: Set<String> = []
    private var failedAssets: Set<String> = []
    private var completedAssetLoads = 0
    private var disposed = false
    private var texture: TextureResource?
    private var floor: ModelEntity?
    private var marble: ModelEntity?
    private var motor: ModelEntity?
    private var state: AtelierRealitySurface?
    private var renderedParts: [String] = []
    private var renderedChapter = -1
    private var currentAttempt: UUID?
    private var hasStartedAttempt = false
    private var completionDelivered = true
    private var testElapsed: Float = 0
    private var restingPosition: SIMD3<Float> = [-1.92, 0.27, 0.67]
    private var previousAssetNotice: String?
    private var elapsed: Float = 0
    private var orbit: Float = 0
    private var isActive = false
    private var reduceMotion = false
    private let startPosition: SIMD3<Float> = [-1.92, 0.27, 0.67]
    private let socketPositions: [SIMD3<Float>] = [[-1.25, 0.24, 1.65], [0, 0.24, 1.65], [1.25, 0.24, 1.65]]

    func install(in view: ARView) {
        self.view = view
        texture = AtelierGeometry.paintTexture()
        anchor.name = "OddworksAnchor"
        world.name = "OddworksWorld"
        anchor.addChild(world)
        view.scene.addAnchor(anchor)
        world.addChild(fallbackWorld)
        world.addChild(socketRoot)
        world.addChild(mechanismRoot)
        world.addChild(rigRoot)
        world.addChild(goalRoot)
        world.addChild(character)
        character.addChild(fallbackCharacter)
        character.position = startPosition
        makeFallbackStage()
        makeFallbackCharacter()
        makeSockets()
        makePhysicsRig()
        makeLighting()
        anchor.addChild(camera)
        camera.camera.fieldOfViewInDegrees = 37
        camera.camera.near = 0.1
        camera.camera.far = 35
        aimCamera()
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        loadAsset("StrangeAtelier")
        loadAsset("Loop")
    }

    func synchronize(_ next: AtelierRealitySurface) {
        guard !disposed else { return }
        let wasTesting = state?.isTesting ?? false
        state = next
        reduceMotion = next.reduceMotion
        if renderedChapter != next.chapter {
            renderedChapter = next.chapter
            character.position = startPosition
            restingPosition = startPosition
            character.orientation = simd_quatf(angle: -0.15, axis: [0, 1, 0])
            hasStartedAttempt = false
            completionDelivered = true
            resetRig()
            makeGoal(chapter: next.chapter)
        }
        let supported = ["fan", "bell", "spring", "mirror", "sail", "magnet", "wheel", "seed"]
        let boundedParts = (0..<3).map { index in
            let id = next.parts.indices.contains(index) ? next.parts[index] : ""
            return supported.contains(id) ? id : ""
        }
        if boundedParts != renderedParts { setParts(boundedParts) }
        for (index, ring) in selectionRings.enumerated() {
            ring.scale = .init(repeating: index == next.selectedSocket ? 1.13 : 0.92)
            ring.isEnabled = index == next.selectedSocket || !next.isTesting
            if let model = ring as? ModelEntity {
                model.model?.materials = [AtelierGeometry.material(index == next.selectedSocket ? AtelierGeometry.acid : AtelierGeometry.cobalt,
                                                                    texture: texture)]
            }
        }
        setActive(next.isActive)
        let freshAttempt = !hasStartedAttempt || next.attemptID != currentAttempt || !wasTesting
        if next.isTesting && freshAttempt {
            currentAttempt = next.attemptID
            hasStartedAttempt = true
            completionDelivered = false
            testElapsed = 0
            character.position = startPosition
            resetRig()
            if !next.reduceMotion && next.isActive { startRig() }
        }
        if !next.isTesting {
            completionDelivered = true
            stopRig()
        } else if next.reduceMotion && !completionDelivered {
            applyTestPose(progress: 1)
            finishAttempt()
        }
        configureSubscription()
        publishAssetNotice()
    }

    private func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        world.isEnabled = active
        if !active {
            updateSubscription?.cancel()
            updateSubscription = nil
            // Disabling the world removes its bodies from simulation while backgrounded.
            // Keep their transforms for the next foreground frame rather than integrating
            // a large wall-clock delta when the user returns.
        }
    }

    private func configureSubscription() {
        let needsUpdates = isActive && !reduceMotion
        if !needsUpdates {
            updateSubscription?.cancel()
            updateSubscription = nil
            if reduceMotion { stopRig() }
            return
        }
        guard updateSubscription == nil, let view else { return }
        updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.tick(deltaTime: event.deltaTime)
        }
    }

    private func tick(deltaTime: TimeInterval) {
        guard !disposed, isActive, !reduceMotion, let state else { return }
        let dt = Float(min(max(deltaTime, 0), 1.0 / 30.0))
        elapsed += dt
        if state.isTesting && !completionDelivered {
            testElapsed += dt
            let progress = min(testElapsed / 3.15, 1)
            animateMechanisms(time: testElapsed)
            applyTestPose(progress: progress)
            // A single bounded physics marble is recycled if it leaves the visible rig.
            if let marble, marble.position.y < -0.5 || simd_length(marble.position) > 6 {
                marble.isEnabled = false
            }
            if progress >= 1 { finishAttempt() }
        } else {
            character.position.y = restingPosition.y + sin(elapsed * 1.8) * 0.018
        }
    }

    private func applyTestPose(progress: Float) {
        guard let state else { return }
        let eased = progress * progress * (3 - 2 * progress)
        let pass = state.didPass == true
        let tideStation = ((max(1, renderedChapter) - 1) % 6) == 5
        // Only the stair puzzle asks Loop to travel. Elsewhere the selected mechanisms
        // act on the actual goal sculpture, while Loop watches from the landing.
        let end: SIMD3<Float> = pass && tideStation ? [0.75, 1.18, -0.15] : startPosition
        let travel = tideStation ? min(eased * 1.18, 1) : 0
        character.position = startPosition + (end - startPosition) * travel
        if !reduceMotion {
            character.position.y += sin(progress * .pi) * (tideStation && pass ? 0.24 : 0.05)
            character.orientation = simd_quatf(angle: sin(progress * .pi * 4) * (pass ? 0.12 : 0.06), axis: [0, 0, 1])
        }
        if progress >= 0.72 && !pass && state.didPass != nil && !reduceMotion {
            character.position.x += sin(progress * .pi * 16) * 0.04
        }
        let goalProgress = pass ? min(max((eased - 0.10) / 0.90, 0), 1) : 0
        applyGoalPose(progress: goalProgress)
    }

    private func animateMechanisms(time: Float) {
        for (index, mechanism) in mechanisms.enumerated() {
            let id = renderedParts[index]
            switch id {
            case "fan", "wheel":
                mechanism.findEntity(named: "rotor")?.orientation = simd_quatf(angle: time * (id == "fan" ? 14 : 6), axis: [0, 0, 1])
            case "bell":
                mechanism.orientation = simd_quatf(angle: sin(time * 10) * 0.22, axis: [0, 0, 1])
            case "spring": mechanism.scale.y = 0.72 + 0.28 * abs(sin(time * 7))
            case "mirror", "sail":
                mechanism.orientation = simd_quatf(angle: sin(time * 3) * 0.28, axis: [0, 1, 0])
            case "magnet": mechanism.position.y = socketPositions[index].y + 0.22 + sin(time * 6) * 0.04
            case "seed": mechanism.scale = .init(repeating: 0.84 + min(time / 3.15, 1) * 0.22)
            default: break
            }
        }
    }

    private func finishAttempt() {
        guard !completionDelivered, state != nil else { return }
        completionDelivered = true
        restingPosition = character.position
        stopRig()
        let generation = loadGeneration
        let attempt = currentAttempt
        let chapter = renderedChapter
        // Avoid mutating SwiftUI state during updateUIView, including Reduce Motion.
        Task { @MainActor [weak self] in
            guard let self, !self.disposed, self.loadGeneration == generation,
                  self.currentAttempt == attempt, self.renderedChapter == chapter,
                  let currentState = self.state, currentState.attemptID == attempt,
                  currentState.isTesting else { return }
            currentState.onTestFinished()
        }
    }

    private func setParts(_ ids: [String]) {
        renderedParts = ids
        mechanismRoot.children.removeAll()
        mechanisms.removeAll()
        for (index, id) in ids.enumerated() {
            let mechanism: Entity
            if let prototype = prototypes[id] {
                mechanism = prototype.clone(recursive: true)
            } else {
                let prototype = AtelierGeometry.part(id, texture: texture)
                prototypes[id] = prototype
                mechanism = prototype.clone(recursive: true)
            }
            mechanism.position = socketPositions[index] + [0, 0.22, 0]
            mechanism.scale = .init(repeating: 0.76)
            mechanism.name = "socket-\(index)"
            mechanism.components.set(CollisionComponent(shapes: [.generateBox(size: [1.25, 1.6, 1.0])],
                                                         filter: .init(group: Collision.socket, mask: [])))
            mechanismRoot.addChild(mechanism)
            mechanisms.append(mechanism)
        }
    }

    private func makeSockets() {
        let baseMaterial = AtelierGeometry.material(AtelierGeometry.ink, texture: texture)
        for (index, position) in socketPositions.enumerated() {
            let base = AtelierGeometry.model(AtelierGeometry.cylinder(height: 0.38, radius: 0.47), baseMaterial, at: position)
            base.name = "socket-\(index)"
            base.components.set(CollisionComponent(shapes: [.generateBox(size: [0.98, 1.22, 0.94])],
                                                    filter: .init(group: Collision.socket, mask: [])))
            socketRoot.addChild(base)
            let ring = AtelierGeometry.model(AtelierGeometry.ring(radius: 0.43, tubeRadius: 0.028),
                                              AtelierGeometry.material(AtelierGeometry.cobalt), at: position + [0, 0.205, 0])
            ring.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            socketRoot.addChild(ring)
            selectionRings.append(ring)
            let number = AtelierGeometry.model(.generateText("0\(index + 1)", extrusionDepth: 0.001,
                                                               font: .monospacedSystemFont(ofSize: 0.09, weight: .bold)),
                                                AtelierGeometry.material(AtelierGeometry.chalk), at: position + [-0.07, -0.01, 0.46])
            socketRoot.addChild(number)
        }
    }

    private func makeLighting() {
        let key = DirectionalLight()
        key.light.color = UIColor(red: 1, green: 0.93, blue: 0.85, alpha: 1)
        key.light.intensity = 4800
        key.shadow = .init(maximumDistance: 12, depthBias: 1.1)
        key.look(at: .zero, from: [-3, 7, 5], relativeTo: nil)
        anchor.addChild(key)
        let fill = PointLight()
        fill.light.color = AtelierGeometry.lilac
        fill.light.intensity = 550
        fill.light.attenuationRadius = 12
        fill.position = [3, 3.5, 3]
        anchor.addChild(fill)
        let rim = PointLight()
        rim.light.color = AtelierGeometry.coral
        rim.light.intensity = 380
        rim.light.attenuationRadius = 8
        rim.position = [-2, 2.3, -3]
        anchor.addChild(rim)
        let accent = PointLight()
        accent.light.intensity = 100
        accent.light.attenuationRadius = 3
        accent.position = [0.7, 1.8, 0]
        anchor.addChild(accent)
        goalAccent = accent
    }

    private func makeGoal(chapter: Int) {
        goalRoot.children.removeAll()
        goalElements.removeAll()
        goalRoot.position = [0.72, 0.18, -0.30]
        let station = (max(1, chapter) - 1) % 6
        let paints = [AtelierGeometry.acid, AtelierGeometry.lilac, AtelierGeometry.coral,
                      AtelierGeometry.cobalt, AtelierGeometry.acid, AtelierGeometry.lilac]
        goalAccent?.light.color = paints[station]
        let dark = AtelierGeometry.material(AtelierGeometry.ink, texture: texture)
        let white = AtelierGeometry.material(AtelierGeometry.chalk, texture: texture)
        let yellow = AtelierGeometry.material(AtelierGeometry.acid, texture: texture)
        let red = AtelierGeometry.material(AtelierGeometry.coral, texture: texture)
        let blue = AtelierGeometry.material(AtelierGeometry.cobalt, texture: texture)
        let purple = AtelierGeometry.material(AtelierGeometry.lilac, texture: texture)
        @discardableResult
        func add(_ name: String, _ mesh: MeshResource, _ paint: PhysicallyBasedMaterial,
                 at position: SIMD3<Float>, scale: SIMD3<Float> = .one) -> Entity {
            let model = AtelierGeometry.model(mesh, paint, at: position, scale: scale)
            model.name = "goal-\(name)"
            goalRoot.addChild(model); goalElements[name] = model
            return model
        }
        switch station {
        case 0: // A noise crosses a real, visible gap and reaches an envelope-shaped receiver.
            add("sender", AtelierGeometry.ring(radius: 0.19, tubeRadius: 0.055), red,
                at: [-0.76, 0.85, 0])
            add("sender-post", AtelierGeometry.tube([[-0.76, 0.05, 0], [-0.76, 0.65, 0]], radius: 0.045), dark,
                at: .zero)
            add("receiver", .generateBox(size: [0.65, 0.47, 0.18], cornerRadius: 0.055), yellow,
                at: [0.68, 0.84, 0])
            add("mail-fold", AtelierGeometry.tube([[-0.23, 0.14, 0], [0, -0.03, 0.04], [0.23, 0.14, 0]], radius: 0.022), dark,
                at: [0.68, 0.84, 0.11])
            add("receiver-post", AtelierGeometry.tube([[0.68, 0.05, 0], [0.68, 0.58, 0]], radius: 0.045), dark,
                at: .zero)
            for index in 0..<3 {
                add("signal-\(index)", AtelierGeometry.ring(radius: 0.12 + Float(index) * 0.055, tubeRadius: 0.018), white,
                    at: [-0.76, 0.85, 0.08])
            }
            add("delivered", .generateSphere(radius: 0.10), red, at: [0.68, 1.2, 0])
        case 1:
            let moon = Entity(); moon.name = "sleeping-moon"
            goalRoot.addChild(moon); goalElements["moon"] = moon
            moon.addChild(AtelierGeometry.model(.generateSphere(radius: 0.46), purple, scale: [1, 1, 0.58]))
            moon.addChild(AtelierGeometry.model(.generateSphere(radius: 0.10), white,
                                                at: [-0.19, 0.18, 0.22], scale: [1, 0.6, 0.3]))
            let lids = Entity(); moon.addChild(lids); goalElements["lids"] = lids
            let eyes = Entity(); moon.addChild(eyes); goalElements["eyes"] = eyes
            for x: Float in [-0.16, 0.16] {
                lids.addChild(AtelierGeometry.model(AtelierGeometry.ring(radius: 0.075, tubeRadius: 0.017, arc: .pi, start: .pi), dark,
                                                    at: [x, 0.01, 0.255], scale: [1, 0.5, 1]))
                eyes.addChild(AtelierGeometry.model(.generateSphere(radius: 0.04), dark,
                                                    at: [x, 0.02, 0.27], scale: [0.75, 1.4, 0.5]))
            }
            add("pillow", AtelierGeometry.ring(radius: 0.48, tubeRadius: 0.09), red,
                at: [0, 0.17, 0], scale: [1.15, 0.4, 0.85]).orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        case 2:
            add("stem", AtelierGeometry.tube([[0, 0, 0], [-0.09, 0.36, 0], [0.03, 0.73, 0]], radius: 0.048), blue,
                at: [0, 0.07, 0])
            add("flower-pot", AtelierGeometry.lathe([[0, 0], [0.25, 0], [0.35, 0.33], [0.28, 0.33], [0.19, 0.06], [0, 0.06]]), red,
                at: [0, -0.03, 0])
            let flower = Entity(); goalRoot.addChild(flower); goalElements["flower"] = flower
            flower.addChild(AtelierGeometry.model(.generateSphere(radius: 0.13), dark, at: [0, 0, 0.04], scale: [1, 1, 0.65]))
            for index in 0..<6 {
                let petal = AtelierGeometry.model(AtelierGeometry.blade(), index.isMultiple(of: 2) ? yellow : purple,
                                                   scale: [1.15, 0.95, 0.65])
                flower.addChild(petal); goalElements["petal-\(index)"] = petal
            }
            add("leaf", AtelierGeometry.blade(), blue, at: [-0.04, 0.42, 0], scale: [0.8, 0.6, 0.6])
                .orientation = simd_quatf(angle: 1.1, axis: [0, 0, 1])
        case 3:
            let cup = Entity(); goalRoot.addChild(cup); goalElements["cup"] = cup
            cup.addChild(AtelierGeometry.model(AtelierGeometry.lathe([[0, 0], [0.23, 0], [0.34, 0.44], [0.27, 0.44], [0.18, 0.07], [0, 0.07]]), red))
            cup.addChild(AtelierGeometry.model(AtelierGeometry.ring(radius: 0.16, tubeRadius: 0.045, arc: .pi * 1.5, start: -.pi * 0.75), yellow,
                                                at: [0.33, 0.22, 0]))
            makeCloud(at: [0.30, 1.42, 0], material: purple)
            for index in 0..<7 {
                add("rain-\(index)", .generateSphere(radius: 0.035), blue, at: [0, 0.5, 0], scale: [0.7, 1.5, 0.7])
            }
        case 4:
            makeCloud(at: [0.10, 1.38, 0], material: purple)
            var star: [SIMD2<Float>] = []
            for index in 0..<10 {
                let angle = Float(index) * .pi / 5 + .pi / 2
                let radius: Float = index.isMultiple(of: 2) ? 0.24 : 0.10
                star.append([cos(angle) * radius, sin(angle) * radius])
            }
            add("spark", AtelierGeometry.extrude(star, depth: 0.10), yellow, at: [0, 0.25, 0.10])
            for index in 0..<3 {
                add("trail-\(index)", AtelierGeometry.ring(radius: 0.09, tubeRadius: 0.015), red,
                    at: [0, 0.30 + Float(index) * 0.30, 0])
            }
        default:
            goalRoot.position = [0.15, 0.16, -0.05]
            for index in 0..<5 {
                add("stair-\(index)", .generateBox(size: [0.48, 0.18, 0.68], cornerRadius: 0.025), index.isMultiple(of: 2) ? yellow : purple,
                    at: [-0.95 + Float(index) * 0.48, 0.10, 0])
                let wave: [SIMD3<Float>] = (0...20).map { sample in
                    let t = Float(sample) / 20
                    return [-0.19 + t * 0.38, sin(t * .pi * 2) * 0.035, 0]
                }
                add("tide-\(index)", AtelierGeometry.tube(wave, radius: 0.028), blue,
                    at: [-0.95 + Float(index) * 0.48, 0.22, 0.32])
            }
        }
        applyGoalPose(progress: 0)
    }

    private func makeCloud(at position: SIMD3<Float>, material: PhysicallyBasedMaterial) {
        let cloud = Entity(); cloud.position = position
        goalRoot.addChild(cloud); goalElements["cloud"] = cloud
        for (x, y, radius): (Float, Float, Float) in [(-0.32, 0, 0.25), (0, 0.13, 0.34), (0.30, 0.02, 0.24)] {
            cloud.addChild(AtelierGeometry.model(.generateSphere(radius: radius), material,
                                                 at: [x, y, 0], scale: [1, 0.8, 0.70]))
        }
        let halo = AtelierGeometry.model(AtelierGeometry.ring(radius: 0.48, tubeRadius: 0.023),
                                           AtelierGeometry.material(AtelierGeometry.acid), at: [0, 0, -0.10], scale: [1.35, 0.8, 1])
        cloud.addChild(halo); goalElements["cloud-halo"] = halo
    }

    private func applyGoalPose(progress: Float) {
        let station = (max(1, renderedChapter) - 1) % 6
        switch station {
        case 0:
            for index in 0..<3 {
                let wave = goalElements["signal-\(index)"]
                wave?.isEnabled = progress > 0.02
                wave?.position = [-0.76 + progress * 1.44 - Float(index) * 0.07, 0.85, 0.12 + Float(index) * 0.02]
                wave?.scale = .init(repeating: 0.7 + progress * 0.5)
            }
            goalElements["delivered"]?.isEnabled = progress > 0.9
        case 1:
            goalElements["moon"]?.position = [0, 0.68 + progress * 0.64, 0]
            goalElements["moon"]?.orientation = simd_quatf(angle: -0.18 * (1 - progress), axis: [0, 0, 1])
            // This puzzle succeeds by lifting the moon without waking it.
            goalElements["lids"]?.isEnabled = true
            goalElements["eyes"]?.isEnabled = false
        case 2:
            goalElements["stem"]?.scale.y = 0.30 + progress * 0.85
            goalElements["flower"]?.position = [0.03, 0.32 + progress * 0.62, 0]
            goalElements["flower"]?.scale = .init(repeating: 0.35 + progress * 0.65)
            for index in 0..<6 {
                let angle = Float(index) * .pi * 2 / 6
                goalElements["petal-\(index)"]?.orientation = simd_quatf(angle: angle * progress, axis: [0, 0, 1])
            }
        case 3:
            goalElements["cup"]?.position = [-0.12, 0.54, 0]
            goalElements["cup"]?.orientation = simd_quatf(angle: .pi * (1 - min(progress * 2, 1)), axis: [0, 0, 1])
            for index in 0..<7 {
                let t = min(max(progress * 1.4 - 0.28 - Float(index) * 0.035, 0), 1)
                let drop = goalElements["rain-\(index)"]
                drop?.isEnabled = progress > 0.28 && progress < 0.99
                drop?.position = [-0.1 + sin(t * .pi) * 0.32, 0.84 + t * 0.69, 0.10 + Float(index % 2) * 0.03]
            }
            goalElements["cloud-halo"]?.isEnabled = progress > 0.9
        case 4:
            goalElements["spark"]?.position = [0.1, 0.25 + progress * 1.20, 0.14]
            goalElements["spark"]?.orientation = simd_quatf(angle: progress * .pi * 0.4, axis: [0, 0, 1])
            for index in 0..<3 { goalElements["trail-\(index)"]?.isEnabled = progress > Float(index + 1) * 0.2 }
            goalElements["cloud-halo"]?.isEnabled = progress > 0.9
        default:
            for index in 0..<5 {
                let height = progress * Float(index) * 0.22
                goalElements["stair-\(index)"]?.position.y = 0.10 + height
                goalElements["tide-\(index)"]?.position.y = 0.22 + height
            }
        }
    }

    private func makePhysicsRig() {
        // Real physics supplies secondary feedback only; deterministic Core rules decide
        // the puzzle result. One dynamic ball and one kinematic motor stay bounded.
        let floorShape = ShapeResource.generateBox(size: [5.6, 0.12, 3.8])
        let floor = ModelEntity()
        floor.position = [0, 0.10, 0]
        floor.components.set(CollisionComponent(shapes: [floorShape],
                                                 filter: .init(group: Collision.floor, mask: [Collision.marble])))
        floor.components.set(PhysicsBodyComponent(shapes: [floorShape], mass: 1, mode: .static))
        rigRoot.addChild(floor); self.floor = floor
        let marble = AtelierGeometry.model(.generateSphere(radius: 0.09),
                                             AtelierGeometry.material(AtelierGeometry.acid, metallic: 0.4, roughness: 0.26))
        marble.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.09)],
                                                  filter: .init(group: Collision.marble, mask: [Collision.floor, Collision.motor])))
        rigRoot.addChild(marble); self.marble = marble
        let motor = AtelierGeometry.model(.generateBox(size: [0.70, 0.06, 0.12], cornerRadius: 0.03),
                                            AtelierGeometry.material(AtelierGeometry.coral))
        let motorShape = ShapeResource.generateBox(size: [0.70, 0.06, 0.12])
        motor.components.set(CollisionComponent(shapes: [motorShape],
                                                 filter: .init(group: Collision.motor, mask: [Collision.marble])))
        motor.components.set(PhysicsBodyComponent(shapes: [motorShape], mass: 1, mode: .kinematic))
        rigRoot.addChild(motor); self.motor = motor
        resetRig()
    }

    private func resetRig() {
        stopRig()
        marble?.position = [-0.46, 0.60, 0.30]
        marble?.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        motor?.position = [0, 0.38, 0.30]
        motor?.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        marble?.isEnabled = false
        motor?.isEnabled = false
    }

    private func startRig() {
        guard let marble, let motor else { return }
        marble.isEnabled = true; motor.isEnabled = true
        var body = PhysicsBodyComponent(shapes: [.generateSphere(radius: 0.09)], mass: 0.035,
                                        material: .generate(friction: 0.5, restitution: 0.45), mode: .dynamic)
        body.isContinuousCollisionDetectionEnabled = true
        marble.components.set(body)
        marble.components.set(PhysicsMotionComponent(linearVelocity: [0.8, 0, -0.15], angularVelocity: [0, 0, -3]))
        motor.components.set(PhysicsMotionComponent(angularVelocity: [0, 5.5, 0]))
    }

    private func stopRig() {
        marble?.components.remove(PhysicsBodyComponent.self)
        marble?.components.remove(PhysicsMotionComponent.self)
        motor?.components.remove(PhysicsMotionComponent.self)
    }

    private func loadAsset(_ name: String) {
        let generation = loadGeneration
        guard let url = assetURL(name) else {
            failedAssets.insert(name); completedAssetLoads += 1
            return
        }
        // loadAsync is the iOS 17-compatible asynchronous publisher. Newer async
        // Entity initializers require iOS 18; retain cancellation ownership here.
        Entity.loadAsync(contentsOf: url)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, !self.disposed, self.loadGeneration == generation else { return }
                if case .failure = completion { self.failedAssets.insert(name) }
                self.completedAssetLoads += 1
                self.publishAssetNotice()
            }, receiveValue: { [weak self] entity in
                guard let self, !self.disposed, self.loadGeneration == generation else { return }
                self.loadedAssets.insert(name)
                if name == "Loop" {
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let height = bounds.extents.y
                    guard height.isFinite, height > 0.001 else {
                        self.failedAssets.insert(name); return
                    }
                    let scale = 0.95 / height
                    entity.scale *= scale
                    entity.position = [-bounds.center.x * scale, -bounds.min.y * scale, -bounds.center.z * scale]
                    self.character.addChild(entity)
                    self.fallbackCharacter.isEnabled = false
                } else {
                    self.world.addChild(entity)
                    self.fallbackWorld.isEnabled = false
                }
            }).store(in: &assetLoads)
    }

    private func assetURL(_ name: String) -> URL? {
        for subdirectory: String? in ["OddworksAssets", "Resources/OddworksAssets", nil] {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory) { return url }
        }
        return nil
    }

    private func publishAssetNotice() {
        guard let callback = state?.onAssetNotice, completedAssetLoads >= 2 else { return }
        let notice: String?
        if failedAssets.isEmpty { notice = nil }
        else if failedAssets.count == 2 { notice = "3D assets unavailable. Showing the built-in workshop." }
        else if failedAssets.contains("Loop") { notice = "Character asset unavailable. Showing the built-in companion." }
        else { notice = "World asset unavailable. Showing the built-in workshop." }
        guard notice != previousAssetNotice else { return }
        previousAssetNotice = notice
        // Asset state is reported after a view update, not during it.
        let generation = loadGeneration
        Task { @MainActor [weak self] in
            guard let self, !self.disposed, self.loadGeneration == generation else { return }
            callback(notice)
        }
    }

    @objc private func tap(_ recognizer: UITapGestureRecognizer) {
        guard let view, let state, !state.isTesting, isActive else { return }
        guard let hit = view.hitTest(recognizer.location(in: view), query: .nearest, mask: Collision.socket).first else { return }
        var entity: Entity? = hit.entity
        while let current = entity {
            if current.name.hasPrefix("socket-"), let index = Int(current.name.dropFirst(7)), (0..<3).contains(index) {
                state.onSocketTap(index); return
            }
            entity = current.parent
        }
    }

    @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
        guard let view, isActive, !reduceMotion, state?.isTesting != true else { return }
        let translation = recognizer.translation(in: view)
        orbit = min(0.20, max(-0.20, orbit + Float(translation.x) * 0.0012))
        recognizer.setTranslation(.zero, in: view)
        aimCamera()
    }

    private func aimCamera() {
        let angle: Float = 0.48 + orbit
        camera.look(at: [0, 0.76, 0], from: [sin(angle) * 8.7, 4.4, cos(angle) * 8.7], relativeTo: nil)
        camera.orientation *= simd_quatf(angle: -0.025, axis: [0, 0, 1])
    }

    private func makeFallbackStage() {
        // A small authored native stand-in keeps interaction alive if asset loading fails.
        // It is replaced in full when the original bundled Blender environment arrives.
        let blue = AtelierGeometry.material(AtelierGeometry.cobalt, texture: texture)
        let red = AtelierGeometry.material(AtelierGeometry.coral, texture: texture)
        let yellow = AtelierGeometry.material(AtelierGeometry.acid, texture: texture)
        let dark = AtelierGeometry.material(AtelierGeometry.ink, texture: texture)
        let deck = AtelierGeometry.model(.generateBox(size: [5.6, 0.35, 3.4], cornerRadius: 0.15), blue, at: [0, -0.08, 0])
        fallbackWorld.addChild(deck)
        let arch = AtelierGeometry.model(AtelierGeometry.ring(radius: 0.83, tubeRadius: 0.20, arc: .pi, start: 0), red,
                                          at: [0.78, 1.45, -0.85])
        fallbackWorld.addChild(arch)
        for x: Float in [-0.05, 1.61] {
            fallbackWorld.addChild(AtelierGeometry.model(.generateBox(size: [0.40, 1.45, 0.40], cornerRadius: 0.10), red,
                                                         at: [x, 0.72, -0.85]))
        }
        for index in 0..<5 {
            let step = AtelierGeometry.model(.generateBox(size: [0.55, 0.18, 0.65], cornerRadius: 0.04), index.isMultiple(of: 2) ? yellow : dark,
                                               at: [-1.8 + Float(index) * 0.45, 0.28 + Float(index) * 0.18, -0.25])
            fallbackWorld.addChild(step)
        }
    }

    private func makeFallbackCharacter() {
        let blue = AtelierGeometry.material(AtelierGeometry.cobalt, texture: texture)
        let red = AtelierGeometry.material(AtelierGeometry.coral, texture: texture)
        let yellow = AtelierGeometry.material(AtelierGeometry.acid, texture: texture)
        let dark = AtelierGeometry.material(AtelierGeometry.ink)
        let loop = AtelierGeometry.model(AtelierGeometry.ring(radius: 0.29, tubeRadius: 0.12), blue,
                                          at: [0, 0.55, 0], scale: [0.85, 1.2, 1])
        fallbackCharacter.addChild(loop)
        fallbackCharacter.addChild(AtelierGeometry.model(.generateSphere(radius: 0.16), red, at: [0.25, 0.66, 0.03]))
        fallbackCharacter.addChild(AtelierGeometry.model(.generateSphere(radius: 0.07), yellow, at: [-0.16, 0.76, 0.13]))
        fallbackCharacter.addChild(AtelierGeometry.model(.generateSphere(radius: 0.032), dark, at: [-0.16, 0.76, 0.19]))
        for (x, length): (Float, Float) in [(-0.17, 0.27), (0.16, 0.20)] {
            let leg = AtelierGeometry.model(AtelierGeometry.tube([[x, 0.30, 0], [x, 0.08, 0], [x + 0.10, 0.04, 0.10]], radius: 0.052),
                                             x < 0 ? yellow : red, scale: [1, length / 0.27, 1])
            fallbackCharacter.addChild(leg)
        }
    }

    func dismantle() {
        guard !disposed else { return }
        disposed = true
        loadGeneration = UUID()
        updateSubscription?.cancel(); updateSubscription = nil
        assetLoads.forEach { $0.cancel() }; assetLoads.removeAll()
        stopRig()
        for gesture in view?.gestureRecognizers ?? [] { view?.removeGestureRecognizer(gesture) }
        anchor.stopAllAnimations(recursive: true)
        anchor.removeFromParent()
        anchor.children.removeAll()
        world.children.removeAll()
        mechanisms.removeAll(); prototypes.removeAll(); selectionRings.removeAll()
        goalElements.removeAll(); goalAccent = nil
        texture = nil; floor = nil; marble = nil; motor = nil
        state = nil; view = nil
    }
}
