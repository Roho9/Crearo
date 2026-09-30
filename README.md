# Crearo

Crearo is an iOS creativity puzzle game. Players invent solutions to unusual situations, receive a visible creativity score out of 100, and advance through levels. The intended experience combines a light, expressive world with satisfying progress and opportunities to compare ideas and scores with friends.

The current app calls its world **Prism**. It is an early playable foundation; the richer world, character art, and social features are still being developed.

## Current player experience

1. Complete the opening and name a companion.
2. Read the current level's situation and goal, then type an invention or solution.
3. Receive a score breakdown, feedback, and a short procedural pixel cut-scene.
4. Reach the level's required score to advance. Failed answers can be refined and retried.
5. View the accumulated story and personal progress. The current version permits one successful level per day.

There are twelve authored challenges. After those, the challenge bank cycles while the pass mark continues to rise. Progress is saved locally as JSON.

## Development direction and known gaps

The [direction brief](docs/CREARO_DIRECTION.md) documents the implementation audit and proposes twelve new challenges across three regions. The expansion is a proposal, not implemented content.

The next work needs to address these concrete gaps:

- **Scoring and progression:** the default offline scoring path caps at 62/100, below Level 5's required 64. Its vocabulary and length heuristics cannot evaluate whether an answer solves the actual challenge.
- **Consistent outcomes:** displayed AI grades and the offline evaluation used for rewards and world growth currently follow separate paths.
- **World and art:** cut-scenes reuse simple shapes for inventions and obstacles. The repository does not yet contain production character or environment assets.
- **Social comparison:** there is no leaderboard or shared, server-verified challenge score system yet.

The existing design documents also describe an earlier dark-fantasy survival RPG with hidden creativity scores. Those documents contain useful systems and research, but they do not describe the current app's complete player flow. The direction brief records the current goal of visible scores, level progression, and a light visual identity.

## Run locally

Requirements: Xcode with an iOS SDK, XcodeGen, and a simulator or device supporting iOS 17 or later.

Run the platform-independent game-logic tests:

```bash
cd CrearoCore
swift test
```

From the repository root, create the local configuration and generate the Xcode project:

```bash
cp CrearoApp/Secrets.swift.example CrearoApp/Secrets.swift
xcodegen generate
open Crearo.xcodeproj
```

Leave `anthropicAPIKey` empty to use the offline fallback, subject to the scoring limitation above. To try AI challenge grading and scene direction locally, set your Anthropic key in the gitignored `Secrets.swift`. This direct API configuration is for local testing; a released app needs server-side model credentials and authoritative scoring.

In Xcode, select the `CrearoApp` scheme, choose a simulator or device, and run. For a physical device, configure your signing team and bundle identifier.

## Repository layout

| Path | Purpose |
| --- | --- |
| `CrearoApp/` | SwiftUI app, daily level flow, cut-scenes, local persistence, and AI integration |
| `CrearoCore/` | Foundation-only Swift package for models, scoring, economy, and progression, with unit tests |
| `docs/CREARO_DIRECTION.md` | Current audit, recommended next steps, and proposed world expansion |
| `docs/` | Earlier game design, story, scoring research, architecture, roadmap, and setup guides |
| `supabase/` | Backend schema and Edge Functions for the earlier forge and originality systems |
| `project.yml` | XcodeGen project specification |

Forge, home-base, and other earlier RPG systems remain in the codebase, but the current root view opens the daily level experience. Supabase setup is optional for those earlier systems; the visible challenge judge currently uses the separate local-testing AI path described above.
