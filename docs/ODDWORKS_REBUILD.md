# Oddworks rebuild — 19 October 2026

The requested direction is **surreal graphic worlds with bold shapes, unusual characters and sharp typography**, combining short writing challenges with hands-on puzzles. This update changes the app's launch flow, art, renderer, interaction, scoring and progression. It keeps the Crearo identity and the player's earlier saved writing.

## Game surface

RootView now opens AtelierView. The scene is the focal point, followed by a numbered three-role construction rack. Players choose objects, change their roles, see authored rule totals, write one short explanation, and test. Results show a score, specific rule checks, the player's theory, sharing, and immediate continuation. The station index and invention collection are separate sheets and cannot interrupt a running test to compete with its result presentation.

The six stations use different goals, constraints and staged outcomes. All have multiple solutions, with role assignments changing object contributions. The finite collection offers replay after completion rather than secretly recycling content as new levels. Local scores compare visible toy rules, not global novelty or semantic quality. Explanation scoring checks completion only; it does not reward length or claim to understand an arbitrary mechanism.

## Models and renderer

Loop.usdz and StrangeAtelier.usdz contain original Blender geometry and UV-painted pigment textures. Editable source and scripts live under art/Oddworks. Standard USD preview materials contain their dependencies, so no Blender procedural node graph or external service is required at runtime. The character has 10,716 triangles; the shared architecture has 16,392. Seven static material batches reduce the world graph, but do not establish a measured draw-call count.

AtelierSceneView hosts RealityKit's non-AR view through UIViewRepresentable. Its coordinator owns the scene, camera, mechanism prototypes, lighting, socket hit regions and bounded physics objects. SwiftUI changes selection and attempt state without rebuilding the scene in body. The eight mechanisms use custom UV-mapped lathe, tube, helix, curved sail and propeller geometry. Runtime goal sculptures distinguish the stations; the Blender architecture is their shared setting.

Selected mechanisms assemble into sockets. Scene-time choreography demonstrates the result selected by the deterministic evaluator. It does not run a general physical or natural-language solver. Dynamic physics is limited to a reusable marble and its deliberate motor/floor interaction; other animation uses controlled transforms. Tests can always be skipped to their actual result. Native role/object controls provide an alternative to 3D taps and camera gestures.

Subscription ownership, bounded arrays, explicit collision groups, delta clamping, generation-guarded asset loading and teardown follow the requested RealityKit guidance. Backgrounding pauses work; Reduce Motion suppresses large movement while retaining results. The renderer supports iOS 17. RealityView and orthographic cameras would require iOS 18, so they are not used. A custom Metal renderer is unnecessary for this scene; RealityKit supplies the GPU rendering pipeline.

## Tools and skills

Piemonte's [RealityKit](https://github.com/piemonte/skills/tree/main/realitykit-visionos) and [Metal](https://github.com/piemonte/skills/tree/main/metal-graphics) guides were read and applied to rendering, ownership and resource decisions. Their SKILL.md files are installed in Codex; optional nested Codex agent metadata was not copied because this environment protects those configuration directories. Existing Axiom guidance and the newly installed Core ML skill were also inspected. No untrained Core ML model, MLX runtime or paid generation API was added merely to increase framework count.

The thiennc repository now redirects to [thienqo/ios-skills](https://github.com/thienqo/ios-skills). Its actual GameKit and SpriteKit specialists were installed in the task's skill workspace for inspection; a single ios-gaming-skills folder should not be assumed. Game Center requires real capabilities, identifiers and authentication, so this build uses native sharing rather than a fabricated leaderboard. The visionOS-specific pack was inspected as a possible later target; this build is an iPhone/iPad game.

Blender MCP was not connected to this running Codex session. Original models were built with verified official Blender locally, through its headless Python interface. The official MCP source now lives at [ahujasid/mcp-for-blender](https://github.com/ahujasid/mcp-for-blender); its add-on and server can expose the same authoring operations in a configured future session. No Meshy, Tripo, Rodin, Hunyuan or other cloud model service was used. See the [art README](../art/Oddworks/README.md) for the reproducible route, tool checksums and validation details.

## Persistence

ContraptionSave has an explicit version, canonical station identifiers, per-station drafts, best scores and a bounded journal. Recording recomputes the result against the canonical challenge and submitted construction before advancing. A completed station can improve its best without unlocking progress repeatedly. AtelierSaveStore serializes writes and uses atomic file replacement. Full over-limit text remains editable; submission rejects it rather than grading a prefix.

The new file is separate from existing AppState storage. Old invention history and earlier narrative pages are displayed in the collection. An unreadable/newer workshop save is never silently overwritten by a fresh empty game. File errors give a visible notice while preserving the affected file.

## Evidence and limits

All 90 Core tests pass. New tests cover two authored passing constructions per station, all 2,016 ordered recipes, missing/duplicate objects, role consequences, constraints, the exact 600/601-character boundary, honest explanation completion, save decoding, replay behavior, canonical-result verification and journal limits.

A separate native harness compiles production AtelierGameModel and AtelierSaveStore with the actual Core module. Its 34 checks exercise selection/swap/toggle, loading guards, frozen attempts, failed drafts, single clears, duplicate callbacks, replay, next station, relaunch, rapid/interleaved/debounced/background writes, over-limit text retention, unknown/unreadable saves and write failures. No model or store logic is replaced with a test stub.

Full app Swift source compiles and links with an iOS 17 target against the installed iOS 26.5 simulator SDK. XcodeGen regenerates the project and places both USDZ packages in Resources. Apple strict USD/ARKit validation accepts both models; Blender reimports and renders the exact packages. Those checks verify content and source, not actual iOS GPU behavior. The [scene review](ODDWORKS_SCENE_REVIEW.md) records the final renderer fixes and remaining device checks.

CoreSimulator services and Xcode's normal manifest cache are blocked in this environment; a complete Xcode build and app launch have not been established. UI previews use native SwiftUI source rendering with a Blender asset still replacing the GPU viewport. They are not device screenshots or live RealityKit recordings. Validate actual camera composition, shadows, hit testing, physics, every station's successful/failed animation, interruption recovery, Reduce Motion, VoiceOver, Dynamic Type, keyboards, memory, thermals and frame pacing on supported physical devices before release.
