# Crearo backend (Supabase)

Postgres + Auth + Storage + Edge Functions, with **pgvector** powering the originality/rarity engine.
Full rationale: `../docs/TECH_ARCHITECTURE.md §5`. Scoring math: `../docs/CREATIVITY_SCORING.md §4`.

## Contents
- `schema.sql` — tables (`profiles`, `world_state`, `creations`, `resource_ledger`, `prompts`, `prompt_responses`), the **HNSW** vector index, the `response_rarity()` function, and Row-Level Security.
- `functions/interpret-idea/` — turns a player idea into a balanced, named, art-styled object (GDD §33).
- `functions/score-originality/` — embeds a response, computes population rarity, records the embedding.

## Setup
```bash
# 1. Link a project (or run locally)
supabase init           # first time
supabase start          # local stack, OR link a cloud project:
supabase link --project-ref <your-ref>

# 2. Apply the schema
supabase db push        # or paste schema.sql into the SQL editor

# 3. Deploy functions
supabase functions deploy interpret-idea
supabase functions deploy score-originality

# 4. Secrets (NEVER in the app)
supabase secrets set OPENAI_API_KEY=sk-...
# SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected into functions automatically.

# 5. Auth: enable the Apple provider in the dashboard (Sign in with Apple), per SETUP_GUIDE §5.
```

## Notes
- **Same embedding model everywhere.** `score-originality` uses `text-embedding-3-small` (1536-dim) to match the `vector(1536)` column. Changing models requires re-embedding (versioned via `embedding_model_version`).
- **Privacy:** `prompt_responses` stores only embeddings + minimal metadata; direct row reads are blocked by RLS, and the cross-user baseline is reachable only through the `SECURITY DEFINER` `response_rarity()` function (GDD §62).
- **No keys configured?** Both functions degrade gracefully (deterministic fallback / neutral 0.5 novelty) so the app runs end-to-end in development.
