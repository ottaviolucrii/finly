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
- [x] Transactions of an archived category show the real category name (archived ones are hidden only from the new-transaction forms; the filter lists them as "(arquivada)")
- [ ] Charts and report: the income/expense totals are posted only, the category spending includes pending (same rule as budgets); consider unifying
- [ ] Charts are drawn by hand (no chart package); revisit if more chart types are needed
- [ ] Selected chips are gold (brand secondary): decide whether to use Tech Blue via a chip theme
- [ ] Check dark and light mode, 200% font scale and TalkBack on every screen (charts, report, trash and the alerts card included)
- [ ] Home: seven shortcut buttons wrap onto three lines; consider a bottom navigation bar

## Missing in finished features
- [x] Transactions: edit, search and filters (type, status, account, category, period), pagination (20 per page)
- [x] Transactions: trash screen (Lixeira): deleted ones stay 30 days and can be restored; a daily job removes them for good after that
- [x] Transfers: a deleted transfer can be restored from the trash (both legs together, even across the two workspaces)
- [ ] Trash: a deleted card invoice payment is listed but cannot be restored (the invoice has to be paid again)
- [ ] Trash: no "delete now" button (the app cannot hard-delete; the daily job does it after 30 days)
- [ ] Transactions: "move to another account" (delete and recreate in one step)
- [x] Accounts: rename, correct the opening balance, list and restore archived accounts
- [x] Categories: create, rename, recolour, archive and restore (FR-G02)
- [x] Credit cards: create, limit bar, invoices, installments, pay invoice
- [x] Credit cards: edit name, limit and closing/due days; archive a card that owes nothing
- [ ] Credit cards: partial invoice payment
- [ ] Credit cards: updating a card is two writes (name, then settings); make it one database function if it ever shows a half-saved card
- [ ] Credit cards: no alert yet for an invoice due soon or a card near its limit
- [x] Budgets: monthly limit per category with versions and end markers
- [x] Budgets: in-app alert on the dashboard at 80% and over 100% (FR-B03, without push)
- [ ] Budgets: push/local notification at 80% and 100% (needs the notification setup)
- [x] Recurring: create, list, pause and resume, pending occurrences
- [x] Recurring: edit (description, amount, category, end date) and delete (pending occurrences removed, history kept)
- [ ] Recurring: notification before the due date (lead days; the column exists but nothing uses it yet)
- [ ] Recurring: the schedule (frequency, interval, start date) cannot be edited; delete and create another
- [ ] Recurring: clearing an end date does not bring back the occurrences that the end date removed (a gap stays; generated_count already moved past them)
- [x] Dashboard: balance, month, charts, budgets, upcoming items and an "Atenção" card
- [x] Alerts card: budgets at 80% and over the limit, pending bills overdue, due today or in the next 3 days (most urgent first, 5 at a time)
- [ ] Alerts: pending incomes that are late ("a receber") are not reported; the 3-day window and the 80% threshold are fixed (not in the settings)
- [ ] Alerts: a notification centre screen with every alert and a way to dismiss one
- [x] Reports: monthly report with the month before beside it (summary, spending by category, biggest expenses), month arrows, currency chips
- [x] Reports: export the month as CSV through the share sheet (; separator, decimal comma, ISO dates, Windows-1252 text, formula-safe cells)
- [ ] Export: characters outside Windows-1252 (emoji, other alphabets) become "?" in the CSV; an .xlsx export would remove the encoding and locale problems for good
- [ ] Export: amounts use a decimal comma; a spreadsheet set to the US locale reads them as text (set the spreadsheet locale to Brazil)
- [ ] Reports: export as PDF, and a custom period
- [ ] Export: only from the report screen (the transactions list and the filters cannot export), capped at 10,000 transactions per month
- [ ] Export my data (LGPD portability): one file with everything of the user
- [ ] Reports: the biggest expenses list is not tappable (no jump to the transaction)

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
- [x] Database jobs scheduled with pg_cron: invoices close at 00:05 and recurring bills generate at 00:15 (sql/10), the trash is purged at 00:25 (sql/13), all in Sao Paulo time
- [x] The first two jobs ran and succeeded on 2026-10-06 (checked in cron.job_run_details)
- [ ] Check that finly-purge-deleted ran: select * from cron.job_run_details order by start_time desc limit 10
- [x] injection.dart split into one module per feature (features/<name>/di), with a test that builds every bloc and cubit
- [x] View monthly_flow (sql/11) sums income and expenses per month in the database, so charts and reports never download every transaction
- [x] Functions update_recurring and delete_recurring (sql/12), restore_transfer (sql/14), each tested on real data inside a rolled-back transaction
- [x] Database tests cover monthly_flow, update_recurring / delete_recurring, purge_deleted and restore_transfer (90 checks)
- [x] GitHub Actions (.github/workflows/ci.yml): flutter analyze, flutter test and the database tests on every PR and push to develop and main
- [x] ARCHITECTURE.md, DATABASE.md, ROADMAP.md and README.md match the code; docs/SUPABASE_SETUP.md added
- [x] HomePlaceholderPage renamed to HomePage
- [x] share_plus added (the share sheet for exports), behind a FileSharer interface in core/share so tests never touch the platform
- [ ] The database tests cannot run on Windows without a manual fix (the embedded Postgres has no time zone database): use CI, or copy the tzdata files into .venv-db
- [ ] Protect develop and main on GitHub: require a pull request and the two CI checks before merging
- [ ] Pin the Flutter version in CI (flutter-version) after the first green run, so a new stable release cannot break a PR by surprise
- [ ] Security advisor: tables are visible in the GraphQL schema to signed-in users (protected by RLS); consider revoking select where GraphQL is not used
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months and charts
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] Remove the unused DeleteBudgetUseCase (budgets are stopped, not deleted); its test lives in save_and_delete_budget_use_cases_test.dart
- [ ] Move isoDate from the budgets domain to core/utils (budgets and recurring use it; the dashboard has its own copy)
- [ ] Cubit tests should also feed data-layer models (not only base entities), to catch runtime type traps such as firstWhere with orElse
- [ ] Widget and golden tests for the main screens
- [ ] UI_GUIDE.md: record the colours the code really uses for chips and charts once the chip colour is decided

## Done so far (for the record)
- Database: 14 tables, 4 views, RLS everywhere, 90 local checks (sql/00 to sql/14), three daily jobs
- Auth, workspaces and the protected workspace switch (never stuck, with a timeout)
- Settings: change password, sign out everywhere, delete account; forgot password by e-mail code
- Accounts (create, edit, archive, restore), categories (create, edit, archive, restore)
- Transactions (create, edit, search, filters including period, pagination, trash), transfers (same workspace and owner, restorable from the trash)
- Credit cards (create, edit, archive), budgets, recurring bills (create, edit, pause, delete)
- Dashboard with balance, month, charts, budgets, upcoming items and alerts; monthly report with CSV export
- Errors never leave a screen loading; wiring split by feature
- Continuous integration on GitHub; documentation up to date
- About 885 automated tests