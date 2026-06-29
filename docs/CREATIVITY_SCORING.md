# CREATIVITY_SCORING.md — The Hidden Creativity Engine

*The research, math, and safeguards behind §39–45 of the GDD. The runnable contract lives in `CrearoCore/Sources/CrearoCore/Engines/CreativityScoringEngine.swift`, `RarityService.swift`, and `BalanceEngine.swift`.*

> **Design oath:** the player never sees a number. Every output of this engine is expressed only as world state — color, light, loot, dialogue, badges, prophecy. The math is invisible; the *feeling* is the product.

---

## 1. What "creativity" means here (the two-factor definition)

Across the research literature, a creative product is consistently defined by **two** properties at once: it is **novel** *and* **useful/appropriate** to its context. Pure novelty is not creativity (random noise is novel); pure usefulness is not creativity (a textbook answer is useful). Crearo scores **novelty × appropriateness**, and structurally refuses to reward novelty that fails the appropriateness gate (§5). This is the entire reason the engine cannot be fooled by nonsense.

This maps to **Guilford's** classic distinction:
- **Divergent thinking** — generating many, varied, original ideas → measured by *Fluency, Flexibility, Originality* across a player's responses.
- **Convergent thinking** — selecting/forming a single working solution that fits constraints → measured by the *Usefulness / constraint-satisfaction gate*.

Crearo deliberately trains **both**, because shipping a creative act requires the divergent *leap* and the convergent *landing*. Most "creativity apps" only reward divergence; Crearo's survival/balance/usefulness systems force the landing too.

---

## 2. The eight scored dimensions (and their research basis)

| Dimension | Definition (as scored) | Research basis | Primary in-game signal |
|-----------|------------------------|----------------|------------------------|
| **Originality** | statistical rarity of the response vs. the population on the *same* prompt, plus semantic distance from the obvious | Torrance "originality = statistical rarity"; Divergent Association Task (semantic distance via embeddings), Olson et al. 2021 | re-saturates the world; earns Musefire/Hollow Sparks; counters Conformity enemies |
| **Fluency** | number of distinct, relevant ideas/solutions generated (for a prompt or over a session) | Torrance "fluency = number of relevant ideas" | resource yield; idea-rich players unlock more options |
| **Flexibility** | number of distinct *categories* of solution used (across a problem or the player's history) | Torrance "flexibility = number of categories"; cognitive flexibility | opens regions; beats one-trick Shadows; "three different ways" |
| **Elaboration** | amount of *meaningful* detail/development in a response | Torrance "elaboration = amount of detail" | durability/finish of creations; richness of home |
| **Usefulness / fit** | does it satisfy the constraint and function in the world (the gate) | Convergent thinking; two-factor creativity (novelty×usefulness) | whether a creation *works*; pass/fail of the relevance gate |
| **Risk-taking** | boldness / distance from the safe default / acceptance of instability | resistance to premature closure (TTCT-figural); risk in creative cognition | high-Instability gear; beats risk-averse bosses; earns Willpower |
| **Emotional expression** | genuine affective charge / personal vulnerability in a response | affective creativity; CAT expert ratings of expressiveness | magic vs. Fear/Shadow; the Lull; earns Essence |
| **Symbolic / metaphorical thinking** | use of metaphor, symbol, reframing, abstraction | metaphor & problem-reframing as markers of high creativity | symbolism puzzles; Mythweaver; door/metaphor locks |

Two **context flags** modulate all of the above:
- **Reframing detected** — did the player redefine the problem rather than solve the stated one? (A top creativity marker; mirrors TTCT-figural's *resistance to premature closure*.)
- **Constraint satisfied under scarcity** — did they create successfully with *less*? (Creativity-under-constraint; a robust finding that limits can *boost* creativity.)

---

## 3. The scoring pipeline (three stages)

```
 Player response (text / drawing / photo / voice→text / arrangement / build)
        │
        ▼
 ┌──────────────────────────────────────────────────────────────────┐
 │ STAGE 1 — RELEVANCE / USEFULNESS GATE  → g ∈ [0,1]                │
 │  • semantic relatedness to the prompt ≥ floor                    │
 │  • functional sim-check where applicable (bridge holds? weapon   │
 │    stops the Tidy? recipe feeds?)                                 │
 │  • media coherence (drawing has structure; text is on-topic;     │
 │    voice transcribes to relevant content)                        │
 │  If g ≈ 0 → minimal reward, no originality credit. (Anti-nonsense)│
 └──────────────────────────────────────────────────────────────────┘
        │ g
        ▼
 ┌──────────────────────────────────────────────────────────────────┐
 │ STAGE 2 — DIMENSIONAL SCORING  → each dᵢ ∈ [0,1]                  │
 │  Originality (rarity+semantic distance), Fluency, Flexibility,    │
 │  Elaboration, Usefulness, Risk, Emotional, Symbolic + flags       │
 │  All novelty-type dims are multiplied by g (gate-gated).          │
 └──────────────────────────────────────────────────────────────────┘
        │ {dᵢ}
        ▼
 ┌──────────────────────────────────────────────────────────────────┐
 │ STAGE 3 — TRAJECTORY UPDATE → CreativeProfile                    │
 │  recency-weighted, effort-weighted, uncertainty-aware EWMA per    │
 │  dimension; robust to one-off flukes; tracks deltas/trends.       │
 └──────────────────────────────────────────────────────────────────┘
        │
        ▼  consumed by: reward multiplier · creation creative-stats ·
           badges/class/region/companion/boss triggers (never shown raw)
```

**Per-act reward multiplier** (drives resources & loot quality):
`reward = base × g × (w·{dᵢ})` where `w` weights dimensions by the *current quest's* focus (a flexibility daily weights Flexibility; the forge weights Originality+Usefulness). Capped to keep the economy bounded.

**Creation creative-stats** (the §24 block) are a direct, lightly-mapped function of `{dᵢ}`: `Originality→Originality stat`, `Risk→Instability`, `Emotional→Emotional Charge`, etc., then clamped by the `BalanceEngine` to the player's level/region budget (§4 below, GDD §34).

---

## 4. Originality as rarity — the population baseline (pgvector)

Torrance defines originality as **statistical rarity**, which requires a *population baseline per prompt*. Implementation (Supabase Postgres + `pgvector`):

1. **Embed** every response: text via a sentence-embedding model; images via an image-embedding model; voice via transcript→text-embedding. Store the vector in `prompt_responses` keyed by `prompt_id` + `embedding_model_version` (see `supabase/schema.sql`).
2. **Rarity** = inverse local density. For a new response `q` to prompt `p`, find its k nearest neighbors among *gate-passing* responses to `p` via an **HNSW** index; rarity rises as mean cosine similarity to neighbors falls (sparse neighborhood = rare = original). Convert to a **percentile** ("more novel than 88% of fitting responses to this prompt").
3. **HNSW** is the 2026 default index for pgvector and keeps nearest-neighbor queries sub-10ms at the scales we expect; **the same embedding model must be used for all comparisons** (mixing models yields meaningless distances — enforced by versioning).
4. **Cold-start** (prompt has few responses): blend (a) **DAT-style semantic distance** from the prompt's obvious/expected answers, and (b) an **LLM-judge originality estimate calibrated to CAT** (§6); fold in population-rarity as data accrues. Graceful degradation, no cliff.

> The accumulating, prompt-anchored corpus of human responses + novelty distributions is itself a **moat and research asset** (GDD §41, §64). It is stored as embeddings + minimal anonymized metadata, never identifiable cross-user content (GDD §62).

SQL sketch (full in `schema.sql`):
```sql
-- nearest-neighbor rarity for a response embedding :q to prompt :p
select 1 - avg(1 - (pr.embedding <=> :q)) as mean_similarity      -- <=> = cosine distance
from prompt_responses pr
where pr.prompt_id = :p and pr.passed_gate
order by pr.embedding <=> :q
limit 20;  -- k-NN; lower mean_similarity ⇒ higher rarity ⇒ higher originality
```

---

## 5. Anti-nonsense: why randomness can't win

The DAT literature is explicit that pure novelty/semantic-distance metrics can be **gamed by randomness** — stochastic or meaningless outputs can score as highly "divergent" while lacking any appropriateness (Olson et al., 2021). Crearo neutralizes this:

1. **Gate before credit (§3):** originality is only credited *after* the response clears the semantic-relatedness floor **and** the functional/coherence checks. Novelty without fit → `g≈0` → ~0 reward.
2. **Rarity among *fitting* responses:** the population baseline (§4) is computed only over gate-passing responses, so "rare" means "rare among things that work," not "rare among all keystrokes."
3. **Coherence checks per modality:** drawings need structure/intent (image stats + aptness model, not scribble-noise); text must be coherent and on-topic; voice must transcribe to relevant content.
4. **Elaboration ≠ length:** meaningful detail is rewarded; repetition, padding, and copy-paste are detected and discounted.
5. **Trajectory robustness (§7):** one lucky/gamed input can't move standing; the profile updates on *trends*.

Result: the player is rewarded only for being **novel *and* apt** — the two-factor definition (§1). This is the engine's scientific backbone, not a patch.

---

## 6. Calibration to human judgment (CAT)

The **Consensual Assessment Technique** (Amabile, 1982) — expert raters independently judging creativity, averaged — is widely regarded as the **gold standard** for product creativity, with strong inter-rater reliability and construct validity. We can't put human judges in the real-time loop, so we **calibrate the automated engine to CAT**:

- Assemble a **calibration corpus** of real player responses per prompt type (drawings, weapon ideas, dialogue, etc.).
- Have a small panel of domain-appropriate raters (and/or an **LLM-judge ensemble validated against those human ratings**) produce CAT-style creativity scores without training, per Amabile's protocol.
- **Fit/validate** the engine's dimensional outputs against the CAT scores; adjust weights, gates, and the LLM-judge prompt until automated scores **track human consensus** within target reliability.
- Re-validate periodically and across **languages/cultures** to audit bias (§8). CAT is our ground truth; the live engine is the fast, scalable proxy.

---

## 7. The CreativeProfile (trajectory over verdict)

Each user has a private profile (model: `CreativeProfile`): for each dimension, a recency- and effort-weighted estimate with an uncertainty band, plus trend (Δ), plus meta-signals: modality preferences, problem-type tendencies, repetition patterns, idea speed, constraint-handling, combat-reliance, channel-avoidance (emotional/visual/symbolic/narrative), practicality, multi-solution ability, "do ideas strengthen over time," and consistency of return.

Update rule (per dimension `i`, per gate-passing act):
`profileᵢ ← (1−α)·profileᵢ + α·effort·g·dᵢ`, with `α` small (e.g., 0.1–0.2) so the profile is **stable and hard to swing**, and `effort` discounting trivial inputs. Trends use a longer-window comparison so growth (the whole point) is detectable and celebrated.

**Principles:** trajectory over verdict (we score *change*, never a fixed label); blind spots become *gentle pressure* (resource shortage → companion longing → region demand → boss); the profile is the brain that personalizes classes, region order, companion tone, NPC memory, reward tuning, daily-quest selection, decay targeting, and the final boss.

---

## 8. Fairness, bias, and validity

- **Cultural/linguistic bias:** embedding models and LLM judges carry biases; "originality vs. population" can disadvantage minority styles. *Mitigations:* per-locale baselines, multilingual embeddings, CAT panels spanning cultures, regular bias audits, and never penalizing — only *rewarding* — so a mis-score costs a player upside, never progress (there's always a viable path; GDD §46).
- **Construct validity:** the TTCT has known validity debates; we treat each metric as a *useful proxy*, triangulate (rarity + semantic distance + CAT + behavioral signals), and validate against outcomes in playtests (does the engine's "growth" correlate with independent creativity gains?).
- **No high-stakes use:** scores never gate essential progress, are never shown, and are never used to judge the person — purely to *tune a game and personalize growth*. This dramatically lowers the harm of any individual mis-score.
- **Validation study (Horizon 2/3):** a longitudinal study testing whether sustained play improves independent creativity measures — both a marketing/credibility asset (GDD §64) and an ethics safeguard.

---

## 9. Boss composition from the profile (`BossComposer`)

At endgame, `BossComposer` reads the `CreativeProfile` and:
1. selects the **2–3 lowest / most-stagnant / most-avoided** dimensions → these become the boss's **phases** (each immune to the player's crutches, yielding only to a neglected dimension);
2. identifies the **single most-overused tactic/creation type** → the boss **mirrors and counters** it (the ultimate Shadow);
3. pulls **named creations and patterns** from history for the boss's personalized dialogue;
4. ensures Act 5's run-up **pre-trains** those exact dimensions (and the prophecy reports foreshadow them) so the finale is a winnable culmination, not a gotcha.

Mapping table of weakness → boss is in GDD §51. The win condition is always: *demonstrate the missing creativity, live.*

---

## 10. References

Creativity science:
- [Torrance Tests of Creative Thinking — Wikipedia](https://en.wikipedia.org/wiki/Torrance_Tests_of_Creative_Thinking) and the [TTCT Interpretive Manual (STS)](https://www.ststesting.com/gift/TTCT_InterpMOD.2018.pdf) — the four dimensions: fluency, flexibility, originality (statistical rarity), elaboration; figural adds resistance to premature closure.
- [Torrance Tests — Scoring, Validity & Batteries (Cogn-IQ)](https://www.cogn-iq.org/learn/theory/torrance-tests/) and [construct-validity critique (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S1871187108000072).
- [Divergent Association Task — Wikipedia](https://en.wikipedia.org/wiki/Divergent_Association_Task) (Olson et al., 2021): originality as average semantic distance between words via computational word-meaning models — and the explicit caveat that random/stochastic outputs can score highly without meaning.
- [Tracking divergent thinking via semantic distance (ResearchGate)](https://www.researchgate.net/publication/309220682_Tracking_the_dynamics_of_divergent_thinking_via_semantic_distance_Analytic_methods_and_theoretical_implications) — semantic-distance methods for divergent thinking.
- [Amabile's Consensual Assessment Technique (overview, ScienceDirect)](https://www.sciencedirect.com/topics/psychology/consensual-assessment-technique) and [CAT reliability over time, Barth 2021 (Wiley)](https://onlinelibrary.wiley.com/doi/full/10.1002/jocb.462) — CAT as the gold standard; expert consensus, no rater training, domain familiarity.
- Guilford's divergent vs. convergent thinking (foundational; see TTCT/DAT references above for lineage).

Technology:
- [pgvector: Embeddings and vector similarity (Supabase Docs)](https://supabase.com/docs/guides/database/extensions/pgvector) and [Semantic search (Supabase Docs)](https://supabase.com/docs/guides/ai/semantic-search) — storing embeddings, ANN search, same-model requirement.
- [Supabase Vector & pgvector best setup 2026 (Kreante)](https://www.kreante.co/post/build-smart-apps-with-supabase-vector-database-semantic-search-guide) — HNSW as the 2026 default; sub-10ms p99 at ~5M vectors on Pro.
