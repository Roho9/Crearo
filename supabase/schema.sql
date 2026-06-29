-- Crearo backend schema (Supabase / Postgres).
-- Implements the originality/rarity engine (pgvector + HNSW), cloud save, the resource ledger,
-- and Row-Level Security. See docs/CREATIVITY_SCORING.md §4 and docs/TECH_ARCHITECTURE.md §5.
--
-- Apply with:  supabase db push     (or paste into the SQL editor)

-- ── Extensions ─────────────────────────────────────────────────────────────
create extension if not exists "vector";     -- pgvector: embeddings + similarity
create extension if not exists "pgcrypto";    -- gen_random_uuid()

-- ── Profiles (1:1 with auth.users) ─────────────────────────────────────────
create table if not exists public.profiles (
    id              uuid primary key references auth.users(id) on delete cascade,
    display_name    text,
    -- The private CreativeProfile snapshot (never exposed to other users). GDD §44.
    creative_profile jsonb not null default '{}'::jsonb,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ── Full world-state blob (offline-first cloud save) ───────────────────────
create table if not exists public.world_state (
    user_id     uuid primary key references auth.users(id) on delete cascade,
    data        jsonb not null,            -- the encoded CrearoCore.WorldState
    updated_at  timestamptz not null default now()
);

-- ── Permanent creations (GDD §36) ──────────────────────────────────────────
create table if not exists public.creations (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    name            text not null,
    type            text not null,
    traditional     jsonb not null default '{}'::jsonb,
    creative        jsonb not null default '{}'::jsonb,
    effect          jsonb not null default '{}'::jsonb,
    art_descriptor  text,
    cost            jsonb not null default '[]'::jsonb,
    region          text,
    decay           jsonb not null default '{}'::jsonb,
    created_at      timestamptz not null default now()
);
create index if not exists creations_user_idx on public.creations(user_id);

-- ── Resource ledger (append-only economy; derive wallet by summing) ────────
create table if not exists public.resource_ledger (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references auth.users(id) on delete cascade,
    resource    text not null,            -- Resource.rawValue
    delta       integer not null,         -- + earn / - spend
    reason      text,
    created_at  timestamptz not null default now()
);
create index if not exists ledger_user_idx on public.resource_ledger(user_id);

-- ── Prompts + responses (the rarity corpus) ───────────────────────────────
create table if not exists public.prompts (
    id                      text primary key,   -- e.g. "daily.2026-06-29", "forge.mirrorwood"
    kind                    text not null,      -- daily | forge | puzzle | character_creation
    text                    text,
    embedding_model_version text not null default 'text-embedding-3-small'
);

-- IMPORTANT: stores ONLY the embedding + minimal metadata for novelty baselines — never raw
-- personal content across users (GDD §62). dim 1536 = OpenAI text-embedding-3-small.
create table if not exists public.prompt_responses (
    id                      uuid primary key default gen_random_uuid(),
    prompt_id               text not null references public.prompts(id) on delete cascade,
    user_id                 uuid references auth.users(id) on delete set null,
    embedding               vector(1536) not null,
    embedding_model_version text not null default 'text-embedding-3-small',
    passed_gate             boolean not null default true,  -- only fitting responses count (§5)
    created_at              timestamptz not null default now()
);

-- HNSW index (the 2026 default; sub-10ms ANN at our scale). Cosine distance operator <=>.
create index if not exists prompt_responses_embedding_idx
    on public.prompt_responses
    using hnsw (embedding vector_cosine_ops);
create index if not exists prompt_responses_prompt_idx on public.prompt_responses(prompt_id);

-- ── Rarity function (statistical-rarity originality; Torrance/DAT) ─────────
-- SECURITY DEFINER so it can read across users for the baseline while RLS blocks direct row reads.
-- Returns mean cosine similarity to the k nearest gate-passing neighbors for the prompt.
create or replace function public.response_rarity(p_prompt text, q vector(1536), k int default 20)
returns table(mean_similarity double precision, sample_count integer)
language sql
stable
security definer
set search_path = public
as $$
    with knn as (
        select 1 - (pr.embedding <=> q) as similarity
        from public.prompt_responses pr
        where pr.prompt_id = p_prompt and pr.passed_gate
        order by pr.embedding <=> q
        limit greatest(k, 1)
    )
    select coalesce(avg(similarity), 0.0)::double precision as mean_similarity,
           count(*)::integer as sample_count
    from knn;
$$;

-- ── Row-Level Security ─────────────────────────────────────────────────────
alter table public.profiles        enable row level security;
alter table public.world_state     enable row level security;
alter table public.creations       enable row level security;
alter table public.resource_ledger enable row level security;
alter table public.prompt_responses enable row level security;

-- Owner-only access to personal data.
create policy "own_profile"     on public.profiles        for all using (auth.uid() = id)      with check (auth.uid() = id);
create policy "own_world_state" on public.world_state     for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_creations"   on public.creations       for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_ledger"      on public.resource_ledger for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- prompt_responses: a user may insert their OWN embedding; nobody may directly SELECT rows
-- (the anonymized baseline is only reachable through response_rarity()). This protects the corpus.
create policy "insert_own_response" on public.prompt_responses
    for insert with check (auth.uid() = user_id);

-- Prompts are public read (so the client can show prompt text), writable by service role only.
alter table public.prompts enable row level security;
create policy "prompts_readable" on public.prompts for select using (true);

-- ── Convenience view: a user's current wallet (summed ledger) ──────────────
create or replace view public.wallet as
    select user_id, resource, sum(delta)::int as amount
    from public.resource_ledger
    group by user_id, resource;
