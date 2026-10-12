# AI quick add

The person writes a sentence ("gastei 50 no mercado ontem no nubank") and the
"+" sheet is filled in for them to check. Nothing is saved without their tap.

## How it works

1. The app sends the sentence, the person's "today", and the names of their
   categories and accounts to the Edge Function `ai-parse-transaction`.
2. The function checks the person is signed in, and calls `ai_take_quota()`:
   the AI must be turned on (consent, `ai_settings`) and today's limit
   (`ai_daily_limit()`, 60 uses) not reached.
3. The function calls Claude (Haiku 5.5, low effort) with short labels
   (c1, a1) instead of ids, and checks every field of the answer
   (`logic.ts`): labels must exist, an income never goes to a card, dates far
   from today become today, doubtful fields stay empty.
4. The app shows the draft in the "+" sheet.

## Privacy

- Sent to the AI: the sentence, category names and account names. Never
  balances, history, or ids.
- The sentence is never logged by the function.
- The API key is a Supabase secret (`ANTHROPIC_API_KEY`), never in the app.
- The person turns the AI on and off in Configurações.

## Costs

- About US$ 0.13 per 1,000 sentences with Haiku 5.5 (Oct 2026 prices).
- Limits: 60 uses per person per day (database), plus the monthly spending
  limit set in the Claude console.

## Deploy

    supabase login
    supabase init            # only once, if supabase/config.toml is missing
    supabase link --project-ref <project ref>
    supabase functions deploy ai-parse-transaction

Optional secret `AI_MODEL` changes the model without new code.

## Tests

- Database: `python sql/tests/run_db_tests.py` (AI consent, limit, isolation).
- Function logic: `deno test supabase/functions/ai-parse-transaction/logic_test.ts`.

# Questions about money ("Perguntar sobre meu dinheiro")

The person asks Amora ("quanto gastei com Uber esse ano?") and she answers
from the totals of their Finly.

1. The app sends the question, the workspace and "today" to the Edge Function
   `ai-ask`. Questions have their own consent (`ai_settings.ask_enabled`) and
   share the daily limit with the quick add (`ai_take_ask_quota()`).
2. Claude receives the question and four tools (`logic.ts`): spending per
   category, spending whose description has a word, money in and out, and
   account balances. It can ask for nothing else.
3. Each tool runs as the person (`security invoker`, RLS applies) through the
   functions of `sql/20_ai_ask.sql`. The workspace always comes from the app,
   never from the AI. Periods are checked (in order, at most 3 years).
4. Only the totals go back to Claude, with money already formatted, so it
   never does the math. Expenses include pending ones (card purchases).
5. The answer (at most 3 short sentences) goes back to the app. Nothing is
   saved; the question is never logged.

Deploy: run `sql/20_ai_ask.sql`, then `supabase functions deploy ai-ask`.
Tests: `python sql/tests/run_db_tests.py`; `deno test supabase/functions/ai-ask/logic_test.ts`.
