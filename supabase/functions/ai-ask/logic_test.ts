import assert from "node:assert/strict";
import { describeRows, money, readAsk, systemPrompt, toolCall } from "./logic.ts";

const ws = "3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90";

Deno.test("reads a good question", () => {
  const read = readAsk({ question: "  quanto  gastei com uber? ", workspaceId: ws, today: "2026-10-12" });
  assert.deepStrictEqual(read, { question: "quanto gastei com uber?", workspaceId: ws, today: "2026-10-12" });
});

Deno.test("refuses bad questions, with the reason", () => {
  assert.strictEqual(readAsk({ question: "", workspaceId: ws, today: "2026-10-12" }), "empty_text");
  assert.strictEqual(readAsk({ question: "x".repeat(301), workspaceId: ws, today: "2026-10-12" }), "text_too_long");
  assert.strictEqual(readAsk({ question: "oi", workspaceId: "nope", today: "2026-10-12" }), "invalid_workspace");
  assert.strictEqual(readAsk({ question: "oi", workspaceId: ws, today: "12/10/2026" }), "invalid_today");
});

Deno.test("a tool call becomes a query on the app's workspace, never one the AI names", () => {
  const call = toolCall("gastos_com_palavra", { de: "2026-01-01", ate: "2026-10-12", palavra: "uber", p_workspace: "other" }, ws);
  assert.deepStrictEqual(call, {
    rpc: "ai_spending_matching",
    args: { p_workspace: ws, p_from: "2026-01-01", p_to: "2026-10-12", p_text: "uber" },
  });
});

Deno.test("bad tool input is refused with a reason the AI can fix", () => {
  assert.strictEqual(toolCall("entradas_e_saidas", { de: "ontem", ate: "2026-10-12" }, ws), "datas inválidas: use AAAA-MM-DD");
  assert.strictEqual(toolCall("entradas_e_saidas", { de: "2026-10-12", ate: "2026-01-01" }, ws), "a data inicial vem depois da final");
  assert.strictEqual(toolCall("gastos_com_palavra", { de: "2026-01-01", ate: "2026-10-12", palavra: "u" }, ws), "a palavra precisa ter de 2 a 60 letras");
  assert.strictEqual(toolCall("apagar_tudo", {}, ws), "ferramenta desconhecida");
});

Deno.test("money is written like in Brazil", () => {
  assert.strictEqual(money(81240, "BRL"), "R$ 812,40");
  assert.strictEqual(money(123456789, "BRL"), "R$ 1.234.567,89");
  assert.strictEqual(money(-5000, "BRL"), "-R$ 50,00");
  assert.strictEqual(money(1999, "USD"), "US$ 19,99");
});

Deno.test("rows become short facts with formatted money", () => {
  assert.deepStrictEqual(describeRows("ai_spending_matching", [{ currency: "BRL", total_cents: 81240, transactions: 31 }]), [
    { total: "R$ 812,40", lancamentos: 31 },
  ]);
  assert.deepStrictEqual(describeRows("ai_spending_matching", []), { total: "R$ 0,00", lancamentos: 0 });
  assert.deepStrictEqual(describeRows("ai_income_expense", [{ currency: "BRL", income_cents: 500000, expense_cents: 320000 }]), [
    { entrou: "R$ 5.000,00", saiu: "R$ 3.200,00", sobrou: "R$ 1.800,00" },
  ]);
});

Deno.test("the instructions know today and forbid inventing numbers", () => {
  const prompt = systemPrompt("2026-10-12");
  assert.ok(prompt.includes("Hoje é 2026-10-12"));
  assert.ok(prompt.includes("nunca invente"));
});
