# Crearo: feasible native 3D redesign

Research checked October 19, 2026 against primary Apple documentation, source repository READMEs, and the installed iPhoneSimulator 26.5 Swift interfaces. This is an implementation recommendation, not a measured performance result.

## Recommended architecture

Use **RealityKit for a richly lit miniature workshop**, with SwiftUI for readable controls and the existing deterministic game/progression model. A fixed three-quarter camera, substantial beveled silhouettes, wood/ceramic/brass material distinctions, and a small number of directly selectable objects would create an identifiable visual language. Those art decisions are an inference from the capabilities below, not an Apple claim that a particular art style improves retention.

For the existing iOS 17 deployment target, host `ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)` in `UIViewRepresentable`. Use a `PerspectiveCamera` under a world anchor; this is a virtual scene and does not need to start an AR camera session. Avoid increasing the minimum OS just to embed 3D. Apple's [ARView reference](https://developer.apple.com/documentation/realitykit/arview) and [PerspectiveCamera reference](https://developer.apple.com/documentation/realitykit/perspectivecamera) explicitly support this rendering arrangement.

Keep one coordinator-owned scene per visible workshop rather than reconstructing entities in every SwiftUI update. Cache shared mesh/material resources, update only changed properties, cancel scene subscriptions and animations on dismantle, and stop work while inactive. Keep movement controlled by a single system: kinematic animation for the staged puzzle, dynamic physics only for deliberately simulated loose objects. Do not promise 60 fps until it has been measured on supported iPhones.

## What can materially change the appearance

| Technology | Practical use in Crearo | Availability verified in local SDK |
|---|---|---|
| `PhysicallyBasedMaterial` | Separate base color, roughness, metallic, normal and ambient-occlusion textures; use clearcoat selectively for enamel. Texture roughness matters more than a generic glossy finish. | iOS 15+ |
| `MeshDescriptor` and `MeshResource.generate(from:)` | Author original rounded structures, curved handles, asymmetrical silhouettes and properly UV-mapped parts instead of stacking unmodified primitives. Mesh descriptors support positions, normals and UVs. | iOS 15+ |
| `DirectionalLight`, `PointLight`, shadow component | One warm key with a restrained cool fill; explicit shadow support for depth and contact. Keep the scene compact and shadow distance tight. | Core APIs iOS 13+ |
| `CustomMaterial` with Metal surface shader | Optional subtle ceramic mottling, wood grain or tool highlight in the existing RealityKit lighting pipeline. A PBR material fallback should remain available when the custom library fails to load. | iOS 15+; **unavailable on visionOS** |
| SwiftUI `sensoryFeedback` | A discrete selection tick, action confirmation and result feedback tied to state changes. | iOS 17+ |
| SwiftUI accessibility actions | Expose the same object selection and puzzle operations as named actions/buttons, in addition to direct 3D taps. | Fits iOS 17 |

Primary references: [PBR material](https://developer.apple.com/documentation/realitykit/physicallybasedmaterial), [mesh descriptors](https://developer.apple.com/documentation/realitykit/meshdescriptor), [directional light](https://developer.apple.com/documentation/realitykit/directionallight), [custom Metal materials](https://developer.apple.com/documentation/realitykit/modifying-realitykit-rendering-using-custom-materials), [sensory feedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)), [accessibility actions](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(_:_:)).

The old 2D theatre can remain a fallback or be retired; adopting RealityKit does not itself require SpriteKit to participate in every screen. A full custom Metal renderer would add camera, lighting, resource and rendering ownership work that RealityKit already supplies. Start with RealityKit and use a small Metal material only where the visual result justifies it.

## API traps to avoid

- **`RealityView` and `OrthographicCameraComponent` require iOS 18.** They are real APIs in the installed SDK, but they cannot be used unconditionally in this iOS 17 app. Use a farther perspective camera with a restrained field of view for a miniature/isometric impression.
- The installed SDK supports PBR/mesh/custom material work without OS 27 features. Current Apple webpages sometimes include OS 27 portal helpers, render layers and light controls. Do not copy those into an iOS 17 implementation.
- Custom material geometry displacement changes rendering, not collision shapes. If a shader changes the silhouette beyond its original bounds, adjust bounds and do not assume physics matches it. [Apple's custom material guidance](https://developer.apple.com/documentation/realitykit/modifying-realitykit-rendering-using-custom-materials)
- Transparent material behavior differs across older OS versions and apps built against iOS 18+. Set blending explicitly and test intended opacity, rather than relying only on tint alpha. [iOS 18 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-18-release-notes)
- Use only public APIs. The Swift interfaces include many `__` implementation members; they are evidence to avoid, not a supported frame-rate-control surface.

## UI and game feel

Apple recommends direct object interaction when it reduces on-screen controls, comfortable thumb placement, visible/tactile press states, and at least 44 × 44 pt for frequently used controls. Apply that as a full-width workshop with one clear task and a compact tool tray, rather than a dashboard of equally weighted cards. [Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls)

Use brief, precise feedback: selection visibly raises or outlines the object, choosing a mechanism assembles it, and testing produces an understandable consequence. Keep camera movement optional. Reduce Motion should disable orbit/sway and large 3D transitions; progress must still be readable in text. [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Reduce Motion API](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), [designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games)

Dynamic Type, named object actions, accessible task text and an explicit test button should remain SwiftUI elements. Visual objects should have sufficiently large hit regions. Never make color, a hidden drag gesture, a camera orbit or animation the only way to solve a puzzle.

## Social technology

`GameKit` can support friends/global score comparison with classic or recurring leaderboards. It requires Game Center capability, player authentication, and real configured leaderboard identifiers; adding framework code alone does not create a working service. For Crearo, a shared daily challenge with a known ruleset is a better comparison unit than arbitrary AI-assigned creativity grades. Retain transparent practice-score labels and do not post unvalidated model judgments as competitive results. [GameKit](https://developer.apple.com/documentation/gamekit), [recurring leaderboards](https://developer.apple.com/documentation/gamekit/creating-recurring-leaderboards)

## Requested skill packs: what was verified

- **[piemonte/skills](https://github.com/piemonte/skills)** explicitly documents Codex installation. Its actual relevant source directories are root-level [`realitykit-visionos`](https://github.com/piemonte/skills/tree/main/realitykit-visionos) and [`metal-graphics`](https://github.com/piemonte/skills/tree/main/metal-graphics), each with `SKILL.md`. The README's Codex method is cloning to `~/.codex/piemonte-skills` and symlinking selected skills into `~/.agents/skills`. `te-shader` is for GLSL shaders in a Java LED-art environment; it should not be treated as an iOS Metal/RealityKit shader skill. The collection is MIT licensed.
- **[thiennc-tesoglobal/ios-skills](https://github.com/thiennc-tesoglobal/ios-skills)** currently redirects to [`thienqo/ios-skills`](https://github.com/thienqo/ios-skills). The primary README describes focused `SKILL.md` specialist guidance and supports direct `npx skills add …` installation. Its published counts differ between page metadata and README, so do not assume exactly 89 skills. It advises one workflow skill and only necessary specialists. This browsing pass did not successfully retrieve the gaming bundle's manifest or every specialist folder; inspect the repository checkout before installing exact paths. Do not infer Codex compatibility of a Claude bundle command from its name.
- Existing **Axiom** is a router. RealityKit details route to the separate `axiom-graphics` suite; its already installed SpriteKit guidance does not automatically install those files. Its OS 27 sections also need availability checks.
- A visionOS-specific pack is not needed merely to ship an iPhone game. RealityKit's iOS `CustomMaterial` API is explicitly unavailable on visionOS, and a later Vision Pro port would need its own material/input decisions.

## Verification boundary

Compile against the installed SDK with an iOS 17 target. Measure rendered results, hit testing, shader loading, lighting, memory, thermals, frame pacing and background/foreground recovery on a physical supported iPhone. Apple's performance guidance calls for CPU/GPU diagnosis and scalable texture, mesh, material, shadow and post-processing complexity; source review is insufficient to establish smoothness. [RealityKit performance](https://developer.apple.com/documentation/realitykit/improving-the-performance-of-a-realitykit-app)

No app files, skills, global configuration, external accounts or publishing state were changed by this research task.
