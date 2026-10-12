// Amora answers questions about the person's money. The AI can only ask for
// the totals listed in logic.ts; each runs as the person (RLS applies), and
// only those totals go back to the AI. Nothing is saved; the question is never
// logged.
//
// Secrets: ANTHROPIC_API_KEY (required), AI_MODEL (optional).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { describeRows, readAsk, systemPrompt, toolCall, tools } from "./logic.ts";

const model = Deno.env.get("AI_MODEL") ?? "claude-haiku-5-5";
const maxRounds = 5;

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
  const input = readAsk(body);
  if (typeof input === "string") return reply(400, { error: input });

  const { data: quota, error: quotaError } = await supabase.rpc("ai_take_ask_quota");
  if (quotaError) {
    console.error("ai_take_ask_quota failed:", quotaError.code);
    return reply(500, { error: "server_error" });
  }
  if (quota === "disabled") return reply(403, { error: "ai_ask_disabled" });
  if (quota === "limit") return reply(429, { error: "ai_limit" });

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) {
    console.error("ANTHROPIC_API_KEY is not set");
    return reply(500, { error: "server_error" });
  }

  // deno-lint-ignore no-explicit-any
  // The last questions and answers first, so a follow-up makes sense.
  const messages: any[] = [
    ...input.history.flatMap((turn) => [
      { role: "user", content: turn.question },
      { role: "assistant", content: turn.answer },
    ]),
    { role: "user", content: input.question },
  ];

  for (let round = 0; round < maxRounds; round++) {
    // deno-lint-ignore no-explicit-any
    let data: any;
    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({
          model,
          max_tokens: 1500,
          thinking: { type: "adaptive" },
          output_config: { effort: "low" },
          system: systemPrompt(input.today),
          tools,
          messages,
        }),
        signal: AbortSignal.timeout(25_000),
      });
      if (!response.ok) {
        let reason = "";
        try {
          const error = (await response.json())?.error;
          reason = `${error?.type ?? ""}: ${String(error?.message ?? "").slice(0, 300)}`;
        } catch {
          reason = "(no details)";
        }
        console.error("AI call failed with status", response.status, reason);
        return reply(502, { error: "ai_unavailable" });
      }
      data = await response.json();
    } catch (error) {
      console.error("AI call failed:", error instanceof Error ? error.name : "unknown");
      return reply(502, { error: "ai_unavailable" });
    }

    const content = data.content ?? [];
    // deno-lint-ignore no-explicit-any
    const uses = content.filter((block: any) => block.type === "tool_use");
    if (data.stop_reason !== "tool_use" || uses.length === 0) {
      const answer = content
        // deno-lint-ignore no-explicit-any
        .filter((block: any) => block.type === "text")
        // deno-lint-ignore no-explicit-any
        .map((block: any) => block.text)
        .join("")
        .trim();
      if (!answer) return reply(422, { error: "ai_not_understood" });
      return reply(200, { answer: answer.slice(0, 1200) });
    }

    // The whole answer goes back as it came (thinking blocks included), then
    // the result of each query it asked for.
    messages.push({ role: "assistant", content });
    const results = [];
    for (const use of uses) {
      const call = toolCall(use.name, use.input, input.workspaceId);
      if (typeof call === "string") {
        results.push({ type: "tool_result", tool_use_id: use.id, content: call, is_error: true });
        continue;
      }
      const { data: rows, error } = await supabase.rpc(call.rpc, call.args);
      if (error) {
        console.error("query failed:", call.rpc, error.code);
        results.push({ type: "tool_result", tool_use_id: use.id, content: "não foi possível buscar agora", is_error: true });
        continue;
      }
      results.push({
        type: "tool_result",
        tool_use_id: use.id,
        content: JSON.stringify(describeRows(call.rpc, rows ?? [])),
      });
    }
    messages.push({ role: "user", content: results });
  }

  return reply(422, { error: "ai_not_understood" });
});
