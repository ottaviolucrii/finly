// AI quick add: turns a sentence ("gastei 50 no mercado ontem no nubank")
// into a draft transaction. The app shows the draft in the "+" sheet and the
// person saves it; nothing is saved here.
//
// Secrets (Supabase → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY  the key of the Claude API (required)
//   AI_MODEL           optional, defaults to claude-haiku-5-5
// The sentence is never logged.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildPrompt, readAnswer, readInput } from "./logic.ts";

const model = Deno.env.get("AI_MODEL") ?? "claude-haiku-5-5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return reply(401, { error: "not_authenticated" });

  // Acting as the person: the database rules (RLS) apply to everything below.
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: auth, error: authError } = await supabase.auth.getUser();
  if (authError || !auth?.user) return reply(401, { error: "not_authenticated" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "invalid_body" });
  }
  const input = readInput(body);
  if (typeof input === "string") return reply(400, { error: input });

  // Consent and today's limit, checked and counted in the database.
  const { data: quota, error: quotaError } = await supabase.rpc("ai_take_quota");
  if (quotaError) {
    console.error("ai_take_quota failed:", quotaError.code);
    return reply(500, { error: "server_error" });
  }
  if (quota === "disabled") return reply(403, { error: "ai_disabled" });
  if (quota === "limit") return reply(429, { error: "ai_limit" });

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) {
    console.error("ANTHROPIC_API_KEY is not set");
    return reply(500, { error: "server_error" });
  }

  const prompt = buildPrompt(input);
  let answer = "";
  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: 1024,
        // Little thinking: filling in a few fields does not need more, and
        // it keeps the answer fast and cheap. (No temperature: not allowed.)
        thinking: { type: "adaptive" },
        output_config: { effort: "low" },
        system: prompt.system,
        messages: [{ role: "user", content: prompt.user }],
      }),
      signal: AbortSignal.timeout(20_000),
    });
    if (!response.ok) {
      console.error("AI call failed with status", response.status);
      return reply(502, { error: "ai_unavailable" });
    }
    const data = await response.json();
    // The answer may start with thinking blocks: only the text counts.
    answer = (data.content ?? [])
      .filter((block: { type: string }) => block.type === "text")
      .map((block: { text: string }) => block.text)
      .join("");
  } catch (error) {
    console.error("AI call failed:", error instanceof Error ? error.name : "unknown");
    return reply(502, { error: "ai_unavailable" });
  }

  const draft = readAnswer(answer, input);
  if (!draft) return reply(422, { error: "ai_not_understood" });
  return reply(200, { draft });
});
