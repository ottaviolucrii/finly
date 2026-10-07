# Finly - Roadmap

The whole product is planned; phases only fix the order (each depends on the one before). Requirement IDs refer to `Finly_SRS_v4`. This file tracks what is done; `POLISH.md` tracks rough edges and small gaps of finished features.

**Definition of done for any task:** code + tests green, `flutter analyze` clean, tried on a phone, SRS acceptance line satisfied, docs/SQL updated if behavior changed, merged by pull request into `develop` with CI green.

## Where the project is today

Phases 0, 2 and 3 are done (except the items marked open), Phase 1 is mostly done, Phase 4 has the dashboard and charts. About 740 Dart tests and 90 database checks pass, CI runs on every pull request. Next in line: reports, notifications, the session lock, then Phase 5.

## Phase 0 - Foundation

- [x] Compile errors fixed; models and entities consistent
- [x] Supabase project with `sql/00` to `sql/12` applied; 14 tables with RLS on
- [x] Database tests (`run_db_tests.py`): 90 checks
- [x] Packages: `supabase_flutter`, `flutter_bloc`, `get_it`, `mocktail`, `bloc_test` (others are added when a feature needs them)
- [x] `core/config` (`--dart-define-from-file=env.json`), `core/di` (one module per feature)
- [x] `core/theme`: `AppColors`, Poppins + Inter bundled, tabular figures
- [x] `core/money/Money` + tests; `core/error` failure set + error mapper + tests
- [x] Validators: e-mail, CPF, CNPJ (alphanumeric included)
- [x] GitHub Actions: analyze, test, database tests; pull request template
- [ ] Repo hygiene to verify: `hs_err_pid*.log` removed and ignored, `.env*` ignored, no leftover `.github/java-upgrade`, `.github/modernize`
- [ ] Protect `develop` and `main` on GitHub (require a pull request and the two CI checks)

## Phase 1 - Identity and workspaces (FR-A, FR-W, FR-S01-S04)

- [x] Sign up (terms), sign in, sign out (this device / all), session restore, e-mail verification
- [x] Change password (re-authentication), delete account (typed confirmation), forgot password (one-time code)
- [x] `AuthRemoteDataSource` + `AuthRepositoryImpl`; every error mapped to a failure
- [x] Workspace use cases (create, switch); active workspace flows through `AuthBloc` and keyed providers (no `WorkspaceSessionCubit` was needed)
- [x] Onboarding flow (resumable) and second-workspace flow
- [x] Settings: password, sign out everywhere, delete account
- [ ] Change e-mail (needs a confirmation page or a code flow like the password reset)
- [ ] Sign-up confirmation by code (also removes the localhost link problem)
- [ ] `ReauthenticateUseCase` and protected switch beyond "confirm" (biometric / password), attempt lockout
- [ ] Session lock (timeout, background), biometric unlock, hide content in the task switcher
- [ ] Settings: appearance (theme), language, privacy and terms screen, notification preferences
- [ ] Force-update check against `app_config`

## Phase 2 - Core ledger (FR-C, FR-G01-02, FR-T01-04, FR-X01-02, FR-U01)

- [x] Accounts: create, edit (name, opening balance), archive, restore, derived balances
- [x] Categories: create, edit, archive, restore
- [x] Transactions: create, edit, confirm pending, soft delete + 10-second undo, search, filters, pages of 20
- [x] Transfers: internal and owner withdrawal/contribution via RPC; delete via RPC
- [x] Trash screen: deleted transactions stay 30 days and can be restored; a daily job removes them for good after that
- [x] Transfers: a deleted transfer can be restored from the trash (both legs; a card payment cannot)
- [ ] Local read cache (Drift) per workspace, offline banner (starts FR-Y01)

## Phase 3 - Cards, budgets, recurring (FR-K, FR-B01-02, FR-R, FR-T05-06)

- [x] Credit cards: create, limit usage, invoices, invoice detail, edit, archive
- [x] Installments via RPC; pay invoice via RPC
- [x] Budgets with versions and end markers, progress UI
- [x] Recurring: create, pause/resume, edit, delete; `generate_my_recurring` on open and by a daily job
- [x] Daily jobs with `pg_cron`: close invoices, generate recurring occurrences
- [ ] Partial invoice payment
- [ ] Receipt attach (private bucket)
- [x] Transactions: filter by date range
- [ ] Transactions: "move to another account"

## Phase 4 - Overview and alerts (FR-D, FR-N, FR-B03, FR-U02, FR-Y01)

- [x] Dashboard: balance, month, budgets, upcoming
- [x] Charts: income vs expenses (6 months), spending by category
- [ ] Dashboard cache first, refresh in background (needs the local cache)
- [x] Reports: monthly report (summary vs the month before, spending by category, biggest expenses)
- [ ] Report export (CSV / PDF)
- [ ] Local notifications (due dates, bills, pending digest); FCM token registration; Edge Function jobs
- [x] In-app alerts on the dashboard: budgets at 80% and 100%, bills overdue or due in 3 days
- [ ] Notification centre screen
- [ ] Audit log viewer

## Phase 5 - Intelligence (FR-I, FR-G03)

- [ ] Forecast (isolate), with explanation screen
- [ ] Yield simulator (`Decimal`), optional CDI fetch adapter
- [ ] Tax reserve (Business)
- [ ] Receipt OCR (ML Kit) with review step
- [ ] Smart category suggestion (on-device)

## Phase 6 - Data and currency (FR-E, FR-M, FR-X03, FR-Y02)

- [ ] CSV/PDF export; export-my-data file
- [ ] OFX import with preview and duplicate detection
- [ ] Multi-currency totals and display conversion (rate adapter)
- [ ] Offline write queue + conflict screen

## Phase 7 - Hardening and release

- [ ] Accessibility audit (TalkBack/VoiceOver, 200 % font, contrast, charts)
- [ ] Security review (RLS re-test, secrets scan, token storage in secure storage), LGPD review (policy text, erasure, portability)
- [ ] Custom SMTP with an owned domain; leaked-password protection (Pro plan)
- [ ] Performance pass (cold start, 100 000-row dataset)
- [ ] Localisation (pt-BR and en)
- [ ] Store assets, privacy labels, release build, crash reporting

## Workflow

```
git checkout develop && git pull
git checkout -b feature/<name>
# work, commit with Conventional Commits
git push -u origin feature/<name>   # open a PR into develop; CI must be green
```

One feature branch per checklist group, small PRs, tests with the code, `POLISH.md` and the docs updated in the same PR.