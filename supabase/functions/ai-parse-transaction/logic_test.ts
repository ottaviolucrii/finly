import assert from "node:assert/strict";
import { buildPrompt, type Input, readAnswer, readInput } from "./logic.ts";

const input: Input = {
  text: "gastei 50 no mercado ontem no nubank",
  today: "2026-10-11",
  categories: [
    { id: "cat-mercado", name: "Mercado", kind: "expense" },
    { id: "cat-salario", name: "Salário", kind: "income" },
  ],
  accounts: [
    { id: "acc-itau", name: "Itaú", card: false },
    { id: "acc-nubank", name: "Nubank", card: true },
  ],
};

Deno.test("reads a good body", () => {
  const read = readInput({ ...input, accounts: [{ id: "a", name: "  Itaú   Empresa ", card: false }] });
  if (typeof read === "string") throw new Error(read);
  assert.deepStrictEqual(read.accounts[0].name, "Itaú Empresa");
});

Deno.test("refuses bad bodies, with the reason", () => {
  assert.deepStrictEqual(readInput(null), "invalid_body");
  assert.deepStrictEqual(readInput({ ...input, text: "   " }), "empty_text");
  assert.deepStrictEqual(readInput({ ...input, text: "x".repeat(301) }), "text_too_long");
  assert.deepStrictEqual(readInput({ ...input, today: "11/10/2026" }), "invalid_today");
  assert.deepStrictEqual(readInput({ ...input, accounts: [] }), "no_accounts");
  assert.deepStrictEqual(readInput({ ...input, categories: [{ id: "x", name: "A", kind: "other" }] }), "invalid_category");
});

Deno.test("the prompt uses short labels, never the ids", () => {
  const prompt = buildPrompt(input);
  assert.deepStrictEqual(prompt.user.includes("c1 | despesa | Mercado"), true);
  assert.deepStrictEqual(prompt.user.includes("a2 | cartão de crédito | Nubank"), true);
  assert.deepStrictEqual(prompt.user.includes("cat-mercado"), false);
  assert.deepStrictEqual(prompt.system.includes("hoje é 2026-10-11"), true);
});

Deno.test("a good answer becomes a draft with the real ids", () => {
  const draft = readAnswer(
    '{"type":"expense","amount":50,"description":"Mercado","category":"c1","account":"a2","date":"2026-10-10","pending":false}',
    input,
  );
  assert.deepStrictEqual(draft, {
    type: "expense",
    amountCents: 5000,
    description: "Mercado",
    categoryId: "cat-mercado",
    accountId: "acc-nubank",
    date: "2026-10-10",
    pending: false,
  });
});

Deno.test("text around the JSON is ignored", () => {
  const draft = readAnswer('Aqui está:\n{"type":"expense","amount":12.9,"description":"Café"}\nPronto.', input);
  assert.strictEqual(draft?.amountCents, 1290);
});

Deno.test("a comma decimal in text still becomes cents", () => {
  assert.strictEqual(readAnswer('{"type":"expense","amount":"12,50","description":"Café"}', input)?.amountCents, 1250);
});

Deno.test("an income never lands on a card", () => {
  const draft = readAnswer('{"type":"income","amount":3000,"description":"Salário","category":"c2","account":"a2"}', input);
  assert.strictEqual(draft?.accountId, null);
  assert.strictEqual(draft?.categoryId, "cat-salario");
});

Deno.test("a category of the other kind is dropped", () => {
  assert.strictEqual(readAnswer('{"type":"income","amount":10,"description":"Pix","category":"c1"}', input)?.categoryId, null);
});

Deno.test("labels outside the lists are dropped", () => {
  const draft = readAnswer('{"type":"expense","amount":10,"description":"X","category":"c9","account":"b1"}', input);
  assert.strictEqual(draft?.categoryId, null);
  assert.strictEqual(draft?.accountId, null);
});

Deno.test("a far or broken date becomes today; a future one is pending", () => {
  assert.strictEqual(readAnswer('{"amount":10,"description":"X","date":"2019-01-01"}', input)?.date, "2026-10-11");
  assert.strictEqual(readAnswer('{"amount":10,"description":"X","date":"ontem"}', input)?.date, "2026-10-11");
  const future = readAnswer('{"amount":10,"description":"Aluguel","date":"2026-10-15"}', input);
  assert.strictEqual(future?.pending, true);
});

Deno.test("no amount is allowed (the person types it); no amount and no text is not", () => {
  assert.strictEqual(readAnswer('{"type":"expense","amount":null,"description":"Uber"}', input)?.amountCents, null);
  assert.strictEqual(readAnswer('{"type":"expense","amount":null,"description":""}', input), null);
  assert.strictEqual(readAnswer("não entendi", input), null);
});

Deno.test("silly amounts are dropped", () => {
  assert.strictEqual(readAnswer('{"amount":-5,"description":"X"}', input)?.amountCents, null);
  assert.strictEqual(readAnswer('{"amount":1e20,"description":"X"}', input)?.amountCents, null);
});
