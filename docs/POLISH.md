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
- [x] Dashboard charts: income vs expenses for 6 months (bars) and spending by category (donut)
- [ ] Charts: bars show only what already happened, the donut includes pending (same rule as budgets); consider unifying
- [ ] Charts are drawn by hand (no chart package); revisit if more chart types are needed
- [ ] Selected chips are gold (brand secondary): decide whether to use Tech Blue via a chip theme
- [ ] Check dark and light mode, 200% font scale and TalkBack on every screen (charts included)
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
- [x] Recurring: edit (description, amount, category, end date) and delete (pending occurrences removed, history kept)
- [ ] Recurring: notification before the due date (lead days; the column exists but nothing uses it yet)
- [ ] Recurring: the schedule (frequency, interval, start date) cannot be edited; delete and create another
- [ ] Recurring: clearing an end date does not bring back the occurrences that the end date removed (a gap stays; generated_count already moved past them)
- [x] Dashboard: balance, month, charts, budgets and upcoming items

## Auth and privacy
- [x] Settings screen (profile, security, privacy)
- [x] Change password (asks for the current one, signs the other devices out)
- [x] Sign out of all devices
- [x] Delete account (password and typed confirmation; erases every workspace)
- [ ] Delete account was only covered by tests and the local database check: try it end to end with a throwaway account
- [x] Forgot password: a one-time code by e-mail (no deep link), then a new password; signs the other devices out
- [x] Supabase dashboard settings written down in docs/SUPABASE_SETUP.md (the Reset Password template must show {{ .Token }})
- [ ] Set Minimum password length to 8 and the letters-and-digits requirement in Supabase, so the server matches the app
- [ ] Set up custom SMTP in Supabase (needs an owned domain): the built-in sender allows only 2 e-mails per hour for the whole project
- [ ] Change e-mail (needs the confirmation-link page or a code flow like the password reset)
- [ ] Sign-up confirmation could use a code too, which also fixes the localhost error on the link
- [ ] Session lock, biometrics, protected switch beyond "confirm" (FR-A07, FR-A08, FR-W04)
- [ ] Move the session from supabase_flutter's default storage to secure storage
- [ ] Terms acceptance version
- [ ] Leaked-password protection toggle in Supabase Auth (plan-dependent, needs a paid plan)

## Technical
- [x] Data layer catches unexpected errors: a bug shows "Algo deu errado" with a retry, never an endless spinner (details in the console)
- [x] Network errors that reach the app unwrapped say "Sem conexão"
- [x] Database jobs scheduled with pg_cron (sql/10): invoices close at 00:05 and recurring bills generate at 00:15 (Sao Paulo time)
- [ ] Check the jobs worked: select * from cron.job_run_details order by start_time desc limit 10
- [x] injection.dart split into one module per feature (features/<name>/di), with a test that builds every bloc and cubit
- [x] View monthly_flow (sql/11) sums income and expenses per month in the database, so charts never download every transaction
- [x] Functions update_recurring and delete_recurring (sql/12), tested on real data inside a rolled-back transaction
- [x] Database tests cover monthly_flow and update_recurring / delete_recurring (83 checks)
- [x] GitHub Actions (.github/workflows/ci.yml): flutter analyze, flutter test and the database tests on every PR and push to develop and main
- [x] ARCHITECTURE.md, DATABASE.md, ROADMAP.md and README.md match the code; docs/SUPABASE_SETUP.md added
- [ ] Protect develop and main on GitHub: require a pull request and the two CI checks before merging
- [ ] Pin the Flutter version in CI (flutter-version) after the first green run, so a new stable release cannot break a PR by surprise
- [ ] Security advisor: tables are visible in the GraphQL schema to signed-in users (protected by RLS); consider revoking select where GraphQL is not used
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months and charts
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] Remove the unused DeleteBudgetUseCase (budgets are stopped, not deleted)
- [ ] Move isoDate from the budgets domain to core/utils (recurring and dashboard use it)
- [ ] Rename HomePlaceholderPage to HomePage
- [ ] Cubit tests should also feed data-layer models (not only base entities), to catch runtime type traps such as firstWhere with orElse
- [ ] Widget and golden tests for the main screens
- [ ] UI_GUIDE.md: record the colours the code really uses for chips and charts once the chip colour is decided

## Done so far (for the record)
- Database: 14 tables, 4 views, RLS everywhere, 83 local checks (sql/00 to sql/12), two daily jobs
- Auth, workspaces and the protected workspace switch (never stuck, with a timeout)
- Settings: change password, sign out everywhere, delete account; forgot password by e-mail code
- Accounts (create, edit, archive, restore), categories (create, edit, archive, restore)
- Transactions (create, edit, search, filters, pagination), transfers (same workspace and owner)
- Credit cards (create, edit, archive), budgets, recurring bills (create, edit, pause, delete)
- Dashboard with balance, month, charts, budgets and upcoming items
- Errors never leave a screen loading; wiring split by feature
- Continuous integration on GitHub; documentation up to date
- About 740 automated tests