# Crearo

> A cozy dark-fantasy survival RPG where you rebuild a world drained of imagination by *making things* — and the more original, detailed, and brave your creations are, the more the world comes back to life. Underneath the game, a research-grounded engine quietly trains you to think more creatively.

This repository is the **foundation** of the Crearo iOS app: the complete design, a real Swift/SwiftUI codebase implementing the non-3D backbone, and the backend.

## What's real in this repo (and what isn't)

A fully shippable 3D open-world game is a multi-year content effort. What's here is the part a real studio starts from — the systems that are hard and defensible:

| Built & working | Designed, to be built later |
|-----------------|------------------------------|
| The hidden **creativity-scoring engine** (gate → dimensions → trajectory), unit-tested | The full 3D open world, art, animation pipeline |
| The **resource economy**, **balance engine** (idea right-sizing), **rarity** contract | Generative restyling of user art into 3D content |
| **AI-interpretation** contract + offline stub + the `interpret-idea` Edge Function | All 6 regions, 8 classes, full myth arc |
| **Personalized final-boss** composer from the player's weaknesses | Voice/music/gesture inputs, social features |
| SwiftUI **MVP shell**: opening sequence, forge, home, daily quest, prophecy report, RealityKit forest stub | Production auth (Sign in with Apple), CloudKit media sync |
| **Supabase** schema (pgvector + HNSW + RLS) + two Edge Functions | The longitudinal creativity-validation study |

The design is exhaustive in [`docs/`](docs); the code is a runnable seed of the MVP described in `docs/ROADMAP.md`.

## Repository layout

```
Crearo/
├── docs/                     ← the full design & research
│   ├── GAME_DESIGN_DOCUMENT.md   (all 66 sections)
│   ├── CREATIVITY_SCORING.md     (the research + math, with citations)
│   ├── TECH_ARCHITECTURE.md      (MVVM, RealityKit, backend choice)
│   ├── SETUP_GUIDE.md            (Apple account, Xcode, Git, backends)
│   └── ROADMAP.md                (MVP → full version, risks, monetization)
├── CrearoCore/               ← Swift Package: pure, testable game logic (Foundation-only)
│   ├── Sources/CrearoCore/{Models,Engines,Services}
│   └── Tests/CrearoCoreTests
├── CrearoApp/                ← SwiftUI app (MVVM features + RealityKit + DI)
├── supabase/                 ← schema.sql (pgvector) + Edge Functions
├── project.yml               ← XcodeGen spec → Crearo.xcodeproj
└── .gitignore
```

## Quick start

```bash
# 1. Run the pure game-logic tests — no Xcode/simulator needed (fast TDD loop)
cd CrearoCore && swift test

# 2. Generate & open the iOS app
brew install xcodegen
cd .. && xcodegen generate && open Crearo.xcodeproj
#   → select your Team + a unique bundle id, then Run. The app works fully OFFLINE
#     (deterministic AI stub + local JSON save); no backend required to try the loop.

# 3. (Optional) wire the backend
#   See docs/SETUP_GUIDE.md §5 — apply supabase/schema.sql, deploy the two Edge Functions,
#   copy CrearoApp/Resources/Config.example.xcconfig → Config.xcconfig, set USE_REMOTE_AI=YES.
```

## The core loop (try this)
Open the app → light the fire and name your companion (opening sequence) → **Forge** → type *"a sword that shoots honey to slow enemies"* → it becomes **Honeyfang**, balanced and named, in your world → check **Path** to see your *Sky of Makings* brighten and glimpse the personalized shadow forming from your weaknesses.

## Design pillars (one line each)
- **Game first, training invisible.** No scores shown — ever. The world's color *is* the feedback.
- **Creativity = novelty × usefulness.** A relevance gate means random nonsense never scores (defends the known DAT failure mode).
- **Failure transforms the world; it never ends the game.**
- **The final boss is *you*** — assembled from your weakest creative patterns; you win by growing past them.

See [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md) for everything.

---
*Status: foundational build v0.1. Built as a real startup seed, not a prototype to throw away.*
