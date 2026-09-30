# Crearo: Paper Theatre design decisions

Research reviewed September 30, 2026. This is the current visual and interaction direction: a small, tactile paper world where a player invents solutions, sees a creativity score out of 100, and progresses through challenges. It supersedes older design proposals that hide all scores. The research supports hypotheses to test; it does not establish that this implementation improves retention or trains creativity.

## What the evidence says

| Evidence | Decision for Crearo | Limit |
| --- | --- | --- |
| Attractive interfaces can seem easier to use even when interaction problems remain. [NN/g: aesthetic–usability effect](https://www.nngroup.com/articles/aesthetic-usability-effect/) | Give the game a coherent material identity, then observe task completion separately from appearance ratings. | Attractive screens do not prove usability. |
| Scale, contrast, spacing and grouping establish the order in which information is read. [NN/g: visual design principles](https://www.nngroup.com/articles/principles-visual-design/) | Make the scene and current challenge dominant; place the answer field and one primary action together. Keep level information nearby and secondary systems quieter. | These are design principles, not evidence that a particular palette is universally preferred. |
| In four original studies, in-game autonomy and competence were associated with enjoyment; relatedness also predicted enjoyment and future play in the multiplayer study. [Ryan, Rigby & Przybylski, 2006](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf) | Allow different sensible solutions. Explain scores with usable reasons, preserve an answer for revision, and make personal improvement visible. Later, let friends exchange inventions and compare the same challenge. | The authors note limits of assigned laboratory play, sampled genres and new measures. This is not a guarantee for a creativity game. |
| A study of 3,018 players compared four feedback levels in an action RPG. Medium/high feedback performed better than none/extreme on player experience and several other measures. [Kao, 2020](https://www.sciencedirect.com/science/article/pii/S1875952118300879) | Use restrained tactile responses and a stronger, brief success reaction. Let texture carry the identity while idle movement stays subtle. | Findings from one action RPG cannot specify the ideal effect strength for Crearo. |
| A preregistered experiment with 1,699 players found benefits from success-dependent feedback. Amplification reduced the measured motives in the tested implementation; the authors highlight clear action–outcome links. [Kao et al., CHI 2024](https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf) | The player must understand what their idea changed. Distinguish submitting, receiving a judgment, solving the challenge and unlocking a level. Reserve major celebration for actual success. | The study used a dedicated action RPG and particular feedback implementations. It does not justify random surprise rewards. |
| Apple recommends purposeful, brief feedback, optional motion and interactions that do not wait unnecessarily for animations. [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion?changes=l_9_3) | Tie paper movement to actions. Keep navigation available during decorative reactions and support Reduce Motion. | Platform guidance is a practical constraint, not a controlled enjoyment study. |
| Apple identifies depth simulation, spinning and ongoing motion as potential discomfort triggers. [Apple: Reduced Motion evaluation](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/) | With Reduce Motion enabled, stop parallax and bobbing; use static scene states and short opacity transitions. Keep textual status and score feedback. | Check every important flow with the setting enabled. |
| WCAG specifies text contrast of at least 4.5:1, or 3:1 for qualifying large text. [W3C: Contrast minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) | Keep texture faint behind copy, measure final color pairs and give all actionable text adequate contrast. | Web criteria are a useful baseline; applying these alone does not establish full native-app accessibility. |

## Original art direction

The following choices are Crearo design hypotheses, not findings from the cited studies.

- **Material:** warm paper stock, visible fibers, sparse print speckles, soft edge shadows and a small amount of ink misregistration. Use distinct material scales: large collage shapes in the landscape, fine grain on paper, and calm surfaces beneath text.
- **Shape language:** silhouettes with deliberate asymmetry, simple folds, rounded scissor cuts and layers that appear to have thickness. Keep characters readable at small sizes. Paper Theatre is more than beige rectangles: each region needs its own silhouettes, palette and props.
- **Palette:** cream and dark ink anchor the UI; indigo, coral, moss and ochre provide restrained accents. Limit saturated accents to current actions, important scene props and clear state changes.
- **Composition:** frame each challenge like a small stage. Give the central problem space to breathe. Keep progress readable without putting a dashboard between the player and the world.
- **Texture discipline:** use deterministic, reusable patterns. Avoid an animated full-screen grain layer, heavy noise behind small text, or a different visual style on every card.
- **Character:** the companion should react to relevant events with a fold, glance or lean. It should have a recognizable silhouette and personality rather than constant unrelated bouncing.

## Interaction and motion contract

Timing ranges below are starting values for implementation and playtesting, not research-derived thresholds.

| Event | Response | Starting timing |
| --- | --- | --- |
| Press an action | Small paper compression and shadow change; the state updates immediately | 100–160 ms |
| Open a panel | A short eased reveal from its source; keep placement consistent | 180–260 ms |
| Submit an idea | Preserve text, show an explicit evaluation status, prevent duplicate submission | Immediate state change |
| Receive a result | Show final score and explanation; a brief accent may draw attention | 250–450 ms accent |
| Clear a challenge | Scene becomes visibly repaired or changed, companion responds, next action becomes available | 450–800 ms optional flourish |
| Need another attempt | One specific suggestion and a clear revision action; keep the previous answer | No failure spectacle |

Use eased continuous motion for major movement, with small secondary paper bends rather than stepped position jumps. Animate transforms and opacity where practical. Avoid re-randomizing texture while a scene animates. Under Reduce Motion, preserve the same outcomes without translation, scaling, parallax, spinning or decorative loops. Never communicate a pass solely through movement, color or sound.

### Implemented and checked

The opening, challenge, result, journal and progress screens now share the paper palette and surfaces. The hand-authored stage has ten obstacle archetypes and eight invention silhouettes. Passing scenes use a finite 4.4-second action sequence with a skip button available throughout; Reduce Motion presents the final state. Failed attempts go directly to feedback and keep the draft available for revision. Preview texture remains static, with only a restrained companion idle animation during active use.

The solid foreground/background color pairs were calculated using the WCAG relative-luminance formula. Ink on the page is 10.18:1, secondary text is 5.03:1, and white text on the primary terracotta button is 6.11:1. Accent text on the page ranges from 4.70:1 to 5.53:1. These base-color checks exceed the 4.5:1 normal-text baseline; they do not replace inspection of the final composited screens, disabled states, or assistive technology testing.

All 40 core tests pass. The real app sources compile and link for the iOS simulator SDK with an iOS 17 deployment target, and XcodeGen regenerates the project. The [motion study](previews/paper-theatre-motion.gif) and [action snapshots](previews/paper-theatre-study.png) render production artwork code. They are native artwork studies, not simulator screenshots. An Xcode build and launch, real-device performance, large Dynamic Type, VoiceOver, and keyboard behavior remain unverified. The AI request schema was checked against [Anthropic's structured-output documentation](https://platform.claude.com/docs/en/build-with-claude/structured-outputs); no authenticated model request was made.

## A loop that rewards invention

1. **Understand:** show a concrete problem, a goal and one meaningful constraint. Tell the player what kind of response they can give.
2. **Invent:** provide an inviting answer field and optional help that asks a generative question rather than supplying a canonical solution.
3. **See the effect:** make the response and result belong to the same challenge. Present the scoring source honestly; an offline estimate must not masquerade as a population-validated judgment.
4. **Learn:** show the total out of 100, consistent criterion labels and one practical next step. The score describes this submission, not the player's identity or intelligence.
5. **Choose:** offer revision and progression when appropriate. Keep a personal best without penalizing experimentation. A retry should not erase the invention.

For social comparison, compare the same challenge with the same rubric version and evaluation mode. Show an invention alongside its score so players can learn from one another. Prefer optional friend comparison and celebrating different approaches over a global ranking of people. A local share card is not a verified online leaderboard; label its scope accurately until server-verified comparison exists.

### Current scoring boundary

The local fallback uses lexical heuristics and is labeled a practice estimate. It does not judge semantic novelty reliably; its known maximum of about 62 also leaves later score gates unreachable offline. Judge calibration and a viable offline progression policy remain separate required work. The six rubric criteria map into the older eight-axis world profile through a compatibility adapter; detail stands in for fluency and depth stands in for flexibility. Those two proxies are not validated measures of idea or category counts. A passing attempt now commits rewards and growth from the same assessment used by the visible score, once per day. Failed attempts remain revisable and do not earn resources or brighten the saved world.

## First-session playtest

Run a small formative test with 5–8 people who say they sometimes struggle to generate ideas. Include both regular players and people who play rarely. This sample diagnoses problems; it cannot estimate population retention. Keep a screen recording or timestamped observation log with consent. Do not help unless a participant is blocked, and record each intervention.

Give the participant the following tasks in order:

1. Open the game: “Tell me what you think you can do here, then start.” Record the first action and what they expect to happen.
2. Read a challenge: “Explain the goal and constraint in your own words.” Record misunderstandings before the first answer.
3. Submit an idea without coaching. Record the time to first submission, duplicate presses, unexpected waits and any abandoned attempt.
4. View the result: “What happened, and why do you think you received this score?” Record whether they can name an earned strength, an improvement and whether they cleared the level.
5. Revise once: “Try another version if you want to.” Record whether the feedback supports an intentional change and whether the draft is easy to recover.
6. Offer another challenge with no pressure to continue. Record the voluntary choice and ask what motivated it. Ask separately about the appeal of the visuals, comfort of movement and enjoyment of inventing.

| Measure | Record | Diagnostic target for this first round |
| --- | --- | --- |
| Comprehension | Correct goal, response method and constraint before submitting | At least 4 of 5 participants without intervention |
| Action response | Duplicate taps, uncertain status, waits that block intended input | No recurring confusion about whether an action registered |
| Score coherence | Correct pass state; understandable reason and revision opportunity | At least 4 of 5 explain the result in their own words |
| Improvement | Intentional revision prompted by feedback | A usable suggestion for every low-scoring attempt; do not require an automatic score increase |
| Desire for another challenge | Voluntary continuation and participant's reason | Report actual choices and reasons; no claimed retention lift |
| Comfort and readability | Motion discomfort, text difficulty, keyboard/VoiceOver barriers | Resolve any blocker before testing additional content |

These targets are local release decisions, not industry benchmarks. If a screen earns praise but participants cannot explain the goal or score, fix the flow first. If they understand the game but find the scene flat, enrich silhouettes, layering and meaningful reactions. Test a quieter motion variant when participants report distraction. After changes, repeat the affected tasks with fresh participants.
