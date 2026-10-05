# Finly - Roadmap

The whole product is built; phases only fix the order (each depends on the one before). Requirement IDs refer to `Finly_SRS_v4`. Tick boxes in git as you go; this file is the only place that tracks status.

**Definition of done for any task:** code + tests green, `flutter analyze` clean, SRS acceptance line satisfied, docs/SQL updated if behaviour changed, merged by pull request into `develop`.

## Where the project is today

Branch `feature/auth-domain`. Done: `Failure`, `Validators` (email, CPF, CNPJ), entities (`User`, `Workspace`), `AuthRepository` interface, partial models. Not compiling until the entity/model fix below is applied. Supabase dev project still has the old draft schema.

## Phase 0 - Foundation

- [ ] Fix compile errors: `TaxIdType`, `ownerId`/`taxIdType` in `WorkspaceEntity`, nullable `activeWorkspaceId`, `byName` parsing in models
- [ ] Delete `hs_err_pid*.log`; extend `.gitignore` (`hs_err_pid*.log`, `.env*`); remove `.github/java-upgrade` and `.github/modernize`
- [ ] Commit current work on `feature/auth-domain` (data models, `sql/`, docs)
- [ ] Copy `sql/` and `docs/` from this package into the repo; replace `database.md` with `docs/DATABASE.md`
- [ ] Supabase dev project: run `99_reset_dev.sql`, then `00`-`05`; confirm 14 tables with RLS on
- [ ] Run `python sql/tests/run_db_tests.py` locally (61 checks pass)
- [ ] Replace counter `widget_test.dart` and boilerplate `main.dart`
- [ ] Add packages: `supabase_flutter`, `flutter_bloc`, `get_it`, `go_router`, `flutter_secure_storage`, `intl`, `mocktail`, `bloc_test`
- [ ] `core/config` (`--dart-define` for Supabase URL and anon key), `core/di`, `core/router` skeleton
- [ ] `core/theme`: `AppColors`, text styles, light and dark `ThemeData`; Poppins + Inter assets (see `UI_GUIDE.md`)
- [ ] `core/money/Money` + tests; `core/error` failure set + Postgres error mapper + tests
- [ ] Validators: alphanumeric CNPJ, email TLD `{2,}`, unit tests (use `00000000E08G12` and `11222333000181`)
- [ ] GitHub Actions: analyze, test, DB tests

## Phase 1 - Identity and workspaces (FR-A, FR-W, FR-S01-S04)

- [ ] Auth use cases: SignUp, SignIn, SignOut (this device / all), ResetPassword, ChangePassword/Email, DeleteAccount, with tests
- [ ] `AuthRemoteDataSource` + `AuthRepositoryImpl`; map errors to failures
- [ ] Screens: sign in, sign up (terms), verify e-mail, reset password
- [ ] Workspace use cases: CreateWorkspace (RPC), SwitchWorkspace, ReauthenticateUseCase
- [ ] `WorkspaceSessionCubit` + keyed providers; state flush test
- [ ] Onboarding flow (resumable) and second-workspace flow
- [ ] Protected switch: confirm / biometric / password levels, attempt lockout
- [ ] Session lock (timeout, background), biometric unlock, hide content in task switcher
- [ ] Settings: security, appearance (theme), language, privacy and terms, delete account
- [ ] Force-update check against `app_config`

## Phase 2 - Core ledger (FR-C, FR-G01-02, FR-T01-04, FR-X01-02, FR-U01)

- [ ] Accounts: CRUD, archive, balances from `account_balances`
- [ ] Categories: list, CRUD, archive
- [ ] Transactions: create, edit, status changes, soft delete + undo + Trash
- [ ] Transfers: internal, owner withdrawal/contribution via RPC; delete via RPC
- [ ] Local read cache (Drift) per workspace, offline banner (starts FR-Y01)

## Phase 3 - Cards, budgets, recurring (FR-K, FR-B01-02, FR-R, FR-T05-06)

- [ ] Card settings, invoice list/detail, limit usage
- [ ] Installments via RPC; pay invoice via RPC
- [ ] Budgets with versions, progress UI
- [ ] Recurring templates; `generate_my_recurring` on start
- [ ] Search + filter chips, pagination; receipt attach (private bucket)

## Phase 4 - Overview and alerts (FR-D, FR-N, FR-B03, FR-U02, FR-Y01)

- [ ] Dashboard (cache first, refresh in background)
- [ ] Reports and charts
- [ ] Local notifications (due dates, bills, pending digest); FCM token registration; Edge Function + `pg_cron` jobs (`06_jobs.sql`)
- [ ] Notification centre; budget alerts
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

- [ ] Accessibility audit (TalkBack/VoiceOver, 200 % font, contrast)
- [ ] Security review (RLS re-test, secrets scan, token storage), LGPD review (policy text, erasure, portability)
- [ ] Performance pass (cold start, 100 000-row dataset)
- [ ] Store assets, privacy labels, release build, crash reporting

## Workflow

```
git checkout develop && git pull
git checkout -b feature/<name>
# work, commit with Conventional Commits
git push -u origin feature/<name>   # open PR into develop
```

One feature branch per checklist group, small PRs, tests with the code.
