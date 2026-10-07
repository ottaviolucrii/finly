# Finly - Architecture

Companion to `Finly_SRS_v4`. The SRS says *what*; this file says *how*, and it describes what the code does **today**. Things that are planned but not built are marked *(planned)*. Every decision has an ID (ADR-xx) at the bottom so it can be revisited without rewriting the SRS.

## 1. Principles

1. **Dependencies point inward.** `presentation -> domain <- data`. The domain layer is pure Dart: no Flutter, no Supabase, no JSON.
2. **The database defends itself.** Rules that protect money and isolation (RLS, constraints, triggers, RPC functions) live in PostgreSQL. The app can have bugs; the data stays valid and isolated.
3. **Errors are values.** Use cases return `Either<Failure, T>` (dartz). Exceptions stop at the data layer, and the data layer catches *everything* (ADR-14).
4. **Money is an integer.** Never `double`, anywhere (see section 7).
5. **One feature, one folder.** Each feature owns its domain, data, presentation and dependency wiring.

## 2. Layers

```
presentation   Widgets  ->  Cubit / BLoC            (knows Flutter + flutter_bloc)
     |                         |
     v                         v
domain         Entities, UseCases, Repository interfaces, rules   (pure Dart)
     ^
     |
data           Models (map <-> entity), RemoteDataSource (Supabase), RepositoryImpl
```

Request path: `Widget -> Cubit method -> UseCase -> Repository (interface) -> RepositoryImpl -> RemoteDataSource (Supabase)`.
Response path returns `Either<Failure, Entity>`; the Cubit maps it to a state. A local cache (Drift) is *(planned)*.

## 3. Folder structure (feature first)

```
lib/
  main.dart                    entry: load config, init Supabase, configure DI, runApp
  app.dart                     MaterialApp, theme, AuthGate
  core/
    config/                    app_config.dart (values come from --dart-define-from-file=env.json)
    di/                        injection.dart: registers SupabaseClient, then each feature's module
    error/                     failure.dart, error_mapper.dart
    money/                     money.dart (value object)
    security/                  device_authenticator.dart (biometrics / PIN behind an interface)
    share/                     file_sharer.dart (the share sheet behind an interface)
    theme/                     app_colors.dart, app_theme.dart (Poppins, Inter, tabular figures)
    usecase/                   usecase.dart
    utils/                     validators.dart, tax_id_formatter.dart, date_format.dart, iso_date.dart, windows_1252.dart
  features/
    auth/                      sign in/up, e-mail verification, session, password recovery
    workspaces/                onboarding, second workspace, protected switch (confirm / biometric / password)
    accounts/                  list, create, edit, archive, restore archived
    categories/                list, create, edit, archive, restore
    transactions/              create, edit, search, filters (type, status, account, category, period), pagination, delete + undo
    transfers/                 internal + owner transfers
    trash/                     deleted transactions and transfers: list and restore (30 days)
    cards/                     card settings, invoices, installments, pay invoice, edit, archive
    budgets/                   monthly limits with versions and end markers
    recurring/                 create, edit, pause, delete, pending occurrences
    dashboard/                 balance, month, charts, budgets, upcoming, "Atenção" card
    alerts/                    budgets near the limit, bills overdue or due soon (shown on the dashboard)
    reports/                   monthly report, CSV export of the month
    reminders/                 local notifications for pending bills and card invoices
    forecast/                  balance forecast for 30, 60 and 90 days (pure rules, one chart painter)
    lock/                      session lock, biometrics or PIN, password fallback, brute-force limit
    settings/                  change password, sign out everywhere, delete account, app lock, notifications
      <each feature>/
        domain/    entities/  repositories/  usecases/  (+ *_rules.dart for pure logic)
        data/      models/    datasources/   repositories/
        presentation/ cubit|bloc/  pages/  widgets/  (+ *_messages.dart, *_style.dart)
        di/        <feature>_di.dart
assets/fonts/                  Poppins and Inter (OFL licenses included)
test/                          mirrors lib/ (+ test/core/di/injection_test.dart)
sql/                           authoritative schema and database tests (see DATABASE.md)
docs/
.github/workflows/ci.yml       analyze, test, database tests
```

*(planned)* features, not started: `yield_simulator`, `tax_reserve`, `receipt_ocr`, `import_export` (import, PDF, export of all data), `currency`, `audit` viewer, a notification centre and push notifications.

Known untidiness (tracked in `POLISH.md`): `switchWorkspace` still lives in the auth repository. The repository method `deleteBudget` is unused (budgets are stopped with an end marker).

## 4. State management, navigation and workspace context

- **Cubit** for almost everything, **Bloc** for auth (`AuthBloc`). Every state is `Equatable`: a `status` enum, the data, a `failure` (the screen could not load) and an `actionFailure` (an action failed; shown as a message, the data stays).
- **Navigation is plain `Navigator`**, with an `AuthGate` that picks sign-in, onboarding or home from the `AuthBloc` state (ADR-11). A pushed page pops with `true` when it changed something, and the page below reloads.
- **Workspace context.** `AuthBloc` holds the `UserEntity`, which carries the workspaces and `activeWorkspaceId`. Every screen is opened *for* a `WorkspaceEntity` and builds its own cubits for it:

```dart
BlocProvider(
  create: (_) => sl<TransactionsCubit>()..load(workspace.id),
  child: _TransactionsView(workspace: workspace),
)
```

  The home keys the dashboard providers by workspace id (`key: ValueKey(active.id)`), so switching workspace disposes every cubit of the old one. This is how FR-W05 ("no data from workspace A while B is active") is guaranteed structurally, not by discipline.
- **Switching** (`SwitchWorkspaceCubit`): a sheet (from -> to) asks for what the protection level of the user requires (FR-W04): a tap on "confirm" (default), the phone's biometrics or PIN with the account password as a fallback, or the account password -> `switch_workspace` RPC with a 20-second timeout -> `UserReplaced(user)` on `AuthBloc`. The sheet calls `onConfirm` once and only when the protection is satisfied. The cubit catches every error and never stays stuck.

Patterns used by the cubits:

| Pattern | Where | Why |
|---|---|---|
| Keep the old data on screen while reloading | every list and the dashboard | no flicker; a failed reload keeps what was there |
| Remove at once, restore on failure | delete transaction / transfer | a swiped row must leave the tree in the same frame |
| Number each request, ignore stale answers | transaction search and filters | a slow old answer never replaces a newer one |
| Pages of 20, `loadMore`, no duplicates | transactions | stable under inserts between pages |
| One cubit per action | edit, delete, archive, restore, recovery | each screen only depends on what it does |
| Plain `for` loops, never `firstWhere(orElse: ...)` over model lists | cards, invoices, charts | the `orElse` base type breaks at runtime when the list holds data-layer models |

### Re-authentication (ADR-18)

Changing the password and deleting the account first call `signInWithPassword` with the typed password, so a stolen unlocked phone is not enough. Deleting also needs the typed word `EXCLUIR`, checked in the use case and not only on screen.

### Password recovery (ADR-15)

```
Esqueci minha senha -> e-mail -> resetPasswordForEmail           (always answers the same)
  -> e-mail with a one-time code (template shows {{ .Token }})
  -> code + new password -> verifyOTP(type: recovery) -> updateUser(password)
  -> signOut(others) -> signOut(local): nobody stays signed in; the person signs in again
```

The code check signs the person in for a moment, so the local sign-out runs in a `finally`: it happens even if the password change fails. The password is validated *before* the code is spent. See `SUPABASE_SETUP.md` for the dashboard settings this flow needs.

### Session lock and biometrics (ADR-19)

`AppLockGate` wraps the whole app in `MaterialApp.builder`, **above the navigator**, so the lock screen covers every page and dialog and leaves their state alone (the navigator stays alive but is not drawn or reachable while locked). `AppLockCubit` (one for the whole app) decides when to lock:

| Trigger | Rule |
|---|---|
| App start with a saved login | starts locked |
| Signing in by typing the password | never locked on top of it |
| Back from the background | locks when the time away is at least the chosen time; "immediately" locks on every return |
| Idle in the foreground | a 5-second timer; any touch resets it; "immediately" never idle-locks |
| The phone's own prompt on screen | sends the app to the background for a moment; ignored through a flag |

The time (immediately, 1, 2, 5 or 15 minutes; default 2), the biometric switch and the switch protection level are stored in `user_settings` (`lock_timeout_seconds`, `biometric_enabled`, `switch_protection`). Unlocking uses the phone's biometrics or PIN (`local_auth`, behind `DeviceAuthenticator`) or the account password (`signInWithPassword`). Wrong passwords go through one shared `AttemptLimiter`: five wrong ones block **every** password prompt (lock screen and workspace switch) for five minutes (FR-A09; the counter lives in memory). A cover is drawn when the app leaves the screen so the app switcher shows no balances (best effort on Android; blocking screenshots with `FLAG_SECURE` is *(planned)*). Android needs `MainActivity` to extend `FlutterFragmentActivity` and the `USE_BIOMETRIC` permission.

### Reminders (ADR-20)

Local notifications for **pending bills** (expenses that are not card purchases and not transfers) and **unpaid card invoices**, for the active workspace only. `SyncRemindersUseCase` reads the next 30 days, `buildReminders` (pure rules) turns them into at most 40 notifications at 9h: a bill gets one the day before (or its own `lead_days` when it comes from a recurring item) and one on the due day; an invoice gets one 3 days before and one on the due day. `LocalReminderScheduler` (`flutter_local_notifications`) replaces the whole schedule every time, with stable notification ids, in "inexact" mode (a few minutes late is normal, no special permission). `RemindersGate` triggers a rebuild on sign-in, workspace change, leaving and returning to the app; signing out cancels everything. Content is `private` on the lock screen. Preferences live in `user_settings.notification_prefs` (`bill_reminder`, `card_due`; unknown keys are kept). Android needs core library desugaring, the boot receivers and `POST_NOTIFICATIONS`; Xiaomi/HyperOS also needs Autostart and unrestricted battery for the app. Budget alerts as push notifications need a server and are *(planned)*; the dashboard card covers them in the app.

### Alerts and reports

The "Atenção" card (`alerts`) is computed in the app from the budget overview and the upcoming pending items; it needs no table. The monthly report (`reports`) reads `monthly_flow` and `monthly_category_spend` for the month and the one before. The CSV export pages through the transactions of the month and writes `;`-separated, comma-decimal, ISO-dated text in Windows-1252 (what Excel in Brazil and the Android Sheets app read correctly), with a leading apostrophe on text that starts with `=`, `+`, `-` or `@` (ADR-21).

## 5. Error handling

`Failure` hierarchy (domain):

| Failure | Typical source |
|---|---|
| `AuthFailure` | not signed in, wrong password, wrong or expired code (`invalid_code`), unverified e-mail, rate limited |
| `PermissionFailure` | RLS / ownership (`42501`, `forbidden`) |
| `ValidationFailure` | invalid tax id, weak password, same password, bad input |
| `ConflictFailure` | duplicate / already exists (`23505`) |
| `RuleFailure` | business rule from a trigger or function (`23514`, `P0001`); the message is kept |
| `NetworkFailure` | timeouts, `SocketException`, handshake errors, retryable auth fetch errors |
| `ServerFailure` | anything else, including bugs (`unknown_error`) |

`ErrorMapper` converts Supabase exceptions and the stable message keys the SQL raises (`invalid_tax_id`, `workspace_type_already_exists`, `invoice already paid`, `category kind ...`, ...) into these failures. **Every `RepositoryImpl` catches everything** (ADR-14): a runtime bug becomes `ServerFailure('unknown_error')`, printed to the console, and the screen shows "Algo deu errado" with a retry button instead of an endless spinner. The UI turns a failure into text in a per-feature `*_messages.dart` (Portuguese, hard-coded until localisation, *(planned)*), never a raw server message.

## 6. Supabase usage

| Use case | Call |
|---|---|
| Sign up / in / out | `auth.signUp`, `signInWithPassword`, `signOut(scope: local / global)` |
| Change password | re-auth with `signInWithPassword`, `updateUser(password)`, `signOut(scope: others)` |
| Forgot password | `resetPasswordForEmail`, `verifyOTP(recovery)`, `updateUser(password)`, sign-outs (section 4) |
| Delete account | re-auth, `rpc('delete_my_account')`, local sign-out |
| Create / switch workspace | `rpc('create_workspace', ...)`, `rpc('switch_workspace', ...)` |
| Credit cards | `rpc('create_credit_card', ...)`, `rpc('create_installments', ...)`, `rpc('pay_invoice', ...)`; limit and days by table update |
| Transfers | `rpc('create_transfer', ...)`, `rpc('delete_transfer', ...)`, `rpc('restore_transfer', ...)` |
| Recurring | `rpc('generate_my_recurring')` on every open, `rpc('update_recurring', ...)`, `rpc('delete_recurring', ...)`; create and pause by table |
| Move a transaction | `rpc('move_transaction', ...)` |
| Trash | `from('transactions')` with `deleted_at` set (RLS lets the owner read deleted rows); restore a transaction by table update, a transfer by `restore_transfer` |
| Settings | `from('user_settings')` read and update (`lock_timeout_seconds`, `biometric_enabled`, `switch_protection`, `notification_prefs`) |
| Reminders | `from('transactions')` (pending expenses, with the `lead_days` of the recurring item embedded), `from('accounts')`, `from('credit_card_invoices')`, `from('invoice_totals')` |
| Balances and aggregates | `from('account_balances')`, `from('invoice_totals')`, `from('monthly_category_spend')`, `from('monthly_flow')` |
| Everything else | `from('<table>')` CRUD (RLS applies) |

Rules of thumb: simple single-row writes go straight to the table; anything touching several rows, or needing a rule the client must not bypass, goes through an RPC. Two known exceptions that are two writes in the app: editing a card (name, then settings) and nothing else. The `service_role` key is never shipped in the app; the anon key is public by design and RLS is the protection. Daily jobs (`pg_cron`) close invoices, generate recurring occurrences (`sql/10`) and purge the trash after 30 days (`sql/13`), even when the app is closed.

E-mail confirmation note: with confirmation on, `signUp` returns no session. The app shows the verification screen and creates the first workspace after the first verified sign-in (onboarding resumes; FR-W01). The confirmation link still opens a localhost page: a landing page or a code flow is *(planned)*.

## 7. Money

`core/money/money.dart`: `Money(cents, currency)`, an immutable value object with an integer `cents`, an ISO 4217 `currency`, `format()` (Brazilian style, sign handled by the caller), `Money.tryParse(text, currency)` ("1.234,56" -> 123456 with no `double` involved) and `symbolFor(currency)`. Installment splitting is done in the database (the first part takes the remainder, BR-14). Percentages are basis points (`int`); yield and forecast *(planned)* use `Decimal` and round half up to the cent at the end of each period.

## 8. Offline strategy (ADR-04) *(planned)*

| Phase | Capability |
|---|---|
| 1-5 | Online writes. Reads cached in Drift per workspace; screens show "offline / last updated". **Today: everything is online-only.** |
| 6 | Write queue: operations stored locally with client-generated UUIDs, replayed in order, idempotent. Conflict rule: last write wins for descriptive fields; amount conflicts ask the user. |

The schema is ready: UUID primary keys, `updated_at` on every table, soft delete on transactions, unique indexes with `on conflict` for recurring.

## 9. Security checklist

Done:
- RLS on every table; the app never ships `service_role`.
- Re-authentication for sensitive actions; delete account needs a typed confirmation.
- Password policy in the app: 8+ characters with letters and numbers (the server setting should match; see `SUPABASE_SETUP.md`).
- Password change and reset sign the other devices out; "sign out of all devices" exists.
- Config via `--dart-define-from-file=env.json` (git-ignored); nothing sensitive committed.
- The workspace switch cannot get stuck; no data of another workspace survives a switch; it can ask for biometrics or the password (FR-W04).
- Session lock after inactivity, in the background and at every start; unlock with biometrics, PIN or password; five wrong passwords block password prompts for five minutes (FR-A07 to FR-A09).
- Reminders show their content only after the phone is unlocked, and signing out removes them.

To do (Phase 7 hardening):
- The session is stored by `supabase_flutter`'s default storage. Move tokens to `flutter_secure_storage`.
- Block screenshots and make the app switcher reliable (`FLAG_SECURE`); force the password after a new fingerprint is enrolled; Android 8 and older need an AppCompat launch theme for the biometric prompt; iOS needs `NSFaceIDUsageDescription`.
- No PII in analytics or crash reports; mask CPF/CNPJ in the UI by default.
- Leaked-password protection (needs the Pro plan) and custom SMTP for real users.
- Receipts bucket is private; path is `<user_id>/<file>` (storage file `05`).

## 10. Testing and CI

| Level | Tooling | What |
|---|---|---|
| Database | `python sql/tests/run_db_tests.py` (embedded Postgres) | 109 checks: RLS, constraints, triggers, RPCs, views, the trash purge, restore of transfers |
| Domain | `flutter_test`, `mocktail` | validators, `Money`, rules, use cases with mocked repositories |
| Data | `flutter_test` | models, repository implementations with mocked data sources (including "an unexpected error becomes a failure"), error mapper |
| Presentation | `bloc_test`, widget tests | cubit state sequences; the chart, lock screen, switch sheet, alerts and settings widgets |
| Wiring | `test/core/di/injection_test.dart` | builds every bloc and cubit from the DI modules with a fake Supabase client |
| Device | manual checklist per feature | every screen on a phone before a PR |

About 1,350 Dart tests. GitHub Actions (`.github/workflows/ci.yml`) runs `flutter analyze`, `flutter test` and the database tests on every pull request and push to `develop` and `main`, with the same Flutter version as the development machine (3.41.6; move both together). The database tests cannot run on Windows (the embedded Postgres has no time zone database): CI runs them. Protecting the branches so a red PR cannot merge is tracked in `POLISH.md`.

## 11. Conventions

- Branches: `main` (releases) <- `develop` <- `feature/<name>`. Every feature goes through a pull request into `develop`; the PR template has a checklist.
- Commits: Conventional Commits (`feat(auth): ...`, `fix(db): ...`, `docs: ...`, `ci: ...`, `chore: ...`).
- Dart: `flutter_lints`; files `snake_case.dart`; no `dynamic` in domain; one public class per file for entities and use cases (small state/params classes may sit with their use case).
- Use cases: one class, one public method `call(Params)`, returning `Future<Either<Failure, T>>`. Validation lives in the use case; the database repeats the rules that protect data.
- Models extend entities; entities never import models.
- A database change is a numbered file in `sql/`, applied to Supabase and added to `DATABASE.md` in the same PR; if it has behavior, it gets checks in `run_db_tests.py`.
- Anything configured by hand in the Supabase dashboard goes in `SUPABASE_SETUP.md`.

## 12. Packages

In use: `supabase_flutter`, `flutter_bloc`, `equatable`, `dartz`, `get_it`, `share_plus` (the share sheet for exports), `local_auth` (biometrics), `flutter_local_notifications` (pinned to 19.x, whose API is known) with `timezone`, `flutter_lints`, `mocktail`, `bloc_test`. Fonts Poppins and Inter are bundled as assets. Charts are drawn with `CustomPainter` (ADR-16), not a chart package. Plugins that touch the platform sit behind small interfaces (`DeviceAuthenticator`, `FileSharer`, `ReminderScheduler`) so tests never reach the platform.

*(planned)*: `go_router` (if navigation grows: deep links), `drift` + `sqlite3_flutter_libs`, `flutter_secure_storage`, `intl` (with localisation), `decimal`, `image_picker`, `google_mlkit_text_recognition`, `firebase_messaging`, `pdf`, `printing`, `package_info_plus`. `go_router` and `intl` were removed from `pubspec.yaml` until they are needed. Versions are pinned when added.

## 13. Decision log

| ID | Decision | Why |
|---|---|---|
| ADR-01 | Clean Architecture, feature-first folders | Testability; features can be built and deleted independently |
| ADR-02 | BLoC/Cubit (not Provider) | Explicit events/states; best fit for use-case flow and `bloc_test` |
| ADR-03 | Supabase with RLS + RPC for multi-row rules | Isolation and integrity enforced where the data lives |
| ADR-04 | Online writes first, offline queue in Phase 6 | Offline sync is the highest risk; schema is ready for it |
| ADR-05 | Derived balances (no stored balance) | No drift, no race conditions, trivially auditable |
| ADR-06 | Transfers as two linked legs | Per-account history, per-workspace isolation, auditable |
| ADR-07 | Integer cents, basis points, `Decimal` for yield | No floating-point error |
| ADR-08 | Audit by trigger, definer rights, append-only | Catches changes made outside the app; actor from session |
| ADR-09 | Workspace access through `is_workspace_member()` | One place to change when sharing is introduced |
| ADR-10 | Drift for local cache *(planned)* | Typed SQL, migrations, works on mobile and later web/desktop |
| ADR-11 | **Deferred:** plain `Navigator` + `AuthGate` instead of `go_router` | Enough so far (the session lock turned out to be a gate above the navigator, ADR-19); revisit with deep links |
| ADR-12 | Tax-ID uniqueness not enforced globally | Avoids leaking whether a CPF/CNPJ is registered; revisit (SRS OP-1) |
| ADR-13 | One DI module per feature, plus a test that builds every bloc and cubit | `injection.dart` stays small; a forgotten registration fails a test, not a screen |
| ADR-14 | Repositories catch every error, log unexpected ones | A bug shows a retry button, never an endless spinner |
| ADR-15 | Password recovery with a one-time code, not a link | No deep link or landing page needed; works with a one-time template edit |
| ADR-16 | Charts drawn with `CustomPainter`; aggregates computed in the database (`monthly_flow`) | Exact brand control, no dependency, no download of every transaction |
| ADR-17 | A recurring item's schedule is immutable; edits go through an RPC that also updates pending occurrences; delete detaches the history | The generator numbers occurrences from the schedule; history must survive |
| ADR-18 | Re-authenticate for sensitive actions | A stolen unlocked phone is not enough |
| ADR-19 | The session lock is a gate above the navigator (`MaterialApp.builder`), not a screen in it; its settings live in `user_settings`; the password fallback signs in again; one in-memory limiter serves every password prompt | The lock must cover every page and dialog and leave their state alone; the database already had the columns; a restart of the app starts locked anyway |
| ADR-20 | Reminders are local notifications scheduled by the app, rebuilt from the data on every use, for the active workspace only | No server or Firebase needed; the other workspace's data never appears in a notification; the limit is that the app must be used now and then |
| ADR-21 | CSV export as Windows-1252 text with `;`, decimal comma and ISO dates, shared through the share sheet | The Android Sheets app and Excel in Brazil misread UTF-8 files and swap day and month in `dd/MM/yyyy` |
| ADR-22 | The trash keeps deleted rows for 30 days, then a daily job removes them; deleted transfers are restored by a function, never leg by leg; a card invoice payment is not restorable | Mistakes are recoverable; a restored payment would lower the card debt while the invoice stays open |
