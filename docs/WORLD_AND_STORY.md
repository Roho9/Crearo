# Crearo — World & Story (playable-first design)

> Dark-fantasy creativity adventure. The *scale and quest rhythm* of a big open RPG, the *tragic, fated, cursed* weight of grimdark — but every name, place, and event here is original. Keep it simple: the lore is a thin, evocative skin over the real game (making things restores a dying world). Players should feel it, not read it.

## The one-line premise
The world is going grey because people forgot how to make new things. You are one of the last who still can. Every original, heartfelt making you forge pushes back the grey — but the more you create, the closer you come to the one thing the grey is saving for you: a god built from everything you were too afraid to make.

---

## The mythology (the whole bible — keep it this short)

- **The world / continent:** **Ysmera** — a land that was *woven*, not built.
- **The world-tree / loom:** **the Ashen Loom** — a colossal tree-loom at the world's heart that once wove every making into being. It now hangs grey and bare.
- **The sun:** **the Last Ember** (dimming). **The moon:** **the Grey Eye** (the cold light demons love).
- **The creation myth — "the Kindling":** In the beginning there was only **the Sameness**, a grey that ate every shape. **Aevu, the First Hand**, reached into it and *imagined* — and the first colors, the first beasts, the first songs spilled out and caught like fire. To make was to be holy.
- **The first demon — Grust, the Pale Mimic:** the first making that was *afraid to change*. It could only copy, never invent, and it hungered for the originality it could never have. All demons are its brood: the grey given teeth. They eat new ideas.
- **The first king — Sael the Unchanging:** the first mortal to *hoard* making. He decreed that only the crown could shape new things, "to keep the world safe." Invention slowed. The Loom dimmed. His heirs, **the Unchanged**, still rule and still enforce sameness — feeding the very grey they fear.
- **The first sacrifice — the Faceless Gift:** a maker named **Liss** poured her *entire self* into one perfect making to relight a dying village. It worked — and she went blank, faceless, grey. Her kind, **the Faceless**, still wander Ysmera: small, mournful, hopeful. (Your companion is one of them.)
- **The ancient war — the Hollow War:** Makers against the Sameness. It was never won, only slowed. We live in its long, losing aftermath: **the Greying**. The prophesied end is **the Last Sameness**, when the final color goes out.

**The prophecy (the game's spine):**
> *When the Loom hangs grey and bare,*
> *the last Maker forges what they fear —*
> *and meets, at the end of every road,*
> *the shape of all they would not make.*

That last line is the whole tragedy: **the final boss is you** — the Hollow You, a towering cracked-clay colossus wearing the blank faces of every idea you refused to attempt, leaking grey. You don't beat it with strength. You beat it by having *grown past* the creative weaknesses it's built from. (This is literally your existing "personalized shadow from the player's weaknesses" engine.)

---

## Story ↔ mechanics (every system is the story)

| Mechanic you already have | What it *means* in-world |
|---|---|
| Creativity score (gate → dimensions) | How much grey a making pushes back. The relevance gate = the Pale Mimic's curse: copies and nonsense don't fool the world, so they restore nothing. |
| World desaturation / decay ("corruption") | The Greying creeping into your home when you stop making. |
| The Forge | Relighting: turning a raw idea into a real, colored making the Loom remembers. |
| CreaCash (currency) | **Kindle** — caught sparks of the Last Ember. The spendable fuel of making. |
| Emergent classes (from how you create) | Which kind of maker you're *becoming* (see Hands, below). Never chosen — revealed. |
| Companion brightness | Your Faceless companion slowly **warming and forming a face** as you make. Their face returning is your real progress bar — wordless. |
| Personalized final boss | **The Hollow You.** Fated, tragic, unavoidable — and winnable only by growth. |

**The Hands (classes, reskinned, emergent — never picked):** the Wildhand (originality), the Weaver (elaboration/detail), the Wright (usefulness), the Mourner (emotion), the Seer (symbol), the Leaper (risk). You become one by *how* you make, and the world starts calling you by it.

---

## Factions & look (dark fantasy, hand-made clay)

- **The Kindlers** (demon hunters): hunt the Greyed and the Mimics. Charred ash-leather, cracked kiln-clay half-masks, and a hip-lantern holding one *trapped color*. Grim, devout, tired.
- **The Wildhands** (rebels): reject the Unchanged's law that only the crown may make. Dressed in **patchwork they made themselves** — mismatched bright scraps in a grey land. Individuality as defiance.
- **The Unchanged** (Sael's heirs / antagonist order): smooth grey ceremonial clay, identical masks, beautiful and dead. They believe sameness is mercy.
- **Final boss — the Hollow You:** a cracked grey clay giant, hollow inside, hung with the blank faces of your unmade ideas — your companion's lost face somewhere among them.

**Art direction:** everything is visibly **hand-sculpted clay** (matches the toy-3D reference and our procedural blob). Rule: *only what was made has color.* Grey = unmade. This is feasible now (primitive clay meshes), and gives the artist a clear north star later (sculpted USDZ).

---

## World & quest structure (big-RPG rhythm, kept simple)

- **One explorable world**, not menus. A hub grove (your relit home) opens onto **6 regions**, each a "movement" of the Greying, unlocked by making (your existing RegionGates).
- **A quest is tiny and repeatable:** a Faceless or villager asks you to *make* something (a short fiction prompt) → you forge/answer → a small story beat lands → **color returns to that place.** Scale comes from *many* of these, not from complexity.
- **Main line:** restore the 6 regions → reach the Ashen Loom → the prophecy closes → the Hollow You.
- **Side makings:** your existing daily quests, reframed as NPC requests ("the kiln-keeper's lantern went grey — make her a new light").
- **No score is ever shown.** Progress = the world regaining color and your companion regaining a face.

---

## UI / world design direction

1. **Color *is* the HUD.** Start heavily desaturated; global saturation/warmth rises with your creative profile. No bars, no numbers — the saturation is the feedback (your core pillar).
2. **Diegetic panels, not tabs.** Forge already rises over the world. Quests, the prophecy ("Path"), and your gallery should be **objects/NPCs you approach** in the world, opening as opaque panels — never a tab bar.
3. **Companion as progress.** The Faceless one follows you; its growing warmth/face is the emotional throughline. Tapping it = a quiet line of fiction.
4. **Story in fragments.** Prophecy lines and companion remarks, a sentence at a time. Never a wall of text. Immersive, not read.
5. **Tone.** Quiet, cursed, tender. Warm pools of light in a grey world. Failure transforms the world; it never ends the game.

---

## Suggested build order (small, shippable steps)
1. **Reskin the strings** the player already sees with this lore (companion lines, prophecy, region/resource names, opening narration). Cheap, high-impact — the game *feels* like this immediately.
2. **Color-as-progress:** drive global world saturation from companion brightness / profile, so making visibly relights the world.
3. **Companion in the world:** a second smaller Faceless that follows and brightens; tap for a line.
4. **Quest-giver:** one approachable NPC in the world that opens a "making request" panel (reuse the daily-quest engine).
5. Later: the Ashen Loom hub, region travel, and the Hollow You encounter.
