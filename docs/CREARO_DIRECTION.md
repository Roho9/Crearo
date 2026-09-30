# Crearo: direction and first world expansion

Prepared September 30, 2026. Repository reviewed at commit [`3d86901`](https://github.com/Roho9/Crearo/tree/3d869014b9a24dd067083256e0c97e85c86a8f5d).

## The game to build toward

Crearo should help people practice thinking beyond their first answer. A player encounters an understandable obstacle, invents a solution, sees that invention affect a lively world, earns a satisfying creativity score, and advances to the next level. Comparing ideas and scores with friends gives that loop a second reason to return.

The current priorities are **world, characters, objects, and challenge content**, with a light, approachable visual identity that feels deliberately authored. The visible score and level progression stay central. The recommendations and twelve challenges below are proposals; no app improvements have been implemented in this review.

A creativity score is a **game rubric applied to an answer**, not a validated measurement of a person's creativity. The game should communicate what this particular idea did well and how it could improve.

## Five issues the expansion needs to address

1. **Default scoring prevents later progression.** The offline scoring path caps at 62/100, while Level 5 already requires 64. A compiled check of the unmodified engine gave an irrelevant, keyword-rich word list 62. The default rarity service has no populated corpus, so it returns the same neutral originality signal. This makes high scores and continued progression unattainable in that mode. Sources: [default services](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Services/AppServices.swift#L15), [offline signals](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Services/GameEngine.swift#L119), [pass marks](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoCore/Sources/CrearoCore/Engines/CreativityRubric.swift#L203).

2. **The offline judge does not understand the obstacle.** It receives answer text and a prompt ID, without the question or goal. Length, word variety, and particular emotional or metaphorical words stand in for meaning. Changing the prompt ID left the checked answer's score unchanged. The expansion needs to recognize how an invention solves the actual situation, including concise solutions. Source: [signal extraction](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Services/GameEngine.swift#L119).

3. **One submission receives two different verdicts.** The app first updates growth and rewards from offline signals, then requests a separate AI grade for the visible score and advancement. Failed retries still pay resources and brighten the world. The offline scene also describes the adventure moving forward regardless of the grade. Players need one coherent outcome across the score, feedback, animation, and progress. Sources: [submission flow](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/AppState.swift#L187), [world updates](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Services/GameEngine.swift#L69), [fallback scene](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Services/StoryDirector.swift#L126).

4. **Content and difficulty currently rely on repetition.** The twelve authored levels cycle after the first pass through the bank, while the score threshold rises. The same six criterion weights apply to every challenge: a prompt asking for many different uses still demands metaphor, detail, and delight. Richer regions need new obstacles and challenge-specific expectations. Sources: [level bank and cycling](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/Features/Daily/DailyChallenge.swift#L34), [rubric weights](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoCore/Sources/CrearoCore/Engines/CreativityRubric.swift#L27).

5. **Scores are not ready for fair social comparison.** The app persists local totals and a best score, without individual authoritative score records or a leaderboard. The backend rarity function is separate from the current level judge. Daily rarity IDs use a date even though players can be on different levels; answers to different puzzles would enter the same comparison pool if connected unchanged. Sources: [saved progress](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoCore/Sources/CrearoCore/Models/WorldModels.swift#L194), [daily ID](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/CrearoApp/AppState.swift#L160), [backend rarity function](https://github.com/Roho9/Crearo/blob/3d869014b9a24dd067083256e0c97e85c86a8f5d/supabase/functions/score-originality/index.ts#L37).

Validation completed: **35 Swift core tests passed**, and the compiled engine checks above reproduced the scoring problem. The attempted app build was blocked by environment permissions for Xcode cache diagnostics and simulator logs. App compilation, launch, and visual gameplay remain unverified; the blocked build did not establish source errors.

## Make one evaluation drive the entire outcome

Each challenge should define its obstacle, goal, explicit constraints, intended creativity skill, and a small set of human-written scoring examples. Evaluate the answer once against that content. Preserve the visible 100-point score, with understandable reasons tied to the player's own idea.

The resulting evaluation should supply criterion scores, a brief explanation, one actionable improvement, whether the goal was achieved, and a structured scene outcome. Progress, growth, rewards, and animation should all use that result. A failed attempt should visibly explain what happened and leave the player able to refine the idea. A strong solution should create a noticeable, lasting change in the region.

Calibrate weak, promising, strong, and exceptional answers before selecting pass marks. A concise inventive answer must be able to earn a high score. A quantity challenge should reward genuinely different useful ideas; an empathy challenge should reward understanding the recipient. Make later levels harder through richer constraints and combinations of skills.

For comparison, match friends on the **same challenge and scoring version**. Store individual attempts with a stable challenge ID, answer, score breakdown, attempt number, and judge/rubric version. Decide whether the compared score represents the first attempt or best refined attempt, and label it clearly. Story progression and a shared daily challenge can coexist if that fits the user's preferred play schedule.

## Proposed expansion: three regions, twelve new levels

Each region introduces a recognizable cast, a reusable set of objects, and four distinct obstacles. The example solution directions illustrate possibility; players may invent other coherent approaches. Art and animation can reuse these authored pieces while staging the player's particular solution.

### 1. Pocket Park

A sunny neighborhood park seen at the scale of its smallest visitors: a snail, a sparrow, and a tiny groundskeeper. Grass becomes a canopy; picnic supplies become structures. Completing levels adds visible activity to the park.

| Level | Concrete obstacle and goal | Creativity practice | Several possible directions |
|---|---|---|---|
| **The Picnic That Slides** | Snacks keep sliding down a sloping blanket. Make a picnic everyone can reach without flattening the hill. | Inventive use of materials; functional fit | Containers built into the blanket, a terraced arrangement, or a moving snack carrier. Explain why it stays usable. |
| **The Tiny Gate** | The snail fits under the gate, but the tall bird cannot enter comfortably. Design an entrance that welcomes both without changing their size. | Perspective taking; adapting to scale | An adjustable opening, separate connected routes, or a gate that responds differently to each visitor. |
| **The Quiet Parade** | The park wants a celebration beside a sleeping gardener. Make the parade feel exciting without making sound. | Communicating through another sense | Moving flags, coordinated shadows, colorful stepping patterns, or another visible rhythm. |
| **The Misplaced Shade** | The park's shade falls on an empty path while fixed picnic benches bake in the sun. Bring useful shade to the benches without moving them. | Reframing; changing relationships | Redirect a canopy, grow a temporary shade structure, or move something that casts a shadow. |

**First visual kit:** sloped blanket, oversized grass, two-scale gate, flags, benches, movable canopy; three expressive park visitors. Keep the visual changes readable at phone size.

### 2. Ribbon Market

A cheerful courtyard of fabric awnings, wheeled stalls, spools, and patterned parcels. A shopkeeper, a courier, and a balloon seller give inventions a practical audience. Solved levels make the market easier and more enjoyable to use.

| Level | Concrete obstacle and goal | Creativity practice | Several possible directions |
|---|---|---|---|
| **The Shop Without a Sign** | Wind has removed the shop names. Help visitors recognize the bakery without using letters or words. | Symbolic communication; clarity | A shape, a moving demonstration, a scent trail, or a visual sequence that communicates baking. |
| **The Tangle of Deliveries** | Three carts block the narrow lanes. Give three genuinely different ways to deliver their parcels without widening the paths. | Flexibility; distinguishing solution categories | Change the route, move parcels above the lane, or change who travels. Three renamed versions of one mechanism count as one approach. |
| **The Uncooperative Balloons** | Tall balloon animals must travel through a low arch without popping. Invent a transport method that preserves them. | Transformation; working within constraints | Temporarily change their arrangement, guide them along another dimension of the arch, or invent a protective carrier. |
| **The Borrowed Minute** | The market bell rings unpredictably, so customers miss their turns. Create a fair cue system without a clock. | Designing systems; cause and effect | Tokens passed in order, a visible progress trail, or cues tied to completed service. Explain how the next person knows. |

**First visual kit:** modular stalls, swappable signs, carts and parcels, ribbons, arch, balloon forms, bell and cue objects; three market characters with clear anticipation and reaction poses.

### 3. Paper Harbor

A shallow harbor of folded boats, wooden pegs, illustrated maps, and a little lighthouse. A patient boatmaker and a translucent visiting creature give the region warmth. Each solution adds a boat, navigation aid, signal, or welcome ritual to the harbor.

| Level | Concrete obstacle and goal | Creativity practice | Several possible directions |
|---|---|---|---|
| **The Folding Boat** | A paper boat folds flat whenever a splash hits it. Keep it useful on the water without replacing its paper body. | Elaboration; explaining a mechanism | Reinforce its folds, give it a protective surface, or support it with an inventive floating frame. |
| **The Map With Holes** | Important directions are missing from the harbor map. Design a guide that reaches the boatmaker using only three visible landmarks. | Combining information; precise expression | Link shapes, invent a memorable sequence, or encode the route in a small object. The guide must explain the order. |
| **The Lighthouse Looking In** | The lighthouse illuminates its own walls. Help arriving boats see its signal without turning the tower or making the lamp brighter. | Reframing; redirecting existing resources | Reflect or guide the light, change the surface that carries the signal, or turn the lit walls into something visible outside. |
| **The Visitor With No Hands** | A floating visitor cannot hold the harbor's welcome gift. Invent a welcome it can enjoy and a way for it to leave a trace of its visit. | Empathy; meaningful invention | An experience, a shared pattern, or an environment that responds to its movement. Explain why the welcome suits this visitor. |

**First visual kit:** folded boat variations, splash and fold states, peg pier, three landmark shapes, lighthouse optics, translucent visitor, and lasting welcome decorations.

## Visual reference lanes to compare

Explore a small original style study using these primary references: [Pilgrims](https://amanita-design.net/games/pilgrims.html), [Hohokum](https://blog.playstation.com/2013/05/07/hohokum-coming-to-ps4-ps3-ps-vita-in-2014/), [Homo Machina](https://sinnema.com/works/homo-machina/?lang=en), [Lumino City](https://www.stateofplaygames.com/luminocity), and [GNOG](https://www.gnoggame.com/). They offer useful directions to inspect for expressive characters, playful forms, readable mechanisms, tactile environments, and motion.

Choose Crearo's own shape language, palette, material treatment, and motion rules. Start with one companion, one obstacle, and one success/retry sequence in the chosen direction. Approve that visual language before producing all twelve levels. Every new character and prop should contribute to a readable interaction or a lasting world change.

## Decisions still pending

The user's choices about free play versus a daily limit, supported input methods, and the preferred social mode will determine the first implementation scope. The strongest starting slice is one complete Pocket Park challenge: authored environment and actors, a calibrated score, specific coaching, visible invention-driven consequences, and a repeatable path to improvement. Expand the remaining levels after that loop is enjoyable and understandable.
