# SpriteKit and on-device idea coaching

Implemented 19 October 2026. The app still supports iOS 17. The Paper Theatre artwork and 24 authored chapters remain the visual and content foundation.

## What players get

Passing ideas now play through a SpriteKit stage. Each of nine action variants has its own finite choreography; the companion reacts, the authored obstacle changes, and small paper scraps move through SpriteKit physics. After the scene resolves, a player can tap to cheer. This interaction has a named VoiceOver action and is never required for progression. SwiftUI continues to present readable narration, scrolling content, and an always-available skip/score button.

Playback pauses when the app becomes inactive. The 4.4-second sequence measures active scene time after atlas preparation, so returning from another app does not skip ahead on a wall-clock timer. Reduce Motion selects the final composition, removes actions and effects, and stops physics. Failed texture preparation falls back to the existing static Canvas artwork with the score button intact.

An eligible iOS 26+ device can also provide a Foundation Models idea coach. The coach identifies a strength, suggests one concrete revision, quotes evidence from the submitted answer, and selects bounded stage cues. The result panel identifies on-device coaching and continues to label the numeric grade as a local practice estimate.

## SpriteKit implementation

`PaperTheatrePlayback` is owned by SwiftUI state and retains one `PaperTheatreScene`. The fixed 600 × 320 stage uses aspect-fit scaling, a world node, a camera, and named depth layers. Existing Canvas drawings are baked into fifteen images in a texture atlas rather than redrawn in every frame. Atlas upload finishes before the finite, keyed actions begin. A generation token prevents a late upload callback from restarting a dismissed stage.

Only the decorative scraps have dynamic physics bodies; action-driven companion and invention sprites do not. Both body construction sites set explicit category, collision, and contact masks. Eighteen preallocated scraps are reused, with an input cooldown, expiry, and offstage cleanup. Teardown removes actions, nodes, pooled effects, joints, textures, and the camera. The scene holds the playback bridge weakly.

Atlas reuse uses a two-entry `NSCache` with a 24 MiB decoded-image cost policy. These are eviction hints, not a measured memory footprint or hard RAM limit. Cold-cache Canvas baking still happens on the main actor; first-presentation time and GPU allocation need device profiling.

In a Debug build, add `-PaperTheatreDiagnostics` to the scheme's launch arguments to display SpriteKit FPS, node count, draw count, and physics outlines. Production builds expose none of these overlays. The host requests 60 FPS during playback and 30 after completion; achieved frame rate has not been measured.

## Why Foundation Models

The requested [Axiom game skill](https://github.com/charleswiltgen/axiom/tree/main/axiom-codex/skills/axiom-games) and [apple-on-device-ai skill](https://github.com/dpearson2699/swift-ios-skills/tree/main/skills/apple-on-device-ai) were installed for Codex and applied during implementation. The latter routes between inference backends according to the feature. Short structured coaching fits Apple's built-in Foundation Models runtime. There is no custom trained model to convert with Core ML and no need to bundle MLX Swift or llama.cpp and a separate model download for this feature.

The implementation uses APIs in the installed iOS 26.5 SDK, with availability gates around Foundation Models and its iOS 26.4 token-counting APIs. It does not depend on future SDK patterns mentioned in broader skill documentation. See Apple's documentation for [Foundation Models generation](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) and [hosting SpriteKit in SwiftUI](https://developer.apple.com/documentation/spritekit/drawing-spritekit-content-in-a-view).

## Coaching boundaries and fallback

- Check actual model availability and English-language support before prewarming or submitting. Unsupported devices and model assets that are not ready use existing practice feedback.
- Use a fresh transcript for each attempt. The prompt contains only that challenge's goal, constraint, and complete submitted answer. No journal or previous answer is sent to the device model. The local path makes no network request and needs no credentials.
- Treat the answer as untrusted data. Stable instructions request a compact structured response with constrained action/color choices. Validation requires evidence and object phrases to occur in the submitted answer, bounds field lengths, and rejects common grade, reward, or completion claims. These checks cannot prove every coaching statement is correct; model quality still needs playtesting.
- Skip long inputs rather than truncate away a player's mechanism. On iOS 26.4+, budget prompt, instructions, generation schema, and response space using actual token counts. Earlier iOS 26 versions use a conservative character limit.
- Return control after an eight-second deadline, cancellation, refusal, invalid output, or generation error. A timed-out inference retains its exclusive coordinator slot until it exits, preventing overlapping model work. Leaving the foreground releases an unused prewarmed session and cancels pending coaching.
- Give this coach no numeric grade, pass, reward, or progression fields. `PracticeChallengeEvaluator` and the existing level gate still decide local results. Rejected coaching changes none of those decisions. Saves, journal entries, and shared practice scores retain their estimate label.

The existing explicitly configured Anthropic test path remains separate and takes precedence when it returns a result. Unlike the device-local path, it sends the answer and recent story context remotely. If that path is unavailable, local practice grading and optional local coaching remain usable.

## Validation and remaining checks

All 74 Core tests pass, including eight new output-validation tests. The full production app compiles and links for an iOS 17 simulator deployment target against the installed iOS 26.5 SDK, including the Foundation Models macro and SpriteKit sources. XcodeGen regenerates the project successfully.

A separate native harness using production AppState and services, with device inference disabled, verifies draft persistence, failed/repeated reward protection, immediate chapter progression, day-based streaks, late-level practice gates, archive/relaunch behavior, and the input boundary. The scene harness runs production drawing, host, and SpriteKit code against the macOS SDK. It verifies successful rasterisation, stable scene ownership, explicit masks, the eighteen-node pool, all nine variants' setup and final state, Reduce Motion, teardown, and deallocation. The [Axiom audit](SPRITEKIT_AUDIT.md) records these checks and the seventy-three source-pattern searches.

No iOS simulator or physical-device gameplay was executed for this update. The native lifecycle harness does not establish iOS touch dispatch, action playback timing, physical trajectories, frame rate, draw calls, memory, or energy. No real Foundation Models generation was run. Before release, test an eligible iPhone and an older supported device: model readiness and timeout behavior, coaching relevance and adversarial answers, cold-cache staging, repeated transitions and cheers, background/resume, Reduce Motion during preload, VoiceOver, keyboard layouts, and large Dynamic Type.
