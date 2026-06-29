// Supabase Edge Function: interpret-idea
// Turns a player's free idea into a balanced, art-styled, named in-world object (GDD §33).
// All model keys stay server-side. Output is validated + coarsely clamped here (defense in depth);
// the client BalanceEngine re-clamps precisely for the player's level/region.
//
// Deploy:  supabase functions deploy interpret-idea
// Secret:  supabase secrets set OPENAI_API_KEY=sk-...

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const MODEL = Deno.env.get("INTERPRET_MODEL") ?? "gpt-4o-mini";

const EFFECT_KINDS = ["slow","burn","fear","charm","confuse","shield","light","heal","stealth","summon","reframe","none"];
const ITEM_TYPES = ["weapon","armor","spell","structure","relic","ritual","decoration","tool","trap","consumable","companionForm"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const clamp = (x: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, isFinite(x) ? x : lo));

function systemPrompt(): string {
  return [
    "You are the Forge of Crearo, a cozy dark-fantasy survival game.",
    "Turn the player's idea into ONE balanced in-world object. Preserve the player's creative ESSENCE",
    "but fit it to a medieval dark-fantasy world. NEVER refuse an idea — right-size it instead.",
    "Return STRICT JSON only, matching this schema:",
    `{"itemType": one of ${JSON.stringify(ITEM_TYPES)},`,
    ` "traditional": {"damage":0-200,"defense":0-200,"speed":0-100,"durability":0-100,"resistance":0-100,"weight":0-50,"cooldown":0-30},`,
    ` "effect": {"kind": one of ${JSON.stringify(EFFECT_KINDS)}, "magnitude":0.0-0.8, "durationSec":0-10, "cooldownSec":0-30, "range":0-12},`,
    ` "artDescriptor": short cozy dark-fantasy visual description,`,
    ` "suggestedName": an evocative name (the player may rename it)}`,
    "Balance: early-game players (low level) get modest numbers. Strong/unusual ideas keep their identity",
    "but get cooldowns/short range/instability rather than raw power. Map the idea to the closest effect kind.",
  ].join(" ");
}

function coerce(obj: any): any {
  const itemType = ITEM_TYPES.includes(obj?.itemType) ? obj.itemType : "tool";
  const t = obj?.traditional ?? {};
  const e = obj?.effect ?? {};
  const kind = EFFECT_KINDS.includes(e?.kind) ? e.kind : "none";
  return {
    itemType,
    traditional: {
      damage: clamp(+t.damage || 0, 0, 200),
      defense: clamp(+t.defense || 0, 0, 200),
      speed: clamp(+t.speed || 10, 0, 100),
      durability: clamp(+t.durability || 20, 0, 100),
      resistance: clamp(+t.resistance || 0, 0, 100),
      weight: clamp(+t.weight || 2, 0, 50),
      cooldown: clamp(+t.cooldown || 0, 0, 30),
    },
    effect: {
      kind,
      magnitude: clamp(+e.magnitude || 0, 0, 0.8),
      durationSec: clamp(+e.durationSec || 0, 0, 10),
      cooldownSec: clamp(+e.cooldownSec || 0, 0, 30),
      range: clamp(+e.range || 0, 0, 12),
    },
    artDescriptor: String(obj?.artDescriptor ?? "a hand-made dark-fantasy thing").slice(0, 240),
    suggestedName: String(obj?.suggestedName ?? "Nameless Making").slice(0, 60),
  };
}

function offlineFallback(text: string) {
  const t = (text || "").toLowerCase();
  let effect = { kind: "none", magnitude: 0, durationSec: 0, cooldownSec: 0, range: 0 };
  let itemType = "tool";
  if (t.includes("honey") || t.includes("slow")) { effect = { kind: "slow", magnitude: 0.3, durationSec: 3, cooldownSec: 4, range: 0 }; itemType = "weapon"; }
  else if (t.includes("shield") || t.includes("protect")) { effect = { kind: "shield", magnitude: 0.4, durationSec: 5, cooldownSec: 6, range: 0 }; itemType = "armor"; }
  const name = (text || "Nameless Making").split(" ").slice(0, 3).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
  return coerce({ itemType, traditional: { damage: itemType === "weapon" ? 22 : 6, defense: itemType === "armor" ? 18 : 2 }, effect, artDescriptor: "a hand-made dark-fantasy thing", suggestedName: name });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { idea } = await req.json();
    const text: string = idea?.text ?? "";

    if (!OPENAI_API_KEY) {
      // No key configured → deterministic fallback so the function still works in dev.
      return Response.json(offlineFallback(text), { headers: cors });
    }

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.8,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt() },
          { role: "user", content: `Player idea: "${text}". Return the JSON object.` },
        ],
      }),
    });

    if (!resp.ok) return Response.json(offlineFallback(text), { headers: cors });
    const data = await resp.json();
    const raw = data?.choices?.[0]?.message?.content ?? "{}";
    let parsed: any;
    try { parsed = JSON.parse(raw); } catch { return Response.json(offlineFallback(text), { headers: cors }); }
    return Response.json(coerce(parsed), { headers: cors });
  } catch (err) {
    return Response.json({ error: String(err) }, { status: 400, headers: cors });
  }
});
