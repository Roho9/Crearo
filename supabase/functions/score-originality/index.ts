// Supabase Edge Function: score-originality
// Embeds a player's response, computes its population rarity via the response_rarity() RPC
// (pgvector / HNSW k-NN), records the embedding for the growing baseline, and returns a
// novelty percentile. The originality backbone of the hidden engine (CREATIVITY_SCORING.md §4).
//
// Deploy:  supabase functions deploy score-originality
// Secrets: OPENAI_API_KEY  (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are provided automatically)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const EMBED_MODEL = "text-embedding-3-small"; // 1536 dims — MUST match the column + all comparisons

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function embed(text: string): Promise<number[] | null> {
  if (!OPENAI_API_KEY) return null;
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) return null;
  const data = await r.json();
  return data?.data?.[0]?.embedding ?? null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { promptId, text, passedGate = true, userId = null } = await req.json();
    if (!promptId || typeof text !== "string") {
      return Response.json({ error: "promptId and text required" }, { status: 400, headers: cors });
    }

    const vector = await embed(text);
    if (!vector) {
      // Cold start / no key: neutral novelty so scoring degrades gracefully (CREATIVITY_SCORING §4).
      return Response.json({ percentile: 0.5, meanSimilarity: 0, sampleCount: 0, coldStart: true }, { headers: cors });
    }
    const vectorLiteral = `[${vector.join(",")}]`; // pgvector text format

    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    // Ensure the prompt row exists (idempotent), then measure rarity, then record the embedding.
    await supabase.from("prompts").upsert({ id: promptId, kind: promptId.split(".")[0] ?? "misc" }, { onConflict: "id" });

    const { data: rarity, error: rErr } = await supabase
      .rpc("response_rarity", { p_prompt: promptId, q: vectorLiteral, k: 20 })
      .single();
    if (rErr) return Response.json({ error: rErr.message }, { status: 500, headers: cors });

    const meanSimilarity = (rarity?.mean_similarity ?? 0) as number;
    const sampleCount = (rarity?.sample_count ?? 0) as number;
    // Low similarity to neighbors ⇒ rare ⇒ high percentile. Cold start (no neighbors) ⇒ 0.5.
    const percentile = sampleCount === 0 ? 0.5 : Math.max(0, Math.min(1, 1 - meanSimilarity));

    // Record only gate-passing responses, and only the embedding + minimal metadata (privacy, GDD §62).
    if (passedGate) {
      await supabase.from("prompt_responses").insert({
        prompt_id: promptId,
        user_id: userId,
        embedding: vectorLiteral,
        embedding_model_version: EMBED_MODEL,
        passed_gate: true,
      });
    }

    return Response.json({ percentile, meanSimilarity, sampleCount }, { headers: cors });
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 400, headers: cors });
  }
});
