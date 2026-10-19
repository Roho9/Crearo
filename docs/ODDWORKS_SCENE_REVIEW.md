# Oddworks RealityKit scene review

Reviewed October 19, 2026: production `AtelierSceneView.swift` and `AtelierGeometry.swift`, using the installed `realitykit-visionos` skill.

## Corrections made

- The sleeping-moon puzzle now keeps closed eyelids throughout its successful lift. Its completed pose previously opened its eyes, contradicting the goal of keeping the moon asleep.
- Deferred completion now checks chapter, current attempt, current testing state and disposal generation before calling the current completion closure. A queued callback cannot finish a superseded chapter or attempt.

## Review results

- iOS 17 uses a non-AR `ARView`; it does not configure an AR session or request camera access. Two bundled USDZ assets load asynchronously with owned cancellables, weak captures and disposal-generation checks. Native world and character fallbacks remain available on load failure, with a visible notice.
- The scene graph and effect rig are bounded. Only one dynamic marble and one kinematic motor are simulated. Explicit collision groups restrict sockets to hit testing and restrict physics interactions to the marble, floor and motor. Animated character/mechanism/goal transforms do not fight dynamic physics bodies.
- The update subscription is retained, cancelled when inactive or Reduce Motion is enabled, and cancelled again at teardown. Backgrounding disables the world; elapsed scene time resumes using a clamped frame delta. No wall-clock completion timer, repeating action, detached loader or per-frame mesh/texture generation appears in these files.
- Reduce Motion removes the update subscription and physics motion, displays the final test pose directly and defers completion safely. Numbered SwiftUI controls provide an accessible equivalent for selecting scene sockets.
- Six goal variants visibly express their authored results: message transfer, a sleeping moon lift, flower growth, reverse rain, spark delivery and rising tide stairs. The renderer consumes the Core evaluator's result; physics supplies secondary feedback and does not award passes or scores. Failed tests retain the unresolved goal pose.
- Teardown cancels asset loads and updates, invalidates queued callbacks, stops animation/physics, removes gestures and the scene anchor, and releases coordinator caches and references. Renderer-owned procedural meshes and the 256-pixel paint texture are created outside the frame callback.

## Validation and limits

The final two renderer sources typecheck successfully for `arm64-apple-ios17.0-simulator` against the installed iPhoneSimulator 26.5 SDK. Diagnostic log is empty: `work/oddworks-verify/renderer-review-compile.log`. Whitespace validation passes.

This is a source and compiler review, not an iPhone GPU run. Actual frame rate, draw calls, shadows, touch hit testing, projected legibility, asset loading latency, physics trajectories, memory pressure and energy use still require device profiling. The three-second sequence is bounded by scene time; no claim is made about measured performance or physical simulation determining puzzle success.
