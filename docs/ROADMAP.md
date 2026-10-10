# Finly - Roadmap

The whole product is planned; phases only fix the order (each depends on the one before). Requirement IDs refer to `Finly_SRS_v4`. This file tracks what is done; `POLISH.md` tracks rough edges and small gaps of finished features.

**Definition of done for any task:** code + tests green, `flutter analyze` clean, tried on a phone, SRS acceptance line satisfied, docs/SQL updated if behavior changed, merged by pull request into `develop` with CI green.

## Where the project is today

Phases 0 to 4 are done except the items marked open: identity, the session lock and the protected switch, the full ledger with trash and restore, cards, budgets, recurring bills, the dashboard with charts and alerts, the monthly report with CSV export, and local reminders. About 2,190 Dart tests and 137 database checks pass, and CI runs on every pull request. Next in line: the offline cache, push notifications and the notification centre, then Phase 5 (intelligence).

## Phase 0 - Foundation

- [x] Compile errors fixed; models and entities consistent
- [x] Supabase project with `sql/00` to `sql/18` applied; 16 tables with RLS on
- [x] Database tests (`run_db_tests.py`): 162 checks
- [x] Packages added as features needed them (see ARCHITECTURE section 12)
- [x] `core/config` (`--dart-define-from-file=env.json`), `core/di` (one module per feature)
- [x] `core/theme`: `AppColors`, Poppins + Inter bundled, tabular figures
- [x] `core/money/Money` + tests; `core/error` failure set + error mapper + tests
- [x] Validators: e-mail, CPF, CNPJ (alphanumeric included)
- [x] GitHub Actions: analyze, test, database tests; pull request template; Flutter version pinned to the development machine's
- [ ] Repo hygiene to verify: `hs_err_pid*.log` removed and ignored, `.env*` ignored, no leftover `.github/java-upgrade`, `.github/modernize`
- [ ] Protect `develop` and `main` on GitHub (require a pull request and the two CI checks)

## Phase 1 - Identity and workspaces (FR-A, FR-W, FR-S01-S04)

- [x] Sign up (terms), sign in, sign out (this device / all), session restore, e-mail verification
- [x] Change password (re-authentication), delete account (typed confirmation), forgot password (one-time code)
- [x] `AuthRemoteDataSource` + `AuthRepositoryImpl`; every error mapped to a failure
- [x] Workspace use cases (create, switch); active workspace flows through `AuthBloc` and keyed providers
- [x] Onboarding flow (resumable) and second-workspace flow
- [x] Settings: password, sign out everywhere, delete account, app lock, notifications
- [x] Session lock (timeout, background, every start), biometric or PIN unlock with the password as a fallback, five wrong passwords block for five minutes (FR-A07 to FR-A09); content covered in the app switcher (best effort)
- [x] Protected workspace switch: confirm, biometrics or PIN, or password (FR-W04)
- [ ] Change e-mail (needs a confirmation page or a code flow like the password reset)
- [ ] Sign-up confirmation by code (also removes the localhost link problem)
- [x] Settings: appearance (system, light or dark)
- [ ] Settings: language, privacy and terms screen
- [x] Block screenshots (`FLAG_SECURE`) as an option, in Settings
- [ ] Force the password after a new fingerprint is enrolled
- [ ] Force-update check against `app_config`

## Phase 2 - Core ledger (FR-C, FR-G01-02, FR-T01-04, FR-X01-02, FR-U01)

- [x] Accounts: create, edit (name, opening balance), archive, restore, derived balances
- [x] Categories: create, edit, archive, restore
- [x] Transactions: create, edit, confirm pending, soft delete + 10-second undo, search, filters (type, status, account, category, period), pages of 20
- [x] Transfers: internal and owner withdrawal/contribution via RPC; delete via RPC
- [x] Trash (Lixeira): deleted transactions and transfers stay 30 days and can be restored; a daily job removes them for good after that
- [x] Read cache: every read is kept as a copy on the phone and shown when there is no internet, with a banner (the HTTP client keeps the copies; see ADR-28)
- [ ] Offline writing: a queue of changes and rules for conflicts

## Phase 3 - Cards, budgets, recurring (FR-K, FR-B01-02, FR-R, FR-T05-06)

- [x] Credit cards: create, limit usage, invoices, invoice detail, edit, archive
- [x] Installments via RPC; pay invoice via RPC
- [x] Budgets with versions and end markers, progress UI
- [x] Recurring: create, pause/resume, edit, delete; `generate_my_recurring` on open and by a daily job
- [x] Daily jobs with `pg_cron`: close invoices, generate recurring occurrences, purge the trash
- [x] Partial invoice payment: any amount up to what is owed, from the invoice screen; the invoice is settled when nothing is left (`sql/18`)
- [ ] Receipt attach (private bucket)
- [x] Transactions: move an income or an expense to another account of the same workspace and currency; an expense can also go to a card (onto the invoice of its date) and a card purchase can come back to a bank account

## Phase 4 - Overview and alerts (FR-D, FR-N, FR-B03, FR-U02, FR-Y01)

- [x] Dashboard: balance, month, budgets, upcoming
- [x] Charts: income vs expenses (6 months), spending by category
- [x] In-app alerts on the dashboard: budgets at 80% and over the limit, bills overdue or due in 3 days
- [x] Savings goals ("metas"): a goal follows an account, with a target and an optional date, and says what to put aside each month
- [x] Monthly report: summary against the month before, spending by category, biggest expenses
- [x] Local notifications: reminders at 9h for pending bills (the day before, or `lead_days`, and the due day) and card invoices (3 days before and the due day), for the active workspace
- [x] Read cache: every read is kept as a copy on the phone and shown when there is no internet, with a banner (the HTTP client keeps the copies; see ADR-28)
- [ ] Offline writing: a queue of changes and rules for conflicts
- [ ] Notification centre screen; push notifications (FCM token registration, Edge Function jobs) and budget alerts that arrive with the app closed
- [x] Audit log viewer: the history of changes of a workspace, as plain sentences, with a filter by kind of data

## Phase 5 - Intelligence (FR-I, FR-G03)

- [x] Forecast: balance projection for 30, 60 and 90 days from pending bills, recurring items and card invoices, with an explanation card
- [x] Yield simulator: CDB or Tesouro with the regressive income tax, or LCI/LCA exempt, with monthly deposits (the CDI is typed by the person)
- [ ] Yield simulator: fetch the CDI automatically (adapter)
- [x] Tax reserve (Business): a percentage of the month's income set aside, against the taxes of the month
- [ ] Receipt OCR (ML Kit) with review step
- [ ] Smart category suggestion (on-device)

## Phase 6 - Data and currency (FR-E, FR-M, FR-X03, FR-Y02)

- [x] CSV export of a month, from the report screen, through the share sheet
- [x] PDF of the monthly report, from the report screen
- [x] Export of all my data (JSON), from Settings (LGPD data portability)
- [ ] Custom periods
- [ ] OFX import with preview and duplicate detection
- [ ] Multi-currency totals and display conversion (rate adapter)
- [ ] Offline write queue + conflict screen

## Phase 7 - Hardening and release

- [ ] Accessibility audit (TalkBack/VoiceOver, 200 % font, contrast, charts)
- [ ] Security review (RLS re-test, secrets scan, token storage in secure storage), LGPD review (policy text, erasure, portability)
- [ ] Custom SMTP with an owned domain; leaked-password protection (Pro plan)
- [ ] Performance pass (cold start, 100 000-row dataset)
- [ ] Localisation (pt-BR and en)
- [ ] iOS setup (Face ID usage text, notification permission, `AppDelegate`)
- [ ] Store assets, privacy labels, release build, crash reporting

## Workflow

```
git checkout develop && git pull
git checkout -b feature/<name>
# work, commit with Conventional Commits
git push -u origin feature/<name>   # open a PR into develop; CI must be green
```

One feature branch per checklist group, small PRs, tests with the code, `POLISH.md` and the docs updated in the same PR.
