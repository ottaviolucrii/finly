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
- [ ] Transactions of an archived category show "Categoria arquivada" instead of the real name
- [ ] Home: six shortcut buttons wrap onto two lines; consider a bottom navigation bar

## Missing in finished features
- [x] Transactions: edit, search and filters (type, status, account, category), pagination (20 per page)
- [ ] Transactions: filter by date range, "move to another account" (delete and recreate in one step)
- [ ] Transfers: undo after delete (needs a database function)
- [x] Accounts: rename, correct the opening balance, list and restore archived accounts
- [x] Categories: create, rename, recolour, archive and restore (FR-G02)
- [x] Credit cards: create, limit bar, invoices, installments, pay invoice
- [x] Credit cards: edit name, limit and closing/due days; archive a card that owes nothing
- [ ] Credit cards: partial invoice payment
- [ ] Credit cards: updating a card is two writes (name, then settings); make it one database function if it ever shows a half-saved card
- [x] Budgets: monthly limit per category with versions and end markers
- [ ] Budgets: alerts at 80% and 100% (needs notifications, FR-B03)
- [x] Recurring: create, list, pause and resume, pending occurrences
- [ ] Recurring: edit and delete an item, notification before the due date (lead days)
- [x] Dashboard: balance, month, budgets and upcoming items

## Auth and privacy
- [x] Settings screen (profile, security, privacy)
- [x] Change password (asks for the current one, signs the other devices out)
- [x] Sign out of all devices
- [x] Delete account (password and typed confirmation; erases every workspace)
- [ ] Delete account was only covered by tests and the local database check: try it end to end with a throwaway account
- [ ] Change e-mail (needs the confirmation-link page) and forgot-password reset (needs a deep link)
- [ ] E-mail confirmation link opens a localhost error (needs a landing page or deep link)
- [ ] Session lock, biometrics, protected switch beyond "confirm" (FR-A07, FR-A08, FR-W04)
- [ ] Terms acceptance version
- [ ] Leaked-password protection toggle in Supabase Auth (plan-dependent, needs a paid plan)

## Technical
- [x] Data layer catches unexpected errors: a bug shows "Algo deu errado" with a retry, never an endless spinner (details in the console)
- [x] Network errors that reach the app unwrapped say "Sem conexão"
- [x] Database jobs scheduled with pg_cron (sql/10): invoices close at 00:05 and recurring bills generate at 00:15 (Sao Paulo time)
- [ ] Check the jobs worked: select * from cron.job_run_details order by start_time desc limit 10
- [x] injection.dart split into one module per feature (features/<name>/di), with a test that builds every bloc and cubit
- [ ] Security advisor: tables are visible in the GraphQL schema to signed-in users (protected by RLS); consider revoking select where GraphQL is not used
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] Remove the unused DeleteBudgetUseCase (budgets are stopped, not deleted)
- [ ] Move isoDate from the budgets domain to core/utils (recurring and dashboard use it)
- [ ] Rename HomePlaceholderPage to HomePage
- [ ] Cubit tests should also feed data-layer models (not only base entities), to catch runtime type traps such as firstWhere with orElse
- [ ] GitHub Actions: analyze, tests, database tests
- [ ] Widget and golden tests for the main screens
- [ ] Update ARCHITECTURE.md, DATABASE.md and ROADMAP.md (functions create_credit_card and the budget end marker, the cron jobs, the new features)

## Done so far (for the record)
- Database: 14 tables, 3 views, RLS everywhere, 67 local checks (sql/00 to sql/10), two daily jobs
- Auth, workspaces and the protected workspace switch (never stuck, with a timeout)
- Settings: change password, sign out everywhere, delete account
- Accounts (create, edit, archive, restore), categories (create, edit, archive, restore)
- Transactions (create, edit, search, filters, pagination), transfers (same workspace and owner)
- Credit cards (create, edit, archive), budgets, recurring bills, dashboard
- Errors never leave a screen loading; wiring split by feature
- About 650 automated tests