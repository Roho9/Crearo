# CREARO — Game Design Document

*Working title:* **CREARO** (Latin *creare*, "to bring into being"). Internal codename for the build in this repo.
*Genre:* Single-player 3D third-person semi-open-world dark-fantasy survival, with a hidden creativity-training engine.
*Platform:* iOS-first (iPhone, with iPad support). Native Swift/SwiftUI + RealityKit, Supabase backend.
*Document status:* Foundational design spec v0.1. This is the canonical source of truth; the `.docx` export is generated from it.

> **One honest note up front.** This document describes the *full* vision. The repo it lives in implements the **non-3D backbone** (data models, the creativity-scoring engine, the resource economy, the AI-interpretation contract, auth, persistence, and a SwiftUI MVP shell with a RealityKit stub). The 3D open world, art, and animation are a multi-year content effort layered on top of that backbone. Sections 63–66 and `ROADMAP.md` are explicit about what is real now versus later.

---

## Table of Contents

**Part I — Vision & World** (1–11)
1. One-sentence pitch · 2. Product vision · 3. Target audience · 4. Core gameplay loop · 5. iOS 3D gameplay style · 6. Dark-fantasy world concept · 7. Tone & art direction · 8. Lightweight 3D graphics direction · 9. Regions & biomes · 10. Opening wooden-house sequence · 11. The Mirrorwood (first forest)

**Part II — The Player & Identity** (12–21)
12. Character creation · 13. How creation evaluates creativity · 14. Emergent classes · 15. Lore & story structure · 16. The unseen villain · 17. Enemy forces · 18. Companion concepts · 19. Companion adaptation · 20. NPC archetypes · 21. Dialogue style

**Part III — Systems** (22–38)
22. Survival · 23. Creative crafting · 24. Semi-creative stats · 25. Creative combat · 26. Creative puzzles · 27. Creative NPC dialogue · 28. Resource economy · 29. The nine resources · 30. Earning & spending · 31. Daily loops · 32. Decay & corruption · 33. AI interpretation · 34. Nerfing OP ideas · 35. Weak ideas raise difficulty · 36. Permanent creations · 37. Naming · 38. Metric-based decay

**Part IV — The Hidden Engine** (39–45)
39. Hidden scoring · 40. Research principles · 41. Rarity measurement · 42. Anti-nonsense · 43. Badges & growth paths · 44. Creative profile · 45. Prophecy-style reports

**Part V — Progression & Home** (46–51)
46. Unlockable areas · 47. Home base growth · 48. Home corruption · 49. Boss progression · 50. Personalized final boss · 51. Final-boss examples

**Part VI — User Creativity In, World Out** (52–56)
52. Photos/drawings/voice/writing into the world · 53. Real-world exercises · 54. NPC memory · 55. Companion memory · 56. Failure transforms the world

**Part VII — Product, Tech & Business** (57–66)
57. Fun, not homework · 58. Long-session design · 59. Retention · 60. Social sharing · 61. iOS architecture · 62. Privacy & moderation · 63. MVP · 64. Full version · 65. Risks · 66. Sharper, more marketable cut

> Deep-dive companions: **`CREATIVITY_SCORING.md`** (the research + math behind §39–45), **`TECH_ARCHITECTURE.md`** (§61), **`SETUP_GUIDE.md`** (accounts, Xcode, Git, backends), **`ROADMAP.md`** (§63–66 in execution detail).

---

# Part I — Vision & World

## 1. Refined one-sentence pitch

**Crearo is a cozy dark-fantasy survival RPG where you rebuild a world drained of imagination by *making things* — and the more original, detailed, and brave your creations are, the more the world comes back to life — secretly training you to think more creatively every day.**

Alternate framings for different audiences:

- *App Store / consumer:* "Craft your way out of the Grey. A dark-fantasy world that grows from your imagination."
- *Investor:* "Finch meets Sky: Children of the Light, with a hidden creativity-assessment engine — a daily-habit creativity gym disguised as a premium cozy RPG."
- *Internal north star:* "The player should close the app feeling *I am more creative than I thought.*"

## 2. Longer product vision

Most "brain training" apps fail because they feel like tests, and most games don't change who you are after you put them down. Crearo sits deliberately in between: it is a *real game first* — survival, exploration, crafting, combat, bosses, a home you love — and a creativity intervention *second and invisibly*. The player never sees a score. They see a foggy forest become luminous because the lantern they invented was strange enough to frighten the dullness out of it.

The core fiction: the world is being slowly overwritten by **the Grey** — a force that makes everything predictable, repeated, gray, and lifeless. Imagination is the only thing the Grey cannot copy. The player is one of the last people who can still *make new things*, and creation is literally magic: you spend creative resources to bring ideas into being, and the things you make stay in the world permanently.

Underneath, every creative act the player performs — a drawing, a weapon idea, a way of solving a puzzle, a line of dialogue, a photograph of a real object reinterpreted as an artifact — is quietly evaluated along research-backed creativity dimensions (originality, fluency, flexibility, elaboration, usefulness, risk; see §40). The game responds *through fiction*: better creativity makes the world brighter, enemies more counterable, rewards richer; weaker creativity makes the world duller and harder. Over months, the game adapts to the player's specific creative weaknesses and eventually confronts them with a **final boss built entirely from those weaknesses**, which can only be beaten by growing past them.

The vision is a product people keep for *years* — a creative home that remembers everything they've ever made, that gets corrupted if they disappear and heals when they return, and that slowly, genuinely, makes them more imaginative.

Three-horizon vision:

- **Horizon 1 (MVP, ship in ~6–9 months):** the wooden house, the Mirrorwood, character creation, the creation forge, the daily creative quest, one companion, the hidden scoring engine, one personalized "shadow" mini-boss.
- **Horizon 2 (12–24 months):** 4–6 regions, emergent classes fully expressed, home-base growth, real-world photo tasks, the corruption/decay system, the first true personalized final boss.
- **Horizon 3 (24 months+):** the full myth arc, social "visit my world" sharing, seasonal world events, creator-economy of shared prompts, and a defensible dataset of human creativity that is itself a research and licensing asset.

## 3. Target audience

**Primary:** Creatively-curious adults 18–34 — college students, early-career knowledge workers, and "lapsed creatives" who believe they *used* to be imaginative and want it back. They play cozy and narrative games (Sky, Spiritfarer, Stardew, Disco Elysium), follow self-improvement, and respond to identity-driven products ("I'm becoming a more creative person").

**Secondary:** Self-improvement / journaling-app users (the Finch audience — Finch reached ~10M DAU and $100M+ by gamifying self-care) who want something with more *depth* and craft than a virtual-pet checklist.

**Tertiary:** Educators, art therapists, design students, and writers looking for a low-stakes daily creativity practice; and the research/EdTech market that values a validated creativity-training tool.

**Anti-audience (explicitly not for):** competitive multiplayer/PvP players, hardcore survival min-maxers who want a punishing sim, and people seeking a pure idle/clicker. Naming the anti-audience keeps scope honest.

**Audience implications baked into design:**
- They have *some* discretionary time but inconsistent schedules → reward long sessions but make a 5-minute daily loop meaningful (§58–59).
- They are sensitive to feeling judged → never show raw scores; failure is fiction, not shame (§42, §56).
- They will pay for identity and depth, not for pay-to-win → premium + gentle subscription, no competitive monetization (§59, ROADMAP).

## 4. Core gameplay loop

Crearo nests three loops at different time scales.

**Moment-to-moment (seconds–minutes):** explore the world in third person → notice a problem (a blocked path, a starving NPC, a dullness-corrupted shrine, a hungry survival meter) → respond *creatively* using one or more input methods (craft, draw, write, photograph, arrange, speak, build, negotiate) → the world reacts (path opens, NPC brightens, color returns) → earn creative resources.

**Session (20–60 min):** pursue a story or side quest into a region → gather resources and survive → reach a creative "set-piece" (a puzzle, a creature, a corrupted site, a forge challenge) → make a permanent named creation → bring it home → see the home base change → the companion comments on your style.

**Long-term (days–months):** daily creative quest + login keeps the home from decaying → the hidden profile builds → classes emerge from behavior → new regions unlock as you demonstrate range → growth reports arrive as prophecies → the personalized final boss slowly forms from your weakest patterns → you grow past them to win.

```
        ┌────────────────────────────────────────────────────────┐
        │  EXPLORE  →  ENCOUNTER A PROBLEM  →  CREATE A RESPONSE   │
        │     ▲                                        │          │
        │     │                                        ▼          │
        │  HOME GROWS  ←  EARN RESOURCES  ←  WORLD REACTS (bright/ │
        │     │              + HIDDEN SCORE              dull)     │
        │     ▼                                                    │
        │  DAILY QUEST keeps decay away · PROFILE shapes classes,  │
        │  regions, companion, NPCs, and the final boss            │
        └────────────────────────────────────────────────────────┘
```

The single most important design rule: **every loop closes on a creative act that changes the visible world.** If the player ever feels they are "answering a prompt," we've failed; they should feel they are *casting a spell made of their own idea.*

## 5. The 3D third-person iOS gameplay style

A simplified, cozy third-person controller tuned for touch:

- **Movement:** left-thumb floating virtual joystick (appears where the thumb lands). Tap-to-move as an accessibility alternative. Camera auto-follows; right-thumb drag orbits; pinch to zoom. No manual camera babysitting required.
- **Interaction:** a single context button (bottom-right) that changes label by what you're near ("Gather," "Talk," "Forge," "Inspect," "Rest"). One-button design keeps cognitive load low so creative effort goes into *ideas*, not controls.
- **Pace:** deliberately slower than an action game. This is "cozy survival," not twitch combat. Traversal is calm; tension comes from atmosphere, survival meters, and creative stakes.
- **Creative input surfaces:** when a creative act is triggered, the 3D world gently recedes (depth-blur) and a **Making Surface** slides up — a drawing canvas, a text field, a voice recorder, a photo capture, or an object-arrangement board, depending on the challenge. The result animates *into* the 3D world (e.g., your drawn sigil burns itself onto a door).
- **Sessions:** designed for 20–60 minute sit-downs but fully pausable; the world persists. Auto-save continuously.

Reference feel: the calm traversal and readable silhouettes of *Sky: Children of the Light*, the cozy-melancholy of *Spiritfarer*, the one-thumb friendliness of *Alto's Odyssey*.

## 6. The medieval dark-fantasy world concept

The world is **the Wending Lands** — a once-vivid medieval realm being flattened into sameness by the Grey. Surviving pockets of color and imagination cluster around hearths, hidden groves, and stubborn eccentrics. The aesthetic is *cozy dark fantasy*: candlelit wooden interiors and warm hearths set against foggy forests, ruined castles, and the encroaching gray.

Worldbuilding pillars:

- **Imagination is literal magic.** Anything genuinely new resists the Grey. Bards, smiths, hedge-witches, and tinkerers are the realm's true soldiers.
- **The Grey is conformity made physical.** It doesn't burn the world; it *repeats* it until it's lifeless. Corrupted zones are gray, gridlike, looping, and eerily tidy.
- **The corrupt kingdom — the Leaden Court of Greymarch** — sided with the Grey, mistaking sameness for safety and order. Its puppet **Ashen King** issues edicts of standardization. It is the human face of the threat (§17).
- **Decay is magical, not violent.** Plants don't die, they *fade*. Songs don't stop, they *loop*. This makes corruption visually distinct and emotionally unsettling without gore.
- **Nobody has seen the true villain** (§16). The Grey is the symptom; the thing behind it is only known through contradictory myths.

This is a survival game (hunger, thirst, shelter, monsters, tools) and a *symbolic* one (the same forest is both a real biome and a representation of the player's imagination, fears, and habits — §15). The two layers are never explained to the player as "this is your psyche"; they're felt.

## 7. The emotional tone and art direction

**Target feeling:** *cozy, mysterious, a little melancholy, secretly hopeful.* The player should feel safe enough to take creative risks and curious enough to keep pulling threads. Slightly cute, slightly creepy — "Studio Ghibli meets Over the Garden Wall meets Hollow Knight's softer moments."

**Tone rules:**
- Warmth and dread coexist. A candlelit room is cozy *because* the fog outside is not.
- Never cruel. The game is dark but never shames the player. Failure is wistful, not punishing (§56).
- Wonder over horror. Strange creatures are *uncanny and intriguing*, rarely scary-for-scares.
- Earnest, not ironic. The myth is played straight; the companion can be funny, the world is sincere.

**Color language:** saturated warm pools of light (amber, ember-orange, candle-gold, moss-green, deep magical blues/violets) carved out of a desaturated gray fog. **Creativity = color and light; the Grey = desaturation and right angles.** This single rule drives every art decision and is also the *readable feedback channel* for the hidden scoring: more creativity literally re-saturates the world.

**Audio:** no full voice acting (§21). Atmospheric score (lute, hammered dulcimer, soft choir, music-box), reactive ambience (the Grey introduces a faint, looping, metronomic hum), and tactile UI sounds for making (charcoal scratch, forge hiss, ink bloom).

## 8. Simple, lightweight 3D graphic direction

Built to look intentional on a mid-range iPhone, not to chase realism:

- **Stylized low-poly + hand-painted/gradient textures.** Low triangle counts, smooth or flat shading, painterly texture atlases. Readable silhouettes over surface detail.
- **Atmosphere does the heavy lifting.** Volumetric-*looking* fog (cheap depth-based fog), strong directional candlelight, baked lighting and baked ambient occlusion for static scenes, a small number of dynamic lights (the player's lantern, fires).
- **Vertex-based effects** (wind sway, glow pulse, dissolve-to-gray corruption) instead of expensive shaders/particles where possible.
- **Instancing and modular kits.** Forests, ruins, and villages are built from reusable modular meshes (trees, rocks, walls, props) so artists scale content and the GPU batches draws.
- **Performance budget (MVP target, iPhone 12-class):** ≤100k visible triangles/frame, ≤80 draw calls, a handful of real-time lights, 30 fps floor / 60 fps target, aggressive frustum + distance culling, LODs on everything, texture atlases ≤2k. Detailed in `TECH_ARCHITECTURE.md`.
- **The "Grey" as a shader:** corruption is a global post/material effect — desaturate, snap to grid, add a faint scanline/loop — so we can corrupt *any* asset cheaply without new art. This is both an art pillar and an engineering efficiency.
- **User-created content is *restyled, not pasted*** (§52): the player's drawing/photo is reinterpreted into this look (palette-mapped, outlined, given the world's lighting) so everything stays cohesive.

## 9. Main regions and biomes

Regions unlock by *demonstrating creative range* (§46), not by grinding. Each region is a real biome *and* a symbolic chamber of the imagination, with a survival twist, a dominant creative dimension it pressures, and a guardian/boss.

| # | Region | Biome / vibe | Survival twist | Creative dimension pressured | Symbolic meaning |
|---|--------|--------------|----------------|------------------------------|------------------|
| 0 | **Lastlight** (home hamlet) | Cozy wooden house + tiny village clearing | Safe hearth; warmth/decay | Elaboration (make your space yours) | Your creative home / sense of self |
| 1 | **The Mirrorwood** | Foggy enchanted forest | Hunger, thirst, cold, predators | Originality + fluency | First leap of imagination; fear of the blank |
| 2 | **The Hush Mire** | Sunken swamp, drowned bells, fungal light | Disease, sinking ground, scarcity | Flexibility (one tool won't work twice) | Stuckness; the same solution failing |
| 3 | **The Leaden Court / Greymarch** | Ruined gray city, gridded streets, bureaucratic ghosts | Surveillance, "permitted" zones | Risk-taking + reframing | Conformity, fear of judgment |
| 4 | **The Emberreach Highlands** | Volcanic forges, obsidian, ember-rivers | Heat, equipment durability | Usefulness (beautiful but must *work*) | Turning passion into finished craft |
| 5 | **The Lull (Dreaming Coast)** | Moonlit shore, tide of forgotten things | Sleep/exhaustion, memory loss | Emotional + symbolic expression | Feeling, memory, the unconscious |
| 6 | **The Unwritten** (endgame) | Shifting non-place that takes your style | The world rewrites your creations | All — your weakest first | Direct confrontation with the self |

**Design intent:** the first three regions form the MVP-to-Horizon-2 spine. Each region "teaches" one dimension by making the player's *default* approach fail there, forcing growth. A combat-reliant player hits the Hush Mire and finds brute force literally sinks them; a safe player hits Greymarch where "permitted, predictable" actions are punished and risk is rewarded. The map is a **diagnostic instrument disguised as geography.**

## 10. The opening wooden-house sequence (first 10 minutes)

The onboarding must hook, teach controls, *and* take the first creativity baseline — without the player knowing the last part.

**Beat 1 — Waking (cozy):** the player wakes in a small, bare wooden house. Warm but empty: a cold hearth, one stool, a dusty window, a shuttered world outside. A small gray creature (the future companion, §18) sits in the corner, colorless and quiet. Tutorial-by-doing: walk to the hearth (movement), gather a log (interaction), light the fire (context button). The fire blooms the first pool of warm color into the gray room — the game's whole thesis in one image.

**Beat 2 — The first making (baseline #1):** the companion gestures at the cold, blank wall. The Making Surface rises: *"Make a mark so this place knows you live here."* The player can draw, write a word, snap a photo, or place an object. Whatever they make is restyled and **burned onto the wall as a glowing sigil** — their first permanent creation. (Hidden: this is baseline elaboration + first style sample. There is no wrong answer; even a single dot earns warmth, but a richer mark warms more of the room.)

**Beat 3 — The companion wakes (baseline #2):** the sigil's light reaches the gray creature; it gains a flicker of the sigil's dominant color. It speaks for the first time (text), and asks the player to **name it.** Naming is the first attachment hook and the first naming-sample (§37). It now follows the player.

**Beat 4 — The shutters open (the call):** outside, the fog and the Mirrorwood. The companion warns that the warmth won't last if nothing new is ever made here. A faint gray tendril creeps under the door — the first glimpse of the Grey — and recoils from the fire. The player steps out. The house is now their anchor: everything made out in the world can be brought back to grow it (§47).

**Why this works:** it is *all game* — wake, warm, mark, name, leave — yet it has already sampled the player's preferred input, baseline elaboration, and first style signature, and emotionally bound them to a home and a companion in under ten minutes.

## 11. The first forest region — the Mirrorwood

The Mirrorwood is the first true test: survival, creativity, exploration, crafting, combat, and puzzles, in a place that is beautiful and unsettling at once. Cozy pockets (a mossy hollow, a firefly glade) punctuate genuine danger (fog you can lose yourself in, things that mimic you).

**What's in it:**
- **Strange trees & hidden paths** — some trees only reveal a path when you change perspective (crouch, climb, view through your lantern) — a soft intro to perspective-shift puzzles (§26).
- **Talking roots** — half-buried root-faces that trade cryptic hints for small creative acts ("hum me something the wind hasn't heard").
- **Lost shrines** — corrupted, gray, looping; restored by *making* the missing piece (a drawn glyph, an invented offering), which re-colors the glade and yields resources.
- **Corrupted animals** — once-cute creatures stuck in gray loops (a deer pacing the same eight steps). You can fight them, but the *creative* solution (break their loop with novelty — a strange sound, an unexpected object) frees and befriends them, and scores higher.
- **Abandoned camps** — environmental storytelling about earlier failed creatives who "made the same thing twice" and were taken by the Grey; sources of starter resources and lore.
- **Glowing mushrooms** — light, food (survival), and a crafting reagent; risk/reward (some are corrupted).
- **Ancient carvings** — the first broken prophecy fragments about the unseen villain (§16).
- **First signs of the anti-creative force** — patches where color drains, a faint metronome hum, perfectly straight game-trails that shouldn't be straight.

**The Mirrorwood's lesson (originality + fluency):** the forest "remembers" what you make. Reusing the *same* solution it has already seen from you makes that solution weaker here (the Grey copies it), nudging the player to vary their ideas. The region guardian, the **Hollow Stag** (a mini-boss / the player's first "shadow," §49), mirrors the player's most-repeated tactic and forces a second, different approach.

**Survival in the Mirrorwood:** manage warmth (cold fog), hunger (forage mushrooms/berries, hunt), thirst (find clean springs vs. corrupted water), and light (your lantern keeps the fog's disorientation at bay; its fuel is a soft timer that structures exploration). Build a small forward camp (a second, temporary hearth) to push deeper — the first taste of building beyond the home base.

---

# Part II — The Player & Identity

## 12. Character creation mechanics

The character begins **deliberately blank** — a gray, hooded silhouette with no face, no color, no class. The player makes it *theirs* through a guided sequence of creative acts. Crucially, this is framed as *"waking up your character,"* never as "creativity test."

Six creation facets, each accepting multiple input methods:

1. **Outfit / visual style** — draw on a mannequin canvas, *or* snap a photo (a fabric, a texture, a color you like), *or* pick + recombine modular pieces, *or* describe in words. AI restyles it into cozy dark-fantasy gear (§52).
2. **Identity / name & title** — name the character and give a one-line self-description ("a tired baker who dreams in color").
3. **Symbolic object** — choose/draw/photograph one object that "means something" — it becomes a literal in-world relic with minor powers (the Relicseer path leans on this, §14).
4. **Voice / inner voice** — optionally record a short voice clip or pick a text "voice" (wry, gentle, grim, playful) that flavors the character's internal narration (not full VO; used for cadence + the companion's mimicry).
5. **Backstory** — answer one open prompt ("What did you make, once, that you were proud of?") via text or voice. Seeds NPC references and the emotional spine.
6. **Mark / sigil** — the glowing sigil from the opening (§10) is finalized here as the character's signature, stamped on creations.

Each facet is **skippable and revisable** — low pressure, and skipping is itself a (recorded) signal. Total time: 3–6 minutes, interleaved with the opening so it never feels like a form.

## 13. How character creation secretly evaluates creativity

Character creation is **baseline sample #1** for the hidden profile (full method in `CREATIVITY_SCORING.md`). It is ideal for this because it's open-ended, multi-facet, and emotionally safe. What it quietly measures:

- **Preferred modality** — did they draw, write, photograph, arrange, speak? Sets the *default input* and an early class lean (§14). (A drawer leans Inkbinder; a writer leans Mythweaver; a photo-user leans Relicseer.)
- **Elaboration** — detail and effort per facet (stroke count, word richness, layers, time-on-task) vs. minimal "just get through it."
- **Originality (provisional)** — rarity of choices vs. the population on the *same* prompts (e.g., how common is "a sword" as the symbolic object vs. "my grandmother's bus ticket"). Stored as a provisional prior, refined over time (§41).
- **Range / fluency** — did they engage many facets richly, or one-note?
- **Risk & self-expression** — does the backstory reveal something real and specific, or a safe generic?
- **Coherence** — do the facets form a *theme* (a sign of symbolic thinking) or feel random?

**Anti-gaming & anti-shame:** there is no failing this. Low-effort input still produces a valid character and a warm room; it simply yields a *quieter* starting world and a profile prior the game will gently test and update. The baseline is treated as a **prior, not a verdict** — Crearo always trusts *trajectory* over any single sample (§44).

## 14. Emergent class system (discovered, never selected)

There are **no class buttons.** Classes are *named by the world* once your behavior clearly leans a direction — usually 1–3 weeks in. Until then you're simply "a Maker." The eight paths:

| Class | Emerges from | Signature mechanic | Example fantasy |
|-------|--------------|--------------------|-----------------|
| **Forger** | tools, weapons, armor, materials, systems | best raw stats & durability; "smithing" mini-game | the master smith |
| **Mythweaver** | stories, names, symbols, emotion | dialogue/lore powers; words literally bind enemies | the bard who rewrites fate |
| **Wyrdmage** | illusion, trickery, unusual/lateral solutions | misdirection, traps, "wrong-answer" magic | the trickster |
| **Rootspeaker** | nature, sound, organic, growth | summon/grow allies, music-based effects | the green hedge-witch |
| **Inkbinder** | drawing, design, visual transformation | drawn sigils become real objects/spells | the living-ink artist |
| **Hollow Spark** | bold, risky, strange, high-variance ideas | huge upside, instability; "gamble" magic | the reckless visionary |
| **Wardmaker** | defense, shelter, armor, protection | shields, walls, safe-zones, ally protection | the architect-guardian |
| **Relicseer** | real-world photos & ordinary objects as inspiration | turns mundane reality into artifacts | the seer of common things |

**How emergence works:** the profile tracks the *distribution* of your creative acts across modality, problem type, and creative dimension. When one mode crosses a confidence threshold (e.g., >40% of high-effort creations are visual transformations), an NPC ritual *recognizes* you: *"The Inkwitch of the Mire has heard of your drawn doors. She names you Inkbinder."* You gain that path's tools — but the system stays **multiclass and fluid:** keep doing new things and you develop secondary paths; over-rely on one and the world (and final boss) start countering it (§35, §50). Classes are a *mirror of behavior*, and a deliberate lever to push range.

## 15. Lore and story structure

**Premise:** Long ago the Wending Lands were *made* daily — every hearth a small act of creation. Then came the Grey, and with it the seductive promise of *safety through sameness.* The Leaden Court embraced it. Now imagination is nearly extinct, and you are one of the last who can still make new things. The companion found you because you still *can.*

**Structure — "handcrafted spine, adaptive flesh":** the main arc, characters, regions, bosses, and emotional beats are authored (not generated). What *adapts* is which regions open first, which NPCs trust you, which enemies appear, which class you become, which resources flow, how your home and companion evolve, and — above all — **how the final boss is composed** (§50). AI integrates *your* creativity into this fixed skeleton; it does not generate the skeleton (§33).

**Five acts:**
1. **Ember (Lastlight + Mirrorwood):** learn that making is magic; meet the Grey; first shadow (Hollow Stag).
2. **Stuck (Hush Mire):** your favorite trick stops working; learn flexibility; meet survivors who gave up.
3. **The Court (Greymarch):** infiltrate the conformity engine; the Ashen King; learn that the Grey is *chosen,* not imposed; rescue or fail NPCs.
4. **Fire & Feeling (Emberreach + the Lull):** marry usefulness with emotion; recover what the world forgot; gather the means to reach the source.
5. **The Unwritten (endgame):** confront the personalized final boss — the amalgam of your weakest creative patterns — and the brief, partial unveiling of the thing behind the Grey (§16, §50).

**Adaptive beats (examples):** if you spared and freed corrupted animals, a faction of freed creatures aids you at the Court; if you bulldozed everything with combat, that faction is absent and Greymarch fields anti-combat wards. The spine is the same; the *texture* is yours.

## 16. The unseen main villain

The villain is **never clearly seen until the final boss**, and even then only partially. Throughout, it exists only as **myth, rumor, broken prophecy, corrupted dreams, and old warnings** — and crucially, *no two sources agree on what it is.* This contradiction is the point.

Names it's given (all "true," none complete):
- **The Loomwright** — "it weaves all things back into one gray thread."
- **The Sameness / the One Pattern** — "it is not a monster; it is the *last idea,* repeating."
- **He-Who-Already-Happened** — "everything it does, it has done before; that is its power and its prison."
- **The Hollow Crown** — the Court's name for it, mistaking it for a rightful king of order.

**Design truth (for the team, never stated to the player):** the villain is *entropy of the imagination* — the gravitational pull toward the predictable, the safe, the already-done. It has no single body because it is a *process,* not a person. That is why it can only be embodied at the very end, and only as **a reflection of the specific player** (§50): the final boss is the Sameness wearing the mask of *your* creative weaknesses. The horror and the catharsis are the same realization — *the thing flattening the world is the part of me that stopped trying new things.*

This keeps the villain mysterious and *cheap to produce* (it's mostly text, rumor, and environmental dread for 90% of the game) while making the finale maximally personal.

## 17. Main enemy forces

Enemies are **anti-creative forces** with distinct mechanics, each countered by a different creative dimension — so the bestiary itself is a creativity curriculum.

- **Fear (the Mistfright):** wraith-like, drains the player's *willpower* resource and freezes input. Countered by **risk-taking** — bold/unexpected actions dispel it; hesitation feeds it.
- **Conformity (Greywardens / the Tidy):** gridlike constructs that *standardize* terrain and "permit" only repeated actions. Countered by **originality + reframing** — they have no response to something they've never catalogued.
- **Dullness (the Dim):** slow gray oozes that desaturate everything they touch and make the player drowsy (UI dims). Countered by **emotional/aesthetic charge** — vivid, feeling-rich creations burn them off.
- **The Shadow Self (Hollows):** mimics that copy the player's *last/most-used* solution and use it back. Countered by **flexibility** — only a *different* solution beats your own echo (this is the core of every shadow boss, §49).
- **The Leaden Court (Greymarch forces):** the human, political enemy — censors, "standardizers," and the Ashen King; fought as much through dialogue, illusion, and reframing as combat.
- **The Grey itself (environmental):** not a monster but a spreading condition — corrupts zones, your home, and even your creations if neglected (§32, §48).

Design rule: **no enemy is best beaten by raw combat.** Each is a *lock* whose key is a specific kind of creativity, and later instances *adapt against your habits* (§35).

## 18. Main companion character concepts

The companion is the emotional core — *not* a tutorial bot. It begins as a small, gray, ember-like creature (a **Wisp/Kindling**) found in the opening, colorless until your first creation. The player names it and shapes it.

Baseline concept: a palm-sized creature with a lantern-glow heart, big readable eyes, and a form that **accretes features from your creations** (your drawn horns, your photographed texture, your chosen colors). It can perch on the shoulder, scout ahead, hold light, fetch resources, and — most importantly — *witness and remember* everything you make.

It is designed to feel like **a familiar, a sketchbook, and a friend in one.** It never lectures; it reacts, remembers, teases, worries, and grows. Its arc mirrors the player's: as you grow creatively, it gains color, voice, and abilities; if you neglect the world, it dims and grows quiet and concerned (a gentle, non-shaming pressure to return — §32).

## 19. How companion personality adapts to the user

The companion's personality is **assembled from the player's choices and creative style**, along a few axes, so it feels co-authored:

- **Tone axis (set early + drifts):** if your creations are playful/funny, it becomes **witty and mischievous**; if grim/serious, **wise and somber**; if emotional/personal, **warm and supportive**; if strange/risky, **curious and a little unhinged** (it eggs you on). Players can also nudge tone in settings ("I want a sarcastic companion") — explicit preference overrides inference.
- **Memory-driven commentary:** it references *specific* past creations by name ("Another honey weapon? The Honeyfang served us well, but the Mire won't be fooled twice." — pushing flexibility).
- **Style mirroring:** it adopts bits of your voice/word choices over time (if you named things grandly, it speaks grandly).
- **Coaching disguised as character:** when the hidden profile flags a gap (e.g., you never use emotional expression), the companion *organically* wishes for it ("Do you ever miss... color? Real color? Make me something that *aches.*") — never "your emotional-expression metric is low."
- **Stakes:** it can be *disappointed but never cruel,* worried when you vanish, delighted by genuine novelty. Its evolving form and dialogue are a constant, fictionalized mirror of the player's creative trajectory.

Implementation note: tone is a small state vector updated by the scoring engine; lines are authored templates selected by tone + the specific creation referenced (so it's grounded and safe, not free-generated). See `CREATIVITY_SCORING.md` and the `Companion` model.

## 20. Main NPC archetypes

Handcrafted NPCs, each tied to a creative dimension and a class path, each remembering your style (§54):

- **The Ashkeeper (Lastlight elder):** gentle tutorialist and conscience; tends the village hearth; mourns the world that was. Anchors elaboration & home.
- **The Inkwitch of the Mire:** prickly, brilliant hedge-artist; names Inkbinders; trades drawn favors; pushes visual creativity and risk.
- **Brannoch the Hollow-Smith:** half-corrupted Forger who can no longer invent, only copy; teaches forging but begs you to make what he can't. Living warning about the Grey.
- **The Mascaret (the Lull):** a tide-bound figure of memory and feeling; gatekeeps emotional/symbolic growth; speaks in tides and griefs.
- **The Ashen King (Greymarch):** the antagonist-NPC; courteous, reasonable, terrifying in his *sincerity* — he truly believes sameness is mercy. The game's best argument *against* the player's mission, which makes overcoming it meaningful.
- **The Cartographer of Unmade Roads:** wandering Wyrdmage who only appears when you do something genuinely new; rewards reframing and risk with map secrets.
- **Freed creatures (emergent faction):** the corrupted animals you free become a wordless NPC community at home, reflecting your mercy/violence patterns.

## 21. Text dialogue style examples

**No full voice acting.** All dialogue is text — atmospheric, poetic, mysterious, dark-fantasy. It *remembers your style* and comments on it. Lines are authored templates with slots for `{creationName}`, `{class}`, `{styleTrait}`, `{region}` filled from the profile, keeping voice consistent and safe.

**House style:** short lines, concrete images, a little archaic but readable, dread + warmth, never clinical.

Examples:

> **Companion (first making):** *"Oh. You're one of the ones who can still do that. I'd almost forgotten the color of being seen."*

> **Companion (flexibility nudge, you reused a tactic):** *"The Hollow Stag has watched you swing the {creationName} thrice now. It's learning the song. Sing it a different one."*

> **Ashkeeper (you returned after a long absence, home decaying):** *"The dust found your shelves before you did. No matter. Light something. The room remembers faster than you'd think."*

> **Greywarden (conformity enemy, on a too-predictable solution):** *"CATALOGUED. PERMITTED. SEEN BEFORE. SEEN BEFORE. SEEN BEFORE."*

> **Ashen King (the seductive antagonist):** *"You call it dull. I call it *kept.* No grief here, maker. No failure. Only the same warm hour, forever. Is your precious *new* worth what it costs them?"*

> **Inkwitch (recognizing your class):** *"Doors that aren't there until you draw them. Hm. The Court would burn you for it. I'll teach you instead. Sit. You're an Inkbinder now, whether you like the name or not."*

> **Growth report (prophecy style, §45):** *"The Mirrorwood no longer sees only one path in you. Where one road ran, three now branch — and the Stag has lost your scent."*

---

# Part III — Systems

## 22. Survival systems

Survival is **present but gentle** — enough to create stakes and structure exploration, never a punishing sim that crowds out creativity. Four meters, each with a *creative* escape hatch so survival itself rewards imagination:

| Meter | Drains from | Standard fix | Creative fix (scores + rewards more) |
|-------|-------------|--------------|--------------------------------------|
| **Warmth** | cold fog, night, the Grey | fire, shelter, cloak | invent an unusual heat source (a "bottled argument," a relic that runs warm) |
| **Hunger** | time, exertion | forage, hunt, cook | invent a recipe/creature-friendship that yields food sustainably |
| **Thirst** | time, heat | springs, rain catch | purify corrupted water via a designed filter/ritual |
| **Lantern-light** | exploring fog | refuel with ember-moss | craft a light with a strange fuel (memory, song, fear) that lasts longer |

Plus a soft fifth, **Willpower** (also a resource, §29): drained by Fear enemies and by the Grey; restored by rest at a hearth, by genuine creative success, and by the companion. At zero, you don't die — you're pulled back to the last hearth, the screen graying as a *failure-transforms-the-world* moment (§56), not a "Game Over."

**Death/failure philosophy:** there is no permadeath. "Losing" a survival meter degrades the world and your standing (duller, harder, NPCs lose hope) but always continues the story (§56). Survival is a *clock that creates pressure for creativity under constraint* — which is, deliberately, the exact condition that builds creative skill (§40).

## 23. Creativity-based crafting

Crafting is the heart of "making is magic." Two layers:

**(a) Conventional crafting** (grounding/onboarding): combine gathered materials at stations (forge, loom, alchemy bench, drawing desk) into known items via discovered recipes. Familiar, safe, teaches the economy.

**(b) Creative crafting** (the soul): at the **Creation Forge**, the player *invents* an item by combining (i) an **idea** expressed in any input method, (ii) **materials** they hold, and (iii) **creative resources** (§28). The AI interprets the idea into a balanced, art-styled, named in-world object (§33). Example: *"a cloak sewn from forgotten lullabies"* + Moon Thread + Memory Shards → **"the Lullcloak,"** a stealth cloak with emotional-magic vs. Fear enemies, low armor, a unique sleep-debuff on foes who hear it.

Crafting under constraint is the pedagogy: limited resources + a survival need + a region that resists your usual trick = **creativity under pressure**, which research links to skill growth (`CREATIVITY_SCORING.md`). The forge never says "no" to an idea; it *adapts* it to what's affordable and level-appropriate (§34), so the player always feels their idea entered the world — just sized correctly.

## 24. Semi-creative weapon & armor stat system

Every creation has **two stat blocks**: traditional and creative. Both matter; creative stats gate *unique* effects and how the world/NPCs respond.

**Traditional stats:** Damage, Defense, Speed, Durability, Resistance(s), Weight, Cooldown.

**Creative stats (0–100, from the hidden evaluation of the idea that birthed it):** Originality, Symbolism, Adaptability, Emotional Charge, Strangeness, Elegance, Usefulness, **Instability** (a *risk* stat — high originality/strangeness can raise instability: bigger upside, chance of backfire).

**How they interact (examples):**
- *A "basic iron sword":* Damage high, Originality low → reliable, but **Conformity/Greywarden enemies grow resistant to it fast** (they catalogue the predictable).
- *A "lantern-shield":* Defense low, but **Adaptability + Usefulness high** → doubles as a puzzle tool (light, signal, lure) and counters Dullness.
- *"Cloak of forgotten lullabies":* Armor low, **Emotional Charge + Symbolism high** → strong vs. Fear/Shadow enemies; NPCs of the Lull treat you differently.
- *Armor of "Dreamsteel + a childhood photo":* mid Defense, but **specifically negates Fear-based damage** (symbolic resonance).
- *A "clown-trumpet mace":* mediocre Damage, but **Strangeness high** → *confuses* Dullness/Conformity enemies (they can't categorize it), opening them to any follow-up.

Design intent: stats make creativity **mechanically legible** without numbers-on-screen-for-the-player. The player feels "weird, heartfelt things work on weird, heartless enemies"; under the hood it's `EmotionalCharge`, `Strangeness`, `Originality` driving damage multipliers vs. enemy types. See the `CreationStats` model and `BalanceEngine`.

## 25. Creativity-based combat

Combat exists but is **never the only path, and rarely the best.** Each encounter is a problem with many valid solutions: a weapon, a spell, a trap, an illusion, a distraction, an emotional/symbolic attack, an environmental change, a negotiation, a ritual, or simply leaving and re-approaching differently.

- **Solution variety is scored** (flexibility/fluency). Beating ten enemies ten different ways is celebrated by the world; beating them the *same* way ten times invites adaptation against you.
- **Adaptive enemies (§17, §35):** repeat a tactic and later enemies/bosses harden against it — the Shadow/Hollows literally use your own move back at you. This is the in-fiction mechanism that *forces* range.
- **Non-violence is first-class:** freeing a corrupted animal by breaking its loop with novelty, or talking down a Greywarden by presenting something *uncatalogued,* yields more resources and better world-healing than killing.
- **Creative combat verbs:** *Disrupt* (novelty vs. loops), *Charm* (emotional charge), *Confuse* (strangeness), *Reframe* (turn the battlefield/terms against the enemy), *Forge-in-the-moment* (craft a counter on the fly from held materials). Each verb maps to creative dimensions, so combat is a stealth assessment of *how* you solve problems.

Critically, a pure-combat player can progress through early regions, then hits walls (Hush Mire, Greymarch, the final boss) explicitly designed to resist them — converting an over-reliance into a growth arc rather than a soft-lock (the BalanceEngine guarantees a non-combat path always exists).

## 26. Creativity-based puzzles (grounded in creativity research)

Puzzles avoid single-answer riddles in favor of **divergent, multi-solution, insight, and constraint puzzles** drawn from the creativity literature (Guilford's divergent/convergent thinking, Torrance dimensions, alternate-uses, constraint-satisfaction). For each type below: *how it works · why it trains creativity · how it fits the world · inputs · world effect · how it's scored · anti-nonsense guard.* (Scoring detail: `CREATIVITY_SCORING.md`.)

**General anti-nonsense rule for all puzzles:** a response must clear a **usefulness/appropriateness gate** (does it actually satisfy the constraint and connect to the prompt?) *before* originality is rewarded. Novel **and** fitting scores high; novel-but-irrelevant scores low; this directly counters the known DAT failure mode where random words score as "creative" (Olson et al., 2021). See §42.

1. **Open-ended survival puzzle** — *"cross the freezing river with no bridge."* Trains divergent thinking under real stakes. Fits: the Mirrorwood's cold fords. Inputs: build/craft/draw/arrange. World: a *good* crossing becomes a permanent landmark others (NPCs) use. Scored: number & diversity of viable approaches you generate, originality vs. population. Guard: it must actually get you across (sim-checked).
2. **Alternate-use puzzle** — *"you only have a lantern, a bell, and a dead man's letter. Open the shrine."* The classic Guilford alternate-uses task in fiction. Trains fluency + originality. Inputs: object-arrangement + text. World: the shrine re-colors; unused-but-clever ideas are noted by NPCs. Scored: count + rarity of distinct uses. Guard: each use must be physically/narratively plausible in context.
3. **Constraint-based crafting puzzle** — *"make a weapon with no metal that still stops the Tidy."* Trains creativity-under-constraint (the core pedagogy). Inputs: forge. World: item is permanent + named. Scored: satisfies all constraints (convergent) **and** originality (divergent). Guard: constraint satisfaction is hard-checked.
4. **Environmental transformation puzzle** — reshape terrain (divert a stream, grow a bridge-vine, collapse a ruin into stairs). Trains spatial + transformative thinking. Inputs: build/gesture. World: permanent terrain change. Scored: elegance + reach of the transformation. Guard: physics sim validates stability.
5. **Multi-solution logic puzzle** — a mechanism with several valid keyings, not one. Trains convergent thinking with *flexibility* (find more than one). World: extra solutions yield bonus resources. Scored: solutions found, especially non-obvious ones. Guard: each must actually solve it.
6. **Spatial construction puzzle** — build a structure meeting a goal (span a gap, bear a load, hide from sight). Trains spatial reasoning + planning. Inputs: build. Scored: structural validity + ingenuity. Guard: load/visibility simulated.
7. **Perspective-shifting puzzle** — the path only exists from a certain viewpoint/state (crouch, lantern-light, look as the companion). Trains reframing. World: hidden routes open. Scored: did you find/force the reframe yourself. Guard: the alternate view is real, not arbitrary.
8. **Metaphor & symbolism puzzle** — *"the door opens to the thing grief looks like to you."* Trains metaphorical/symbolic thinking. Inputs: draw/write/photo. World: door reads your symbol and reacts in character. Scored: symbolic coherence + originality (CAT-style + embeddings). Guard: must connect to the prompt's concept (semantic-relatedness floor) so random scribbles fail.
9. **Social/emotional dialogue puzzle** — defuse a grieving Greywarden by *reframing* its loss, not defeating it. Trains emotional + narrative creativity. Inputs: text/voice dialogue. World: NPC freed or hardened. Scored: emotional aptness + novelty of the reframe. Guard: must address the NPC's actual stated need.
10. **Invention puzzle** — *"the village needs light that the fog can't drink."* Open invention with a clear functional target. Trains applied creativity. World: invention deployed village-wide, visibly. Scored: usefulness × originality. Guard: function-tested in sim.
11. **Resource-scarcity puzzle** — solve with *less* than you'd want (deliberately starve resources). Trains frugal creativity. Scored: efficiency + ingenuity. Guard: must work within the cap.
12. **Puzzlehunt-style multi-step discovery** — chained clues across a region (carvings → a song → a hidden grove). Trains persistence + insight + synthesis. World: unlocks lore/areas. Scored: synthesis leaps. Guard: each step gated by a real sub-solution.
13. **Visual & sound-based puzzle** — match/continue a corrupted pattern by *drawing* or *humming* the missing piece. Trains visual/auditory creativity. Inputs: draw/voice. Scored: completion + expressiveness. Guard: pattern-fit floor.
14. **Moral-ambiguity puzzle** — no clean answer; *justify* your choice creatively (save the village or the freed-creature faction). Trains reframing + values reasoning. World: branches the story (§15). Scored: coherence + originality of justification, not "correctness." Guard: must engage the actual dilemma.
15. **"Solve the same problem three different ways"** — explicitly demands three distinct solutions to one obstacle. Trains flexibility directly (this is also the final-boss mechanic for flexibility-weak players, §51). Scored: distinctness of the three (category distance). Guard: all three must work.
16. **"Make something useful from unrelated objects"** — combine, e.g., a fishhook, a hymn, and rust into a tool. Trains combinational creativity. Scored: usefulness + surprise of combination. Guard: result must function.
17. **"Reframe the problem" puzzle** — the stated problem is unsolvable; the win is *redefining* it (you can't cross the chasm → you don't need to; bring the other side to you). Trains problem-reframing, a top creativity marker. Scored: detecting + executing the reframe. Guard: the reframe must satisfy the underlying need.
18. **Real-world object-transformation puzzle** — photograph an ordinary real object; transform it into the in-game artifact the puzzle needs (§52–53). Trains transfer + visual creativity, and ties play to life. Scored: aptness of transformation + originality. Guard: must depict a real, relevant object (vision check) and map sensibly to the need.

## 27. Creativity-based NPC dialogue

Dialogue is itself a creative system. Conversations frequently present **open prompts** rather than menus: an NPC poses a need or a riddle and the player *responds in their own words* (text/voice), or with a drawn/photographed offering. The companion and NPCs evaluate *how* you express yourself, not whether you hit a keyword.

- **Reactive memory:** NPCs reference your past creations and your style (§54): *"You're the one who makes weapons out of feelings. The Mire respects that. Mostly."*
- **Persuasion as creativity:** convincing the Ashen King's wardens isn't a charisma stat check; it's whether you can present something *uncatalogued* and *fitting* — originality gated by relevance (§42).
- **Trust economy:** aptness, novelty, and emotional honesty in dialogue build NPC trust, which unlocks quests, trades, resources, and story branches.

Implementation: open responses are scored by the same engine (relevance gate → creative dimensions); NPC replies are authored templates selected by `(intent bucket × creative profile × trust level)`, never free-generated text presented as canon, to protect tone and safety.

## 28. The visible creative resource / token economy

Creation is gated by **visible magical resources** so imagination operates *under constraint* (the whole pedagogical point — see §35, §40). The player always sees their wallet; bigger/rarer/more world-changing ideas cost more, forcing prioritization and cleverness rather than infinite spam.

Nine resources, each tied to a *kind* of creativity, so the economy itself teaches a balanced creative diet (full table §29). They're spent at the Creation Forge and on home-base growth, rituals, and naming-refinements; earned through nearly every activity (§30). Scarcity is intentional and tuned by the `Economy` model + `BalanceEngine`: you can't make everything, so you must decide *what is worth making* — the central creative discipline.

## 29. The nine resources (Embers, Musefire, Dreamsteel, Ink, Essence, Willpower, Memory Shards, Moon Thread, Hollow Sparks)

| Resource | Feels like | Tied to | Primary earned from | Primary spent on |
|----------|-----------|---------|---------------------|------------------|
| **Embers** | warm common spark | baseline creative energy | everything (logins, gathering, small acts) | minor creations, fuel, repairs |
| **Musefire** | bright volatile flame | originality / inspiration | novel solutions, rare-rated ideas | original effects, unique item traits |
| **Dreamsteel** | cold starlit metal | structure + symbolism | bosses, dreams, the Lull | armor, durable/symbolic gear |
| **Ink** | living shadow-fluid | visual creation | drawing acts, Inkbinder quests | drawn sigils, designs, restyling |
| **Essence** | distilled feeling | emotional charge | emotional/symbolic acts, helping NPCs | emotional-magic items, charm effects |
| **Willpower** | inner fire (also survival) | risk + persistence | overcoming Fear, bold choices | risky/high-instability creations, pushing through corruption |
| **Memory Shards** | glass holding a moment | personal/narrative depth | backstory, photos, real-world tasks | relics, anti-Fear gear, home memory-walls |
| **Moon Thread** | silver gossamer | subtlety + elegance | night events, stealth, elegant solutions | cloaks, stealth, refined finishing |
| **Hollow Sparks** | dangerous black-light motes | strangeness / the forbidden | risky wins, taming the Grey, Hollow Spark class | strange/unstable powerful effects; double-edged |

Note the deliberate overlap of fiction and pedagogy: a player who never earns **Essence** literally cannot make the emotional gear that the Lull and Fear enemies require — the economy *surfaces* a creative blind spot as a resource shortage, which the companion then gently addresses (§19).

## 30. How users earn and spend creative resources

**Earning (broad, so every play style is fed, but novelty pays best):**
main quests, side quests, daily login, daily creative challenge, survival challenges, exploration/discovery, defeating enemies (creatively > brute), defeating bosses, helping NPCs, real-world creativity tasks (§53), improving the home base, solving puzzles, building useful creations, and **naming/refining** existing creations (§37). Crucially, the *quality* of a creative act scales its payout via the hidden score — an original, elaborated, useful solution yields more (and rarer) resources than a lazy one (§35).

**Spending:** bringing ideas into the world at the Forge (cost scales with power/rarity/complexity, §34), home-base rooms/stations/decor (§47), rituals (class recognition, corruption cleansing), refining a creation's stats, and unlocking restyle variations of user art.

**Sinks & balance:** decay/corruption repair (§32) is a soft sink that rewards return; rarer resources (Hollow Sparks, Moon Thread) are intentionally scarce to make strange/elegant creations feel precious. The `Economy` model defines costs; `BalanceEngine` enforces that you can never *soft-lock* (a minimum viable path is always affordable).

## 31. Daily login rewards and daily creativity quests

Designed so a **5-minute daily** is meaningful and a long session is rewarded — without daily pressure feeling like a chore (§57).

- **Daily login:** a small Ember stipend + a "the hearth is glad you came" beat (companion line, tiny home event). Streaks grant gentle bonuses (never punishing FOMO; missing a day costs a little glow, not your progress).
- **Daily Creative Quest:** one short, fresh prompt tuned to *your* growth edges (e.g., a flexibility-weak player gets more "solve it another way" prompts). ~3–7 minutes, any input method. Yields targeted resources (often the ones you're short on, §29) and feeds the profile.
- **Daily World Event:** a small rotating happening (a wandering Cartographer, a corrupted glade to cleanse, a meteor of Dreamsteel) that makes the world feel alive and gives a reason to step in.
- **Weekly arc:** dailies ladder into a small weekly creative project (build/illustrate/compose something bigger) for a rare resource — bridging daily habit and long-session depth.

Anti-burnout: dailies are **opt-in to the streak, never gated behind it**; story progress never requires dailies. The reward for returning is *the world stays bright and your home stays healthy* (§32), which is intrinsic, not a coin.

## 32. How inactivity causes decay and corruption

Absence has *gentle, reversible* consequences that create a reason to return without punishing real life:

- **Graceful grace period:** a few days off does nothing (we respect adult schedules). Beyond ~1–2 weeks, the **Grey creeps in**: the home dims, plants wilt, creations gather dust and lose a little glow, the companion grows quiet/concerned, and faint corruption appears near the home (§48).
- **It changes atmosphere, never deletes:** decay desaturates and weakens (small temporary stat dips, cosmetic cracking) but **never destroys** creations or progress. Everything restores through **creative restoration quests** on return (relight the hearth, remake a faded sigil, sing the garden back).
- **Tied to creative health, not just time:** repeating low-effort ideas or avoiding growth also invites mild corruption even if you log in — so the pressure is toward *genuine* creativity, not mere check-ins (§35, §38).
- **Welcome-back, not guilt:** returning after a long absence triggers a warm, slightly melancholy sequence (the Ashkeeper's line in §21), framing it as homecoming. The emotional design goal: *missing it feels like missing a place you love,* which is the healthiest possible retention driver. Implemented via timestamped world-state + a decay scheduler (`TECH_ARCHITECTURE.md`).

## 33. How AI interprets user ideas into balanced game objects

AI is used **narrowly and powerfully**: to translate a player's free creative expression into a *balanced, art-styled, named* in-world object that fits the handcrafted game. It does **not** design the game, write canon lore, or generate the world (§15). The pipeline (full version in `TECH_ARCHITECTURE.md`, contract in `AIInterpretationService.swift`):

1. **Capture** the idea (text/voice→text/drawing/photo/arrangement) + context: player level, region, resources held, class lean, hidden profile, and the active constraint.
2. **Score** the idea's creativity (relevance gate → dimensions; §39–42). This score drives *both* rewards and the object's creative stats.
3. **Interpret** via a constrained LLM call (server-side Edge Function) with a **strict JSON schema** and the game's balance rules in the system prompt. The model proposes: item type, traditional stats, creative stats, unique effect, art-style descriptor, and a suggested name.
4. **Validate & clamp** against the `BalanceEngine`: stat budget for the player's level/region, effect-from-an-allowlist mapping, resource cost, instability. Anything out of bounds is *reshaped*, not rejected (§34).
5. **Restyle** the visual (user art → cozy dark-fantasy via palette-map/outline/lighting, or a generated stylized sprite/3D-decal keyed to the descriptor; §52).
6. **Materialize**: the object enters the world permanently, named by the player (§37), remembered by NPCs/companion.

**Worked example (verbatim from the brief):** player says *"a sword that shoots honey to slow enemies down."*
→ relevance gate passes (clear, fitting); originality moderate, usefulness high, strangeness mid.
→ LLM proposes a slow-debuff melee weapon with a ranged resin effect.
→ BalanceEngine clamps for an early-game player: ranged effect becomes short-range cone, slow capped at 30% for 3s with a cooldown, modest damage, costs Embers + a little Essence.
→ restyled into a dark-fantasy look: amber resin, beeswax-wrapped hilt.
→ result: **"Honeyfang"** (player-named) — early-game weapon, slows the Tidy, strong vs. fast enemies, useless against the slow Dim (encouraging variety). Powerful-feeling, not game-breaking.

## 34. How overpowered ideas are nerfed without killing creativity

The rule: **never reject an idea; right-size it.** The player must always feel "my idea is now real" — just appropriate to their progress. Mechanisms:

- **Stat budget per level/region:** the `BalanceEngine` allocates a total "power budget." A wildly strong idea keeps its *identity* but is scaled into budget (range→cone, infinite→cooldown, instant-kill→heavy-but-survivable, "destroys all enemies"→"staggers nearby enemies once").
- **Cost scaling:** more powerful/rare/world-changing → more (and rarer) resources, often more than the player can afford yet — so big ideas become *aspirations* you grow toward, not early exploits.
- **Instability tax:** very high originality/strangeness raises the `Instability` stat — bigger upside, real chance of backfire — so power has drama and risk, not a free lunch (and it makes the Hollow Spark path thrilling).
- **Conservation of identity:** clamping preserves the *creative essence* and the unique effect's *flavor*; only magnitudes/ranges/cooldowns move. The player sees "Honeyfang slows enemies," never "your idea was denied."
- **Growth unlock:** the *same* idea can be **re-forged stronger later** as you level/earn resources (§36 refinement) — so ambition is banked, not lost. This converts "OP" attempts into long-term goals, which *rewards* bold ideation instead of discouraging it.

## 35. How weak or lazy ideas make the game harder (without shaming)

Low-effort, obvious, generic, or repetitive creativity is answered **through fiction, never a scolding popup.** Consequences (all reversible by improving):

- **Weaker creations:** a generic idea yields a low-creative-stat item — less magical, less durable, easily *countered/catalogued* by Conformity enemies (who specifically resist the predictable).
- **Fewer/poorer resources:** payouts scale with the hidden score; lazy acts earn the common Embers but little Musefire/Hollow Sparks — so the player slowly *feels* under-resourced for ambitious making.
- **World resistance:** repeatedly low-effort areas dull and harden — enemies tougher, puzzles stiffer, NPCs lose hope (their dialogue saddens, some quests close), color drains. The world becoming *grayer* is the feedback.
- **Adaptive enemies:** repeating one solution makes the Grey "learn" it (that tactic weakens here; Shadows use it against you) — pressure toward variety.
- **The companion notices, kindly:** it gets a little quieter, then *curious/longing* for something new (§19) — concern, never contempt.

The loop is **intrinsic and recoverable:** the world visibly brightens the moment the player invests more, so they learn *creativity → the world comes alive* by direct experience. This is operant shaping, not punishment — and it's why we *never* show a low score: the gray forest is the only feedback needed (§42, §56).

## 36. How permanent creations work

Player creations are, by default, **permanent fixtures of the world** — this is core to long-term attachment and the "I built this" feeling.

- **Persistence:** every made item, sigil, structure, freed creature, restored glade, and home addition is saved to the player's world-state (local + cloud) and persists across sessions and devices, named and attributed.
- **Presence:** creations are *referenced* by NPCs/companion and can be *used by the world* (a bridge you built becomes a route NPCs walk; a light you invented gets installed village-wide). The world accumulating *your* fingerprints is the payoff.
- **Refinement, not replacement:** rather than deleting, the player can **re-forge/refine** a creation later — spend resources to raise stats, evolve its form, or re-interpret it at a higher level (§34 growth unlock). Names and history carry forward (the Honeyfang you made on day 3 can become the Honeyfang Reborn on day 90).
- **The only thing that changes them:** controlled *decay* of specific aspects tied to neglected creative metrics (§38) and absence-corruption (§32) — both reversible, never deletion. Permanence + reversible decay is what makes the world feel *alive and accountable* rather than static or punishing.

## 37. How users name their creations

Naming is a **first-class creative act and a powerful attachment + assessment hook.** The player names every major creation: weapons, armor, spells, rooms, artifacts, creatures, structures, rituals, and companion forms.

- **Why it matters mechanically:** a *fitting, original* name grants a small creative-stat bonus and more Memory Shards (names are scored lightly for originality/aptness/emotional charge — `CREATIVITY_SCORING.md`). Lazy names ("Sword2") still work but earn nothing extra.
- **Why it matters emotionally:** naming binds the player to the creation; the world *uses the name* (NPCs speak it, the codex records it, the companion reminisces). This is a cheap, deep retention and identity lever.
- **Refinement:** players can rename/refine on re-forge (a renamed creation can shift how NPCs regard it — a fearsome name spreads fearsome rumors). The naming UI is intentionally tactile and unhurried (handwritten-feel input), treating the act as a small ceremony.

## 38. How specific creation aspects decay based on weak/neglected metrics

A signature system: a creation can **partially distort along the exact creative dimension its maker is neglecting** — a living, diagnostic feedback that teaches without text. Mapping (each reversible by demonstrating that dimension elsewhere):

| Neglected dimension | How the creation visibly changes | In-world consequence |
|---------------------|----------------------------------|----------------------|
| **Elaboration** | looks unfinished, sketchy, brittle; edges fray | lower durability; chips in combat |
| **Originality** | desaturates toward gray, "common" silhouette | Conformity enemies resist/catalogue it faster |
| **Flexibility** | calcifies to a single use; other affordances dim | works in one situation only; fails when reused elsewhere |
| **Usefulness** | beautiful but inert; effect flickers | looks magical, underperforms under pressure |
| **Risk-taking** | overly tidy, "safe," small | low ceiling; never crits/surprises |
| **Emotional expression** | hollow, cold light; mute | reduced magical power vs. Fear/Shadow; NPCs unmoved |
| **(Absence/time, §32)** | dust, lost glow, hairline cracks, creeping gray | mild temp stat dips; attracts corruption |

This is intentionally **specific and legible**: a player whose work always lacks emotion will, over time, watch their beloved creations grow *cold-lit and quiet* — a felt, fictional nudge to make something that *aches.* Restoration is always a creative quest, never a purchase-only fix, so healing the world = practicing the missing skill. The same mapping seeds the **personalized final boss** (§50): your most-neglected dimensions are the ones the endgame is built from.

---

# Part IV — The Hidden Creativity Engine

> This part summarizes the design intent. The full research mapping, formulas, model choices, and anti-gaming detail live in **`CREATIVITY_SCORING.md`**, and the runnable contract lives in `CrearoCore/Sources/CrearoCore/Engines/CreativityScoringEngine.swift`.

## 39. The hidden creativity scoring system

Every creative act produces a hidden, multi-dimensional **CreativityScore**. The player **never sees raw numbers** ("Originality: 73"). Instead the score is expressed only as *world state*: color, brightness, enemy counterability, resource payout, badges, titles, NPC/companion dialogue, unlocked areas, and prophecy reports (§43–45).

A score is computed in three stages:
1. **Relevance/usefulness gate (pass/fail-ish, 0–1 multiplier):** does the response actually address the prompt/constraint and function in the world? Random nonsense fails here and earns little, no matter how "novel" (§42). This is the single most important safeguard.
2. **Dimensional scoring (each 0–1):** Originality, Fluency, Flexibility, Elaboration, Usefulness, Risk-taking, Emotional expression, Symbolic thinking, plus context flags (reframing detected, constraint satisfied, modality used).
3. **Trajectory update:** the act updates the player's running **CreativeProfile** (per-dimension running estimates + trends), weighted by recency and effort, robust to one-off flukes (§44).

Outputs consumed by the rest of the game: a per-act reward multiplier, the new creation's creative stats, profile deltas, and trigger checks for badges/class recognition/region unlocks/boss composition.

## 40. The creativity-research principles behind the scoring

The model is grounded in established creativity science (citations in `CREATIVITY_SCORING.md`):

- **Guilford — divergent vs. convergent thinking:** divergent (generating many varied ideas) is measured by fluency/flexibility/originality across a player's responses; convergent (selecting/forming a working solution) is measured by the usefulness/constraint-satisfaction gate. Crearo deliberately trains *both*, since real creativity needs the divergent leap **and** the convergent landing.
- **Torrance (TTCT) dimensions:** the four classic indices map directly — **Fluency** (number of relevant ideas), **Flexibility** (number of distinct categories), **Originality** (statistical rarity of responses), **Elaboration** (amount of detail). Plus TTCT-figural's **resistance to premature closure** → our "did they push past the first obvious answer" signal.
- **Originality as statistical rarity (Torrance) + semantic distance (Divergent Association Task, Olson et al. 2021):** originality is scored both as *rarity vs. the player population on the same prompt* (§41) and as *semantic distance* via text/image embeddings — with the DAT's known caveat (random items score high) explicitly defended against by the relevance gate (§42).
- **Amabile — Consensual Assessment Technique (CAT):** the "gold standard," where expert consensus defines creativity. We can't put human judges in real-time, so the engine is **calibrated** against CAT-style ratings (a panel — and/or an LLM-judge ensemble validated against humans) on a sample corpus, so automated scores track human judgment.
- **Creativity-under-constraint & problem-reframing:** constraint-satisfaction puzzles and the resource economy operationalize the well-supported finding that constraints can *boost* creativity; reframing puzzles target problem-finding, a hallmark of high creativity.
- **Domains beyond verbal:** visual creativity (drawings), narrative creativity (writing/dialogue), and emotional expressiveness are scored in their own channels (image/text models + CAT calibration), so the game values *all* the modalities it offers, not just words.
- **Growth orientation (Dweck-adjacent):** the system rewards *trajectory and range*, never a fixed verdict — the design intent is creative-confidence growth, so feedback is always "you can become," never "you are (not)."

## 41. How rarity is measured compared to other users on the same prompt

Originality's "statistical rarity" needs a *population baseline per prompt.* Implementation (detail + SQL in `CREATIVITY_SCORING.md` and `supabase/schema.sql`):

- Each structured prompt (daily quests, puzzles, character-creation facets) has an ID. Every response is embedded (text via a sentence-embedding model; images via an image-embedding model) and stored in Postgres with **pgvector** under that prompt ID.
- **Rarity score** = how far a response sits from the *dense center* of all responses to that prompt: low average cosine similarity to nearest neighbors / low local density = rare = original. Operationally a percentile: "this idea is more novel than 88% of responses to this prompt."
- **Tech:** Supabase `pgvector` with an **HNSW** index (the 2026 default; sub-10ms nearest-neighbor at the scales we'll see). The *same* embedding model must be used for all comparisons (mixing models yields garbage) — enforced by versioning the embedding model per prompt.
- **Cold-start:** before a prompt has a population, fall back to (a) semantic distance / DAT-style scoring and (b) an LLM-judge originality estimate calibrated to CAT; blend in population-rarity as data accrues. New prompts therefore degrade gracefully.
- **Privacy:** only embeddings + minimal metadata are pooled for baselines — never raw personal content across users without consent; pooling is opt-in-by-design and anonymized (§62).

This population baseline is also a genuine **business/research asset** over time: a large, prompt-anchored corpus of human creative responses with novelty distributions.

## 42. How the game avoids rewarding random nonsense

The DAT literature is explicit that pure novelty metrics can be gamed by randomness (stochastic outputs score as highly "divergent" while being meaningless — Olson et al., 2021). Crearo defends against this on multiple fronts:

1. **Relevance/usefulness gate first (§39):** originality is only *credited after* a response clears a semantic-relatedness floor to the prompt **and** (where applicable) passes a functional sim-check (does the bridge hold? does the weapon stop the Tidy?). Novelty without fit scores near zero.
2. **Originality = rarity *of fitting* responses:** the population baseline (§41) is computed among responses that *passed the gate*, so "rare" means "rare among things that work," not "rare among all keystrokes."
3. **Coherence checks for open media:** drawings must have structure/intent (not scribble-noise) via simple image stats + an aptness model; text must be coherent and on-topic; voice must transcribe to relevant content.
4. **Effort ≠ length:** elaboration rewards *meaningful* detail, not padding; repeated tokens, copy-paste, and filler are detected and discounted.
5. **Anti-gaming on rarity:** trivially unique gibberish clusters as its own low-density region but fails the gate, so it never converts to reward. Deliberate "weird but empty" spam is caught by the fit + coherence layers.
6. **Trajectory robustness:** the profile updates on trends, so a single lucky or gamed input can't swing standing (§44).

Net: the player is rewarded for being **novel *and* apt** — exactly the two-factor definition of creativity in the research (novelty × usefulness). This is the design's scientific backbone, not a bolt-on.

## 43. Badge and magical growth-path system

Since scores are hidden, *recognition* is delivered as **diegetic badges, titles, and growth paths** — collectible, mythic, and motivating:

- **Badges = "Marks"** earned for creative milestones, framed in-world: *Mark of the Unrepeating* (high flexibility — solved many problems differently), *Mark of the Aching Light* (high emotional charge), *Mark of the First Leap* (a bold risk that paid off), *Mark of the Patient Hand* (deep elaboration), *Mark of Common Things Made Holy* (Relicseer real-world transformations).
- **Growth paths = constellations:** each creative dimension is a star-path in a personal "Sky of Makings" that lights up as you grow on that dimension — a beautiful, glanceable progression that *is* the score made magical, never a bar chart.
- **Titles** evolve and are spoken by NPCs (§54): "the Maker of Feeling-Weapons," "She Who Draws Doors."
- Badges/titles **gate nothing essential** (so they're celebration, not grind) but unlock cosmetic flourishes, rare resource trickles, and special NPC interactions.

## 44. The personal creative profile system

Each user has a private **CreativeProfile**: per-dimension running estimates (Originality, Fluency, Flexibility, Elaboration, Usefulness, Risk, Emotional, Symbolic), trends over time, modality preferences, problem-type tendencies, repetition patterns, response speed, constraint-handling, and consistency of return. It is the brain that personalizes classes (§14), region order (§46), companion tone (§19), NPC memory (§54), reward tuning (§30), the daily quest selector (§31), decay targeting (§38), and the final boss (§50).

Design principles:
- **Trajectory over verdict:** estimates are recency-weighted with uncertainty; the game cares about *change*, not a fixed label, and is hard to swing on one input.
- **Patterns it watches (from the brief):** how original/rare/detailed ideas are; how many solution *types* are tried; idea speed; boldness; repetition of solution patterns; over-reliance on combat; avoidance of emotional/visual/symbolic/narrative channels; practicality/fit; ability to solve one problem multiple ways; creating under constraint; whether ideas strengthen over time; consistency of return.
- **Blind spots → gentle pressure:** an avoided channel surfaces as a resource shortage (§29), a companion longing (§19), a region that demands it (§9), and finally the boss (§50) — a coherent, escalating, *kind* push toward range.
- Stored privately per user (`CreativeProfile` model), encrypted, never shown raw, never sold as individual data (§62).

## 45. Mythical, prophecy-style personal growth reports

Periodically (weekly + at milestones) the player receives a **growth report written as prophecy/myth**, not analytics. It is the hidden metrics *translated* into the world's voice. Rules: poetic, specific to *their* actual changes, always honest, always hopeful-but-not-hollow.

Mapping examples (metric → prophecy):
- *Flexibility +:* "The Mirrorwood no longer sees only one path in you. Where one road ran, three now branch."
- *Originality still low:* "The Grey still hums your name and knows the tune. Make it a song it cannot finish."
- *Emotional expression rising:* "Your makings have begun to ache. The dead bells of the Lull turned, just slightly, toward you."
- *Risk-taking emerging:* "You stepped where the floor was not yet drawn — and it held. The Cartographer marks a road that wasn't there yesterday."
- *Return after absence + restoration:* "The dust is gone from the high shelf. The house exhaled. So did I."

These reports are **assembled from authored phrase-banks keyed to metric deltas** (not free-generated), so they're safe, on-tone, and grounded in real change. They double as the primary "you are growing as a creative person" payoff — the product's deepest promise, delivered as myth.

---

# Part V — Progression, Home & Bosses

## 46. Unlockable areas and progression

Progression is gated by **demonstrated creative range**, not XP grind — the map is a diagnostic (§9). You advance the main story whenever you choose, but *new regions* open when you prove you can do what they require:

- **Range gates:** the Hush Mire opens once you've solved problems in ≥2 distinct ways (flexibility threshold); Greymarch opens once you've taken at least one genuine creative *risk* that paid off; the Lull opens once you've made something with real emotional charge. These gates are felt as story ("the road only appears to those who…"), never shown as requirements.
- **Soft, not hard:** if a player is "stuck" lacking a dimension, the daily quests, companion, and a tutorializing NPC funnel them toward practicing it — so a gate is a *guided growth prompt*, not a wall. There is always a path forward.
- **Lateral unlocks:** classes (§14), home rooms (§47), companion forms, restyle options, and rare resources unlock continuously from creative behavior, so there's always nearby progress even between regions.
- **Backtracking rewards:** re-entering an early region with new skills reveals new content (a perspective puzzle you couldn't reframe before), making the world deepen as you grow.

## 47. Home base growth system

The wooden house (§10) is the **persistent heart** of the game — a customizable home that grows as a *portrait of the player's creativity*. It starts cozy-but-empty and accretes, from the player's creations and choices:

- **Rooms & structures:** new rooms (library, workshop, greenhouse, shrine, gallery), crafting stations (forge, loom, alchemy, drawing desk), portals to regions, balconies, cellars.
- **Living collections:** **memory walls** (your photos/sigils/writings, restyled), **trophy/gallery rooms** (named creations on display), armor stands & weapon racks (your forged gear), a **magical garden** (grows from emotional/organic creations; wilts under neglect, §32), companion nooks.
- **Companions & freed creatures:** the home becomes home to the creatures you freed (§17/§25), a wordless reflection of your mercy.
- **Style is yours:** layout, palette, and décor are player-arranged (object-arrangement input), itself a scored creative act (elaboration/aesthetic). Two players' homes look nothing alike.
- **Function + feeling:** rooms grant real benefits (stations enable crafts; a library boosts Mythweaver tools; a shrine cleanses corruption) and emotional payoff (the place *remembers* everything you've made). It's the retention anchor: people return to a *home they built*, not a level select.

## 48. Home base corruption system

The home is **not permanently safe** — a deliberate stakes-and-return mechanic, always reversible (§32):

- **Triggers:** prolonged absence (§32), repeated low-effort creativity (§35), avoiding growth/range, or losing key story beats.
- **Manifestation (atmosphere, not destruction):** rooms desaturate; plants wilt; creations crack and lose glow; the companion grows quiet and worried; companion/creature behavior shifts (they hide, dim); the Grey's hum seeps in; faint Greywardens may appear at the edge of the property.
- **Severity tiers:** *Dusting* (cosmetic, instant to fix) → *Fading* (minor temp stat dips, small corruption motes) → *Grey-touched* (a room "locks gray," a creature won't speak, mild combat at the threshold). Never reaches deletion.
- **Restoration = creative quests, not payments:** relight the hearth with a *new* making; remake a faded sigil *differently* (flexibility); sing the garden back (emotional); evict a Greywarden by presenting the uncatalogued (originality). Healing the home is *practicing the very skills you'd been neglecting* — the corruption targets your weak dimension (§38), so restoration is targeted growth.
- **Emotional frame:** corruption is wistful, never punitive — "the house misses you," not "you failed." Restoring it is one of the most satisfying loops, which is exactly why mild corruption is a *gift* to the design, not a stick.

## 49. Boss progression

Bosses are **shadow-encounters** that escalate the "creativity vs. your own patterns" theme, each region's guardian tuned to that region's dimension and to *you*:

| Boss | Region | Tests | Mechanic |
|------|--------|-------|----------|
| **The Hollow Stag** | Mirrorwood | originality / repetition | mirrors your *most-used* tactic; you must beat it a *different* way (first "shadow") |
| **The Tide of Bells** | Hush Mire | flexibility | the same attack works only once; demands a new solution each phase |
| **The Ashen King** | Greymarch | risk / reframing / conformity | a *debate-and-siege* boss; brute force fails; won by uncatalogued, reframing creativity and by argument |
| **The Forgefather** | Emberreach | usefulness | beautiful-but-useless creations bounce off; only *working* inventions land |
| **The Mascaret** | the Lull | emotional / symbolic | impervious to logic/force; moved only by genuine emotional/symbolic expression |
| **(personalized final)** | the Unwritten | your weakest dimensions | see §50 |

Each shadow boss is a *rehearsal* for the final boss: it isolates one dimension and forces growth on it, so by the endgame the player has practiced every dimension the finale will demand. Bosses are beatable many ways (a Mythweaver and a Forger defeat the Ashen King very differently), and the *method* is scored and remembered.

## 50. The totally personalized final boss

The final boss is **generated per player from their hidden CreativeProfile** — it is the Sameness (§16) wearing the mask of *your* specific creative weaknesses. No two players fight the same boss. Design:

- **Composition:** at endgame, the engine selects the player's **2–3 weakest / most-neglected dimensions** (lowest, most-stagnant, or most-avoided in the profile) and assembles a multi-phase boss where **each phase is immune to your crutches and only yields to a dimension you've been avoiding.** It also mirrors your *single most-overused* tactic and turns it against you (the ultimate Shadow).
- **It knows you:** it speaks in your own named creations and patterns ("You made the Honeyfang, and the Honeyfang, and the Honeyfang again. I am every idea you were too afraid to have."). It is assembled from your history — the most personal moment in the game.
- **Winning = growing past the weakness, in the moment:** you cannot out-gear it; you must *demonstrate the missing creativity live* (solve its puzzle-phase three different ways; make something genuinely original it hasn't catalogued; land an emotionally-charged creation; take a real risk). The fight is the thesis: *defeating the force of sameness in the world means defeating it in yourself.*
- **Partial unveiling:** only here does the villain become "visible" — and what you see is unmistakably built from *you*, then, as it breaks, a glimpse of the formless Pattern behind it (§16). Catharsis = recognition.
- **Fair + guided:** the run-up (Act 5) heavily features your weak dimensions in lower-stakes practice (and the prophecy reports foreshadow it), so the finale is a *winnable culmination*, never a cruel gotcha. Implemented by `BossComposer` reading the `CreativeProfile` (see model + `CREATIVITY_SCORING.md`).

## 51. Examples of final bosses based on different creative weaknesses

| Player's demonstrated weakness | Final boss form | Phase mechanics (must do to win) |
|--------------------------------|-----------------|----------------------------------|
| **Low originality** (predictable) | **The Echo Choir** — a chorus that instantly copies anything it has seen before | every action you've used in the game is *nullified*; you must present creations/solutions it has *never catalogued*. Predictability deals **0**. |
| **Low elaboration** (thin/unfinished) | **The Unfinished** — a half-drawn colossus of brittle sketch-lines | only richly *detailed*, multi-layered creations can wound it; thin ideas shatter on contact. Forces depth. |
| **Low flexibility** (one-trick) | **The Single Road** — a labyrinth-beast with one mouth for each repeated tactic | each phase locks out the solution you used last; you must solve the *same* obstacle **three distinct ways** in sequence. |
| **Risk-averse** (safe/small) | **The Sealed Door** — a wall that only opens to a leap | progress requires bold, high-Instability, unhedged choices; "safe" actions don't even register. Rewards nerve. |
| **Combat-over-reliant** | **The Anvil That Hits Back** — armored in your own damage | direct attacks *heal* it and empower its counter; only non-combat creativity (illusion, negotiation, reframing, emotional) advances. |
| **Avoids emotion/art** | **The Cold Mirror** — a beautiful, feelingless reflection of you | logic and force pass through it; only genuinely emotional/symbolic/expressive creations land. Forces vulnerability. |
| **Over-uses one creation type** | **The Glutton of Patterns** — grows stronger each time you repeat your favorite move | it *eats* your signature tactic; you must win using your *least-used* tools and channels. |
| **Impractical-nonsense maker** | **The Beautiful Wreck** — gorgeous machines that never quite work | only creations that are original **and** functional (pass the usefulness gate, §42) can solve its puzzle-traps; pretty-but-broken ideas fail. Forces the convergent landing. |
| **Neglected the world** (absence/decay) | **The Forgetting** — made of your own dust, faded creations, and gray rooms | it wields your *corrupted* creations against you; you must *restore* and *remake* them mid-fight (the corruption/restoration loop as a boss). |

In every case the win condition is *become the thing you weren't.* The boss is the most honest mirror in games — and the most personal possible ending.

---

# Part VI — User Creativity In, World Out

## 52. How user-created photos, drawings, voice, and writing become part of the world

The pipeline that turns raw player expression into cohesive, art-styled, *permanent* world content (the "restyle, don't paste" rule, §8; tech in `TECH_ARCHITECTURE.md`):

- **Drawings →** vectorized/cleaned, palette-mapped to the region's scheme, outlined, and given the world's lighting → become sigils, item decals, banners, drawn-door spells (Inkbinder), or 3D billboard/decal props. The *composition and intent* are preserved; the *finish* is unified.
- **Photos (real objects) →** subject is segmented (vision model), reinterpreted into a dark-fantasy material/artifact keyed to its shape/texture/color, and *named* by the player → a relic, armor material, building texture, or creature seed (Relicseer). A photo of a rusty key → "the Key of Small Locks," a relic that opens one thing that shouldn't open.
- **Voice →** transcribed (on-device where possible) for content + scored for expressiveness; can seed a spell's name, a creature's "voice" cadence, or the companion's mimicry. Raw audio stays private (§62); we keep derived features, not necessarily the clip.
- **Writing →** parsed for content, emotion, symbol, and originality → becomes item lore, NPC-spoken names, spell descriptions, or narrative-magic effects (Mythweaver). Your written backstory line seeds NPC references months later.
- **Object arrangements →** the spatial composition becomes a buildable layout (a room, a ward, a puzzle solution) and is scored for elaboration/aesthetic.

Cohesion guarantee: everything routes through the **Restyle service** so the world never looks like a clip-art collage; player essence is retained via composition/feature preservation while the surface is conformed to Crearo's look. This is what lets *deeply personal* content live in a *handcrafted-feeling* world.

## 53. Real-world creativity exercises that feed into the game

A signature differentiator: the game periodically sends the player into *the real world* and brings the result back as magic — bridging play and life, and training transfer of creative skill.

Examples (each is a scored creative act, §39, with the §42 anti-nonsense guards — vision-verified to be a real, relevant object):
- *"Find something ordinary and photograph it as if it were enchanted."* → becomes an artifact/material; rewards Relicseer growth + Memory Shards.
- *"Photograph a texture the Mire could be made of."* → becomes a building/armor material.
- *"Capture something that looks like how courage feels."* → emotional/symbolic task → Essence, anti-Fear gear.
- *"Make a tiny sculpture from things on your desk and photograph it"* → object-transformation → a creature seed or relic.
- *"Record the most unusual sound near you"* → seeds a sound-based spell or a Rootspeaker effect.
- *"Draw the room you're in as a place in the Wending Lands"* → a new home-décor set or a map vignette.

Design guardrails: tasks are **optional, safe, indoors-doable, and never location-tracking** (no "go somewhere"); they respect time and privacy (§62); and they always *pay off visibly in-world* so they feel like magic, not homework (§57). These tasks are also the strongest **organic-sharing** hooks (§60) — "look what my coffee mug became."

## 54. How NPCs remember the player's creative style

NPCs maintain a lightweight read of the player's **style signature** (from the profile: dominant modality, tone, dimensions, signature creations) and reference it in authored, slotted dialogue:

- **Recognition:** *"You're the one who fights with feelings, not iron. The Mascaret will want to meet you."*
- **Tailored quests/trades:** an NPC who values originality offers richer rewards to a high-originality player and gently challenges a predictable one (*"Bring me something I couldn't guess."*).
- **Trust & rewards shift by style:** humor opens some NPCs and annoys others; grim elegance impresses the Court's exiles; safe conformity earns the Greywardens' (unsettling) approval. The *same* world responds differently to *who you are as a maker*.
- **Long memory:** NPCs recall *named* creations and past choices across regions and sessions (e.g., a creature you freed in the Mirrorwood vouches for you in Greymarch). Implemented via the shared `CreativeProfile` + a per-NPC relationship/memory record; dialogue is template-selected, never free-text canon.

## 55. How the companion remembers and reacts to the player

The companion is the most intimate memory system (§18–19):

- **Remembers specifics:** names your creations, recalls how you solved past problems, notices your patterns and repetitions, tracks your moods of making.
- **Reacts in character:** delight at genuine novelty, gentle worry at neglect, teasing at repetition, awe at risk, comfort at emotional pieces — tone set by your style and your stated preference.
- **Coaches invisibly:** voices the profile's growth edges as *wishes/curiosities*, never metrics (§19) — "make me something that scares you a little."
- **Grows with you:** accretes your creations' features (color/horns/texture), gains abilities mirroring your strengths, and dims/quiets under neglect then re-brightens on return — a constant, living mirror.
- **The relationship is the retention:** people return for *someone who remembers what they made.* Implemented as a small persistent `Companion` state (tone vector, memory of recent named creations, evolving form) updated by the scoring engine; lines are authored + slotted for safety/tone.

## 56. How failure transforms the world instead of ending the game

Crearo has **no "Game Over."** Failure — losing a survival meter, a weak creative response, a lost fight, a neglected world — *changes the world and continues the story,* teaching through consequence, never shame:

- **Survival failure** → pulled back to a hearth, the world a little grayer, a wistful companion line, maybe a corrupted patch to later restore — *not* a death screen.
- **Weak creative response** → a weaker creation, fewer rare resources, a tougher/duller area, a saddened NPC — all *reversible* by doing better; the gray world is the lesson (§35).
- **Lost boss/encounter** → the boss *adapts and the region shifts* (more corruption, a changed route), and you try a *different* approach — failure forces range, which is the point.
- **Neglect** → corruption (§32/§48), restored by creative quests.
- **Tone:** every failure is framed as the Grey *gaining ground,* and every recovery as *making the world live again* — so setbacks raise the stakes and the catharsis of return, instead of breaking flow or self-esteem. This is the emotional safety net that lets players take the creative risks the game is trying to teach (§57).

---

# Part VII — Product, Technology & Business

## 57. How the game stays fun instead of feeling like homework

The single biggest product risk is that this becomes "a creativity test with a fantasy skin." Defenses, baked into design:

- **Game first, training never named.** No scores, no "exercises," no quizzes. You light a fire, free a deer, build a bridge, beat a stag. The creativity training is *entirely* a side effect of fun verbs.
- **Fiction is the feedback.** The only feedback is world state — color, the companion, NPCs, loot. The player experiences *cause and delight*, not assessment.
- **Low stakes, high whimsy.** Failure is wistful, not punishing (§56); the tone is cozy; the companion is charming. Creative risk feels *safe and playful.*
- **Always a payoff in the world.** Every creative act *visibly changes something* (a glade re-colors, a room grows) — intrinsic reward, immediate.
- **Respect the player's time and dignity.** No FOMO dailies, no shame, no nagging; opt-in real-world tasks; adult pacing.
- **Craft and beauty.** Cozy art, great audio, satisfying making-haptics. People stay for *vibes and a home they love*, and grow creatively as a bonus they only notice in the prophecy reports.

The test we hold every feature to: *"Would this be fun if there were no hidden creativity system at all?"* If not, it's cut.

## 58. Long-session gameplay design

Built to reward 20–60 minute sit-downs (and longer), unlike snackable mobile games:

- **Layered goals per session:** a survival need + a story thread + a creative set-piece + a home improvement — enough texture to sink in, with natural 5-minute exit points (it auto-saves; the world persists).
- **Exploration depth:** semi-open regions with hidden paths, puzzlehunt chains (§26), and backtracking payoffs reward sustained attention.
- **Making is absorbing:** the Creation Forge and home-building are "flow" activities people lose time in (think the satisfaction of a deep crafting/decoration loop).
- **Pacing curve:** calm traversal → rising survival/atmosphere tension → a creative climax (puzzle/boss/forge) → cozy return home and reflection (prophecy beat). A satisfying session shape, repeatable.
- **Comfort:** iPad support, controller support later, generous text, no twitch reflexes — friendly to long, relaxed play.

## 59. Daily quests and long-term retention

Two-tier retention (validated by the cozy/self-care market — Finch's ~10M DAU shows daily-habit + emotional-attachment loops work):

- **Daily (habit):** login warmth + one tailored creative quest + a world event; keeps the home bright and feeds growth (§31). Optional, never punishing.
- **Long-term (depth):** the things people stay months/years for — world-building, a home they built, boss progression, emergent classes, evolving powers, the companion relationship, named-creation legacy, prophecy growth reports, and the slow personal final-boss arc.
- **Monetization aligned to retention (detail in `ROADMAP.md`):** premium up-front *or* free-with-gentle-subscription (cosmetic home/companion sets, extra restyle variations, more daily creative prompts, a "patron of the hearth" altruistic framing à la Finch's web subscription). **No** pay-to-win, no competitive pressure, no aggressive energy gates — the cozy genre punishes those (market data: ~27% lower ARPU but far higher retention/goodwill; we monetize depth and identity, not friction).
- **Why retention is defensible:** the product literally *remembers everything the user has ever made and who they're becoming.* The switching cost is emotional and personal — the strongest moat a creative app can have.

## 60. Eventual social sharing while keeping the core private

The core experience is **private and single-player** (your inner creative world should feel safe). Social arrives later, opt-in, and *additive*:

- **Share artifacts, not your soul:** export/share a *single* creation, your restyled real-world transformation ("my mug became a relic"), your home's gallery, or a prophecy card — beautiful, shareable images/short clips. Strong organic-growth hooks (§53), zero pressure to share the private profile.
- **Asynchronous, cozy social (Horizon 3):** "visit a friend's world" read-only; leave a creative *gift* (a made object) at another's hearth; community daily-prompt galleries (opt-in, moderated, §62). The cozy market shows shared/visitable spaces boost retention markedly — but we keep it *non-competitive and non-comparative* (no leaderboards of "creativity," ever — that would poison the psychological safety the whole design depends on).
- **Never social-by-default:** profiles, scores, and the personal boss stay private forever. Sharing is a *gift economy*, not a status game — consistent with the product's soul.

## 61. iOS-only technical architecture (summary)

Full detail in **`TECH_ARCHITECTURE.md`**; the repo implements the non-3D layers of this.

- **App:** native **Swift + SwiftUI** for all 2D UI/menus/making-surfaces; **RealityKit** (the modern, native SceneKit successor — best fit for "simple lightweight 3D" on Apple hardware) for the 3D world. Unity-as-a-Library is the documented escape hatch if 3D scope outgrows RealityKit (cross-platform later).
- **Architecture:** **MVVM + a clean, protocol-oriented service layer**, with platform-agnostic logic in a Swift Package (**`CrearoCore`**) so models, the scoring engine, balance, and economy are unit-testable without the app or a device. Dependency injection via a simple container; the data layer is **swappable behind protocols** (so we can move between backends without touching features).
- **Backend (recommended): Supabase** — Postgres + Auth (incl. **Sign in with Apple**) + Storage + Edge Functions, and crucially **`pgvector`** (HNSW) for the originality/rarity engine (§41), which is the deciding factor. **CloudKit** is used optionally for large *private* user media (drawings/photos/voice) to cut cost and maximize privacy. **Firebase** is documented as the alternative (faster MVP, weaker fit for vector analytics). Rationale + comparison table in `TECH_ARCHITECTURE.md`.
- **AI:** server-side **Edge Functions** broker all LLM/vision/embedding calls (keys never on device), enforce the JSON schema + balance rules (§33), and run the embedding/rarity pipeline. On-device Core ML / Vision used for cheap, private pre-checks (speech-to-text, image segmentation, coherence gates).
- **Offline & sync:** local-first persistence (SwiftData/Core Data or GRDB) with a timestamped world-state synced to cloud; the decay/corruption scheduler runs on a server clock so absence is honored across devices.
- **Models, networking, local storage, auth, API** are all scaffolded in this repo (see `CrearoCore/Sources/CrearoCore/...` and `CrearoApp/Services/...`).

## 62. Privacy and moderation

This product handles **intimate personal creativity** (writings, voice, photos, "what you were proud of") — privacy is existential, not a checkbox. (Compliance detail in `SETUP_GUIDE.md`/`ROADMAP.md`.)

- **Data minimization & locality:** prefer on-device processing (speech-to-text, segmentation, coherence checks). Store *derived features/embeddings* over raw media where possible; keep large private media in the user's private CloudKit DB when feasible. Encrypt in transit and at rest.
- **The profile is private, always:** the CreativeProfile and scores are never shown raw, never sold as individual data, never used for cross-user comparison beyond *anonymized, opt-in* rarity baselines (§41). Pooled baselines use embeddings + minimal metadata, not identifiable content.
- **Consent & control:** explicit opt-in for any pooling/sharing; full export & delete (GDPR/CCPA); clear, human privacy policy. No selling personal data, no ad-targeting on creative content.
- **Moderation (because users generate content):** all user media passes safety classification (on-device + server) before it can be shared or pooled; the *single-player* world is permissive but still blocks illegal content; **social features (§60) are gated behind robust moderation, reporting, and human review.**
- **Minors:** the audience is adults/college students, but minors will arrive. Plan for **age gating, COPPA/【UK】Age-Appropriate-Design compliance, stricter defaults for younger users, and no social/sharing for under-18 by default.** AI-generated content is labeled and constrained by the balance/safety layers.
- **AI safety:** server-brokered models with strict schemas/allowlists (§33) prevent prompt-injection from turning user "ideas" into unsafe outputs; generated text is template-bounded for canon, free-form only inside the sandboxed creation interpreter with safety filters.

## 63. A realistic first playable 3D MVP

Scope the MVP to *prove the core loop and the hidden engine* with the least 3D content. (Execution plan + milestones in `ROADMAP.md`.)

**MVP includes:**
- The **wooden house** + a **small slice of the Mirrorwood** (one cozy hollow, one corrupted shrine, one ford) — minimal RealityKit content using a modular kit.
- **Character creation** (3 facets: outfit, symbolic object, sigil) feeding the profile.
- The **Creation Forge** with **2–3 input methods** (draw, text, photo) → AI interpretation → 3–5 balanced item archetypes (restyle can start as palette-map + outline, not full generative art).
- **Survival-lite** (warmth + hunger + lantern), the **resource wallet** with ~4 of the 9 resources, **one companion** (text, basic tone adaptation, memory of last creations).
- The **hidden scoring engine v1** (relevance gate + originality via embeddings/DAT + elaboration + flexibility), **prophecy report v1**, and **one personalized mini-boss** (the Hollow Stag mirroring your most-used tactic).
- **Daily creative quest**, basic home growth (light up rooms), basic decay on absence.
- **Auth** (Sign in with Apple), cloud save, the Supabase backend + the two Edge Functions (`interpret-idea`, `score-originality`).

**MVP explicitly excludes:** open world, most regions, full generative restyling, voice/music/gesture inputs, social, most classes (emergence can be stubbed to 2 paths). Target: a vertical slice that is *genuinely fun for 30 minutes* and *measurably nudges creativity over 2 weeks* in playtests. This repo is the seed of that MVP.

## 64. The long-term full version

- **All 6+ regions** with full biomes, survival twists, guardians, and lore (§9).
- **All 8 emergent classes** fully expressed with deep tool-sets and multiclass fluidity (§14).
- **The complete myth arc** and the fully realized **personalized final boss** system (§50–51).
- **All input methods** (drawing, writing, voice, photo, object arrangement, building, music/sound, gesture, mixed-media) and **rich generative restyling** that turns any input into cohesive dark-fantasy 3D content (§52).
- **Full home base** (all rooms/stations/portals/galleries/gardens/memory-walls) and the complete corruption/restoration system (§47–48).
- **Real-world creativity tasks** at scale (§53), **seasonal world events**, **opt-in cozy social** (§60).
- **A validated creativity-training claim** (longitudinal study; the research/EdTech asset) and a **defensible human-creativity dataset** (the rarity corpus, §41) — both moats and potential B2B/licensing avenues (education, art therapy, L&D).

## 65. Major risks and challenges (critical view)

1. **3D content cost.** A semi-open-world 3D game is *expensive and slow* to build — the biggest risk by far. *Mitigation:* ruthless modular/stylized art, tiny-but-deep MVP, RealityKit before Unity, "the Grey shader" to reuse assets, content tooling early.
2. **AI interpretation quality & balance.** Turning arbitrary ideas into *fun, balanced, on-style* objects reliably is hard; bad outputs break immersion and balance. *Mitigation:* strict schemas + allowlists + the BalanceEngine clamp (§34), heavy template scaffolding, human-curated archetype library, fail-soft to "nearest known item."
3. **Scoring validity & fairness.** If the hidden engine mis-scores creativity (or feels biased/cultural), the whole premise wobbles. *Mitigation:* CAT calibration, the relevance gate (§42), trajectory-over-verdict, never-show-scores, ongoing validation studies, bias audits across language/culture.
4. **"Homework" perception.** If it ever feels like a test, the audience bounces (§57). *Mitigation:* game-first design bar, no scores, fiction-only feedback, playtest for *fun* first.
5. **Privacy/trust & moderation.** Intimate UGC + AI = real exposure (legal, PR, safety). *Mitigation:* on-device-first, minimization, encryption, consent, strong moderation, minor protections (§62).
6. **Cost of AI/embeddings at scale.** Per-creation model calls add up. *Mitigation:* on-device pre-checks, caching, cheap embedding models, batch rarity, generous-but-bounded creation economy (the resource limits *also* cap inference cost — a happy alignment).
7. **Retention vs. cozy monetization tension.** The genre resists aggressive monetization (§59). *Mitigation:* premium/subscription on depth & identity, not friction; the Finch playbook.
8. **Scope/solo-dev reality.** This is a studio-sized vision. *Mitigation:* the horizon plan; the MVP is achievable by a small team; this repo de-risks the *systems* half so effort can focus on content/art.

## 66. A stronger, more focused, more marketable version of the concept

The full vision is gorgeous but *enormous*. The sharpest, most fundable cut **keeps the soul, slashes the 3D risk, and nails one unmistakable hook.** Recommended focusing moves:

- **Lead with ONE magic trick in marketing:** *"A cozy dark-fantasy world that grows from your imagination — and quietly makes you more creative."* The shareable wow is **real-world-photo → enchanted-artifact** (§53) and **your-drawing → real-in-game-object** (§52). That's the trailer.
- **Shrink the world, deepen the home.** Make the **home base + a few small handcrafted regions** the whole game at launch (think *Spiritfarer*'s intimacy, not an MMO's breadth). The home you build + the companion who remembers you is the retention engine; you don't need an open world to ship the magic.
- **RealityKit + modular/stylized art, hard cap on 3D scope.** Treat 3D as *cozy diorama scenes*, not a vast walkable continent, for v1. This alone makes it buildable by a small team.
- **Make the daily creative ritual the habit core (the Finch insight).** A beautiful 5-minute daily "make one thing, watch your world respond" loop is the wedge into the huge self-improvement market — with a real game underneath for depth.
- **Position as a *premium cozy creativity RPG*** (Sky/Spiritfarer adjacency) **with a self-care halo** (Finch adjacency) — straddling the cozy-games and self-improvement markets is the unique, defensible niche.
- **Bank the moats:** the **anonymized creativity-rarity dataset** and a **validated "this makes you more creative" claim** are long-term assets no clone can copy quickly — pursue a small longitudinal study early for credibility and PR.
- **One-line investable thesis:** *"Crearo is a daily creativity gym disguised as a cozy dark-fantasy RPG — Finch's habit loop and emotional retention, with the craft and soul of Sky, plus a defensible creativity-assessment engine and dataset."*

> **Recommended next step:** build the MVP in §63 from this repo's scaffolding, run a 2-week creativity-and-fun playtest, and validate the two marketable tricks (photo→artifact, drawing→object) before investing in 3D breadth.

---

*End of Game Design Document. Companions: `CREATIVITY_SCORING.md`, `TECH_ARCHITECTURE.md`, `SETUP_GUIDE.md`, `ROADMAP.md`. Code: `CrearoCore/`, `CrearoApp/`, `supabase/`.*
