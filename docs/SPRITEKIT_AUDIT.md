# SpriteKit Audit Results

Date: 19 October 2026. Scope: the new Paper Theatre SpriteKit scene and its SwiftUI host in Crearo. This is a source audit plus native macOS lifecycle execution, not a device frame-rate benchmark.

## SpriteKit Map

- One `SKScene` subclass, `PaperTheatreScene`, stages the existing authored paper art as a finite invention vignette.
- No custom `SKNode` or `SKSpriteNode` subclasses own touch handling. The scene handles touches in scene coordinates; SwiftUI supplies an equivalent named accessibility action.
- One fixed world node and one fixed camera contain five visual sprites with named z layers. Native SwiftUI narration and score controls sit outside SpriteKit.
- `PhysicsCategory` names `none`, `scrap`, and `ground`; both physics-body construction sites assign category, collision, and contact-test masks explicitly.
- Only the decorative paper scraps use dynamic physics. Invention and companion choreography uses actions on sprites without physics bodies.
- Zero repeating actions. Three `SKAction.run` closures capture the scene weakly; every running sequence has an action key.
- The scene preallocates eighteen scraps. Input draws from that pool, uses a cooldown and one keyed companion reaction, and never allocates a new sprite per tap.
- Fifteen rasterised images form one `SKTextureAtlas`; the atlas preloads before timed playback. A two-entry, 24 MiB decoded-cost `NSCache` provides reuse hints.
- `SpriteView` retains the state-owned playback scene, pauses outside the active app phase, and has FPS, node-count, draw-count, and physics overlays behind both `#if DEBUG` and a launch argument.

## Summary

- CRITICAL: 0 open issues
- HIGH: 0 open issues
- MEDIUM: 0 open issues
- LOW: 0 open issues
- Phase 2 pattern detection: 0 open issues
- Phase 3 completeness reasoning: 0 open defects established by this audit
- Phase 4 compound findings: 0 open issues

An early texture-factory defect was caught and fixed during review: fifteen generated images were compared with a required count of sixteen. The final code validates the exact required key set instead. The native harness asserts that ordinary staging succeeds without entering the static fallback.

## SpriteKit Health Score

| Metric | Evidence |
|---|---|
| Scene count | 1 `SKScene` subclass |
| Physics-category discipline | Named constants on both body construction sites; no default or all-bits masks |
| Add/remove balance | 5 `addChild` call sites, 2 `removeFromParent` call sites, 2 bulk-child cleanup sites; pool reuse and teardown account for the apparent static imbalance |
| Action-capture discipline | 3 of 3 scene-capturing action callbacks use `[weak self]`; preload and its main-actor task also capture weakly |
| Infinite actions | 0 |
| Atlas adoption | All scene gameplay artwork uses the generated atlas; no `SKShapeNode` or `imageNamed:` calls |
| Object pooling | 18 preallocated scrap nodes; no allocation in input, update, or scatter paths |
| Debug-overlay gating | `#if DEBUG` plus `-PaperTheatreDiagnostics` launch argument |
| Time-step clamping | Local expiry-clock delta bounded to 1/30 second; SpriteKit owns action and physics advancement |
| **Health** | **PERFORMANT under the auditor's source-pattern rubric; actual device performance remains unmeasured** |

`NSCache` count and cost limits are eviction policies, not hard process-memory limits. Decoded image cost excludes atlas packing, GPU allocation, framework overhead, and temporarily live scenes. This audit does not claim a measured 24 MiB app footprint.

## Verified Source Properties

All paths below are repository-relative.

- **Physics:** `CrearoApp/Features/Daily/PaperTheatreScene.swift:143` assigns the static floor to ground, colliding only with scraps, with contacts disabled. The pool setup at line 312 assigns scraps to the reciprocal collision category, also with contacts disabled, and enables precise collision detection. No contact delegate is needed because no gameplay uses contact callbacks.
- **Ownership:** the scene's bridge reference is weak at line 59. The playback owns one scene, and `CutSceneView.swift:28` keeps the playback in SwiftUI state. The body passes that scene into `SpriteView` rather than constructing a scene in the render expression.
- **Finite playback:** keyed actions at scene lines 157–177 and 237–253 contain finite movement, reveal, resolve, and completion sequences. No repeating action or timer was found.
- **Bounded effects:** the pool at line 312 contains eighteen nodes. Scatter consumes only available nodes at line 334, expiry/offstage cleanup returns them at lines 353–378, and the tap reaction at lines 290–300 is cooldown- and action-key-gated. The maximum attached descendant count implied by this graph is 26, excluding the `SKScene` itself.
- **Coordinates:** the iOS touch handler at line 304 uses `touch.location(in: self)` and checks scene bounds. The fixed aspect-fit camera has no moving HUD problem because controls live in SwiftUI.
- **Interruption and teardown:** `CutSceneView.swift:67` pauses the view outside the active scene phase. `tearDown()` at scene line 381 changes the stage generation token, removes scene/child actions and children, empties the pool, clears textures, removes joints and camera, and marks the stage inactive. `willMove(from:)` and SwiftUI disappearance both invoke cleanup.
- **Late work:** the preload callback at line 133 captures weakly, returns to the main actor, and requires a matching stage generation plus an active, non-reduced stage. A dismissed or replaced stage cannot restart from an old preload callback.
- **Reduce Motion:** `showFinalState()` at line 256 cancels actions, recycles effects, removes the floor, stops physics, and selects final textures and poses. Reduce Motion changes in the host invoke it immediately. The skip-to-score button is available throughout playback.
- **Assets:** the factory at lines 434–484 bakes fifteen fixed-size images once on a cache miss, validates all keys, and caches the atlas with decoded-byte cost. No rasterisation, inference, or texture creation occurs in `update(_:)`.
- **Fallback:** if textures cannot be prepared, the host renders the authored static Canvas stage and keeps the score action available.
- **Diagnostics:** `CutSceneView.swift:122` supplies FPS, node-count, draw-count, and physics overlays only in a Debug build with the explicit launch argument. Release returns an empty option set.

## Native Lifecycle Validation

The scratch harness compiled the actual production `Theme.swift`, `PaperTheatreArtwork.swift`, `CutSceneView.swift`, and `PaperTheatreScene.swift` against the local macOS SpriteKit/SwiftUI SDK and the existing Core module. It did not replace production scene methods with test stubs.

Assertions passed:

1. A normal stage successfully rasterises, avoids the fallback, creates two root children and eight total descendants, and preallocates eighteen scraps.
2. Calling `start` a second time retains scene identity and does not duplicate the graph.
3. Every preallocated scrap and the floor have the intended explicit category, collision, and contact masks. Scraps enable precise collision detection.
4. Restaging each of nine action variants creates the same initial node budget and pool size.
5. Selecting the final state removes all scene/child actions and attached physics bodies. Physics speed is zero.
6. Two hundred celebration calls after Reduce Motion creates no effects or additional nodes.
7. Teardown empties the child graph and pool and clears the camera.
8. A stopped playback and its scene deallocate when their owning scope ends.

The harness intentionally did not present an iOS `SKView`. It therefore does not establish actual touch dispatch, automatic action completion timing, running physics trajectories, GPU draw-call counts, frame rate, energy use, or long-session memory behavior. The reported nine-variant checks cover setup, final state, and cleanup; they are not playback videos.

## Method

The full installed `axiom-audit-spritekit/SKILL.md` was read before scanning. The Swift inventory excluded test, preview, vendor, build, scratch, and documentation paths. Every specified grep pattern was run individually rather than merged into a mega-regex. Supplemental searches covered Swift's shorthand `.run` actions, `override func update`, preload, pause state, teardown, action removal, and SwiftUI state ownership. All matching scene/host contexts were read before a finding was accepted. Seventy-three individual patterns were executed against the final implementation; transient process-tool failures were retried successfully.

The eight mandatory checks covered explicit physics masks, draw-call waste, node accumulation, action retention, coordinate confusion, custom-node input enablement, hot-spawn pooling, and development overlays. Completeness review also covered asynchronous asset readiness, scene transitions, interruption clocks, fixed-camera layering, precise collision detection, and late async callbacks. No compound critical pattern remained.

## Recommendations

1. Run a Debug iPhone build with `-PaperTheatreDiagnostics` and record draw/node counts during all regions, all actions, repeated celebrations, and repeated scene transitions. The pool should never exceed eighteen scraps, and closed scenes should disappear from the memory graph.
2. Profile cold-cache staging separately from steady playback. Canvas baking still occurs on the main actor before asynchronous atlas upload. The cache and bounded image sizes reduce repeated work, but first-presentation duration has not been measured on an older supported iPhone.
3. Test active → inactive → background → active transitions mid-vignette and mid-celebration, including toggling Reduce Motion before preload completes. Confirm that score progression remains available and no stale stage restarts.
4. Use Instruments on a physical device for frame pacing, allocations, energy, and scene deallocation. Validate actual iOS VoiceOver activation, touch positioning, and dynamic-type layouts; a source audit cannot substitute for those checks.
