# ROADMAP.md — Crearo execution plan

*The realistic build path behind GDD §63–66. Honest about cost, sequencing, and the 3D risk.*

---

## The core sequencing principle

Build the **risky, defensible systems first** (the hidden creativity engine, the AI-interpretation→balance pipeline, the home/companion attachment loop) on the **smallest possible 3D footprint**, validate *fun* and *creativity-gain* in playtests, and only then invest in 3D breadth. The systems are this team's moat; the open world is the expensive part. This repo is the seed of Phase 1.

---

## Phase 0 — Foundations (this repo) · ~done here

- [x] Full design spec (GDD, scoring, architecture).
- [x] `CrearoCore`: models + scoring engine + balance engine + economy + service protocols + tests.
- [x] SwiftUI app skeleton (MVVM features, DI, design system, RealityKit stub).
- [x] Supabase schema (pgvector) + the two Edge Functions.
- [x] Setup/CI/secrets guides.
- **Exit criterion:** `xcodegen generate` opens a building project; `swift test` green; the §8 smoke test passes against a Supabase dev project.

## Phase 1 — Playable MVP / vertical slice · ~4–7 months, 3–5 people

Team: 1 gameplay/Swift eng, 1 backend/ML eng, 1 technical artist (RealityKit + modular kit), 1 designer/writer, part-time audio. (A scrappy 2-person version is possible but slower.)

Scope (GDD §63): wooden house + a small Mirrorwood slice; character creation (3 facets); Creation Forge with draw/text/photo → balanced items; survival-lite (warmth/hunger/lantern); 4 of 9 resources; one companion with tone + memory; scoring engine v1 (gate + originality + elaboration + flexibility); prophecy v1; one personalized mini-boss (Hollow Stag); daily creative quest; basic home growth + absence decay; Sign in with Apple + cloud save.

Milestones:
- **M1 (mo 1–2):** core loop greybox — move, gather, forge a creation, see the world react. Engine wired end-to-end (even with a stub LLM).
- **M2 (mo 2–4):** restyle v1 (palette-map/outline), home growth, companion memory, daily quest, decay. Art kit v1 for the house + one glade.
- **M3 (mo 4–6):** the Hollow Stag personalized mini-boss, prophecy reports, polish, onboarding.
- **M4 (mo 6–7):** closed playtest (50–200 testers, 2-week diaries) measuring **(a) retention & fun** and **(b) a creativity pre/post** (simple DAT/alt-uses) for early signal.
- **Exit criterion:** "fun for 30 minutes" qualitative bar cleared **and** a positive creativity-trend signal in playtest. This de-risks everything downstream.

## Phase 2 — Early Access / wider beta · ~6–12 months after MVP

- Regions 2–3 (Hush Mire, Greymarch) + their guardians; classes fully emergent (8 paths); home base depth (rooms/stations/gallery/garden); corruption/restoration full system; real-world photo tasks at scale; more input methods (voice, object arrangement, building); restyle v2 (generative, on-style); the first true **personalized final boss** for an Act-1–3 arc.
- Backend hardening: rarity corpus scaling, cost controls, moderation pipeline, RLS audit.
- **TestFlight Early Access**, gentle monetization live (below). Begin a small **longitudinal creativity study** for credibility.

## Phase 3 — Full launch & beyond · 12 months+

- All 6+ regions, the complete myth arc + full personalized final-boss system, all input methods + rich restyling, seasonal world events, **opt-in cozy social** (visit/gift, moderated), the validated "makes you more creative" claim, and the creativity-dataset/B2B avenues (education, art therapy, L&D).

---

## Monetization (aligned to a cozy/self-care audience)

The cozy genre **punishes aggressive monetization** (market signal: ~27% lower ARPU but far higher retention/goodwill) and the whole design depends on psychological safety, so: **no pay-to-win, no competitive pressure, no punishing energy gates.**

- **Model:** premium up-front **or** free with a **gentle subscription** ("Patron of the Hearth"): extra daily creative prompts, more restyle variations, cosmetic home/companion sets, cloud history depth. Mirror **Finch's** web-first, altruistically-framed subscription (it reached ~10M DAU / $100M+ on a cozy self-care loop — proof the audience pays for *depth and identity*, not friction).
- **Never monetize:** creativity scores, the profile, the personal boss, or any comparative/competitive element.
- **Cost alignment:** the in-game creation economy caps creation frequency, which *also* caps AI inference spend — design and unit-economics pull the same direction.

---

## Privacy & moderation execution (GDD §62)

- **Data minimization:** on-device STT/segmentation/coherence checks; store embeddings/derived features over raw media; private media in CloudKit per-user containers.
- **Consent & control:** explicit opt-in for any pooling/social; full export & delete (GDPR/CCPA); plain-language privacy policy; no selling personal data, no ad-targeting on creative content.
- **Moderation:** safety classification (on-device + server) before any content can be shared/pooled; reporting + human review gating *all* social features; the single-player sandbox is permissive but blocks illegal content.
- **Minors:** age-gating, COPPA / UK Age-Appropriate-Design compliance, stricter defaults, **no social/sharing for under-18 by default**, labeled & constrained AI output.

---

## Top risks → mitigations (condensed from GDD §65)

| Risk | Mitigation |
|------|-----------|
| 3D content cost/time (the big one) | tiny-but-deep MVP; RealityKit before Unity; modular/stylized art; "the Grey" reuse-shader; cap 3D scope to dioramas at launch |
| AI interpretation quality/balance | strict schema + allowlist + BalanceEngine clamp; curated archetype library; fail-soft to nearest known item |
| Scoring validity/fairness/bias | CAT calibration; relevance gate; trajectory-not-verdict; never shown; bias audits; validation study |
| "Homework" perception | game-first bar ("fun with no hidden system?"); no scores; fiction-only feedback |
| Privacy/trust/moderation | on-device-first; minimization; encryption; consent; strong moderation; minor protections |
| AI cost at scale | on-device pre-filter; caching; cheap embeddings; economy caps frequency |
| Cozy monetization tension | depth/identity subscription (Finch playbook), not friction |
| Studio-sized scope vs. small team | horizon plan; this repo de-risks the systems half so effort focuses on content/art |

---

## The marketable cut (GDD §66) — recommended for fundraising/launch

- **One hook in marketing:** *"A cozy dark-fantasy world that grows from your imagination — and quietly makes you more creative."* Trailer = **photo→enchanted artifact** and **drawing→real in-game object**.
- **Shrink the world, deepen the home:** ship the **home base + a few intimate handcrafted scenes** (Spiritfarer-intimate, not MMO-broad). The home you build + the companion who remembers you *is* the retention engine.
- **Daily 5-minute creative ritual** as the habit wedge into the self-improvement market, with a real RPG underneath for depth.
- **Position:** premium cozy creativity RPG (Sky/Spiritfarer adjacency) with a self-care halo (Finch adjacency) — a unique, defensible straddle.
- **Bank the moats:** the anonymized creativity-rarity dataset + a validated creativity-gain claim — neither is quickly cloneable.
- **Investable thesis:** *"Finch's habit loop and emotional retention, with the craft and soul of Sky, plus a defensible creativity-assessment engine and dataset."*

## Unity decision gate

Stay on **RealityKit** while the world is stylized dioramas on Apple-only. Re-evaluate **Unity (as a Library)** only if: (a) 3D/animation needs clearly exceed RealityKit, **or** (b) cross-platform (Android) becomes a funded priority. Because the 3D layer is isolated (TECH §4) and logic lives in `CrearoCore`, this swap never touches game systems or the backend.
