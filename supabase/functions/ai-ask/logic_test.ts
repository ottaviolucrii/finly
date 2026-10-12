import assert from "node:assert/strict";
import { describeRows, money, readAsk, systemPrompt, toolCall } from "./logic.ts";

const ws = "3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90";

Deno.test("reads a good question", () => {
  const read = readAsk({ question: "  quanto  gastei com uber? ", workspaceId: ws, today: "2026-10-12" });
  assert.deepStrictEqual(read, { question: "quanto gastei com uber?", workspaceId: ws, today: "2026-10-12", history: [] });
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

Deno.test("keeps the last 3 questions and answers, for follow-ups", () => {
  const history = [1, 2, 3, 4].map((i) => ({ question: `p${i}`, answer: `r${i}` }));
  const read = readAsk({ question: "e no mês passado?", workspaceId: ws, today: "2026-10-12", history });
  if (typeof read === "string") throw new Error(read);
  assert.deepStrictEqual(read.history.map((t) => t.question), ["p2", "p3", "p4"]);
});

Deno.test("broken history items are dropped", () => {
  const read = readAsk({ question: "oi", workspaceId: ws, today: "2026-10-12", history: [{ question: "x" }, "y", null] });
  if (typeof read === "string") throw new Error(read);
  assert.deepStrictEqual(read.history, []);
});

Deno.test("the new tools become their queries", () => {
  assert.deepStrictEqual(toolCall("orcamentos_do_mes", { mes: "2026-10" }, ws), {
    rpc: "ai_budget_status",
    args: { p_workspace: ws, p_month: "2026-10-01" },
  });
  assert.strictEqual(toolCall("orcamentos_do_mes", { mes: "outubro" }, ws), "mês inválido: use AAAA-MM");
  assert.deepStrictEqual(toolCall("faturas_a_pagar", {}, ws), { rpc: "ai_invoices_to_pay", args: { p_workspace: ws } });
  assert.deepStrictEqual(toolCall("metas", {}, ws), { rpc: "ai_goals", args: { p_workspace: ws } });
});

Deno.test("budgets, invoices and goals become short facts", () => {
  assert.deepStrictEqual(
    describeRows("ai_budget_status", [{ category: "Lazer", currency: "BRL", limit_cents: 40000, spent_cents: 41200, left_cents: -1200 }]),
    [{ categoria: "Lazer", limite: "R$ 400,00", gasto: "R$ 412,00", falta: "nada", passou: "R$ 12,00" }],
  );
  assert.strictEqual(describeRows("ai_invoices_to_pay", []), "nenhuma fatura a pagar");
  assert.deepStrictEqual(
    describeRows("ai_goals", [{ goal: "Reserva", target_cents: 1000000, saved_cents: 250000, target_date: null, currency: "BRL" }]),
    [{ meta: "Reserva", objetivo: "R$ 10.000,00", guardado: "R$ 2.500,00", falta: "R$ 7.500,00", percentual: "25%", data: "sem data" }],
  );
});

Deno.test("the instructions say she does not list transactions, and where to see them", () => {
  const prompt = systemPrompt("2026-10-12");
  assert.ok(prompt.includes("Você não vê os lançamentos um a um"));
  assert.ok(prompt.includes("Extrato, escolha o mês e use a busca"));
  assert.ok(prompt.includes("Não invente o motivo"));
});
