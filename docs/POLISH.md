# Finly - Polish and gaps

Things known to be rough or missing. Anything wrong or risky is fixed when
found; cosmetic items are done in batches.

## Visual
- [x] Transfer form: label "Entre contas deste workspace" when it is the only mode
- [x] Transfer form: show the implied exchange rate between currencies (catches typos)
- [x] Transfer form: helper text "informe os dois valores" is cut off
- [x] Poppins and Inter fonts bundled (assets/fonts, with their OFL licenses)
- [x] Tabular figures for money columns (set once in the theme)
- [x] Recorrências: description and account name are truncated in the list tile
- [x] Contas: "Saldo total" excludes credit cards; card debt shown on its own line
- [ ] Selected chips are gold (brand secondary): decide whether to use Tech Blue via a chip theme
- [ ] Check dark and light mode, 200% font scale and TalkBack on every screen
- [ ] Dashboard: charts (spending by category, cash flow over the months)

## Missing in finished features
- [x] Transactions: edit, search and filters (type, status, account, category), pagination (20 per page)
- [ ] Transactions: filter by date range, "move to another account"- [ ] Transfers: undo after delete (needs a database function)
- [ ] Accounts: rename, list and unarchive archived accounts
- [x] Categories: create, rename, recolour, archive and restore (FR-G02)- [x] Credit cards: create, limit bar, invoices, installments, pay invoice
- [ ] Credit cards: edit limit and closing/due days, archive a card, partial payment
- [x] Budgets: monthly limit per category with versions and end markers
- [ ] Budgets: alerts at 80% and 100% (needs notifications, FR-B03)
- [x] Recurring: create, list, pause and resume, pending occurrences
- [ ] Recurring: edit and delete an item, notification before the due date (lead days)
- [x] Dashboard: balance, month, budgets and upcoming items

## Auth and privacy
- [ ] Password reset, change e-mail and password, delete account
- [ ] E-mail confirmation link opens a localhost error (needs a landing page or deep link)
- [ ] Session lock, biometrics, protected switch beyond "confirm" (FR-A07, FR-A08, FR-W04)
- [ ] Terms acceptance version, settings screen
- [ ] Leaked-password protection toggle in Supabase Auth (plan-dependent)

## Technical
- [ ] Data layer: also catch unexpected errors, so a bug shows "Algo deu errado" with a retry button instead of an endless spinner
- [ ] Schedule the database jobs (sql/06_jobs.sql): close invoices and generate recurring occurrences daily
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] Remove the unused DeleteBudgetUseCase (budgets are stopped, not deleted)
- [ ] Move isoDate from the budgets domain to core/utils (recurring and dashboard use it)
- [ ] Rename HomePlaceholderPage to HomePage
- [ ] GitHub Actions: analyze, tests, database tests
- [ ] Widget and golden tests for the main screens
- [ ] Update ARCHITECTURE.md, DATABASE.md and ROADMAP.md (new functions create_credit_card and the budget end marker, new features)

## Done so far (for the record)
- Database: 14 tables, 3 views, RLS everywhere, 67 local checks (sql/00 to sql/09)
- Auth, workspaces and the protected workspace switch (never stuck, with a timeout)
- Accounts, categories (read), transactions, transfers (same workspace and owner)
- Credit cards, budgets, recurring bills, dashboard
- About 510 automated tests