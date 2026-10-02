# Finly - Architecture

Companion to `Finly_SRS_v4`. The SRS says *what*; this file says *how*. Every decision here has an ID (ADR-xx) at the bottom so it can be revisited without rewriting the SRS.

## 1. Principles

1. **Dependencies point inward.** `presentation -> domain <- data`. The domain layer is pure Dart: no Flutter, no Supabase, no JSON.
2. **The database defends itself.** Rules that protect money and isolation (RLS, constraints, triggers, RPC functions) live in PostgreSQL. The app can have bugs; the data stays valid and isolated.
3. **Errors are values.** Use cases return `Either<Failure, T>` (dartz). Exceptions stop at the data layer.
4. **Money is an integer.** Never `double`, anywhere (see section 7).
5. **One feature, one folder.** Each feature owns its domain, data and presentation.

## 2. Layers

```
presentation   Widgets  ->  BLoC/Cubit            (knows Flutter + flutter_bloc)
     |                         |
     v                         v
domain         Entities, UseCases, Repository interfaces   (pure Dart)
     ^
     |
data           Models (JSON <-> entity), DataSources (Supabase / Drift), RepositoryImpl
```

Request path: `Widget -> Bloc event -> UseCase -> Repository (interface) -> RepositoryImpl -> RemoteDataSource (Supabase) / LocalDataSource (Drift)`.
Response path returns `Either<Failure, Entity>`; the Bloc maps it to a state.

## 3. Folder structure (feature first)

```
lib/
  main.dart                  entry: load config, init DI, runApp
  app.dart                   MaterialApp.router, theme, localisation
  core/
    config/                  env (--dart-define): SUPABASE_URL, SUPABASE_ANON_KEY
    di/                      get_it registrations (one file per feature + core)
    error/                   failure.dart, exceptions.dart, error_mapper.dart
    money/                   money.dart (value object), money_formatter.dart
    router/                  go_router config, guards (auth, lock, onboarding)
    theme/                   app_colors.dart, app_text_styles.dart, app_theme.dart
    utils/                   validators.dart, date_utils.dart
    widgets/                 shared widgets (cards, empty states, money text)
  features/
    auth/                    sign in/up, verify, reset, session lock, biometrics
    workspaces/              create, switch (protected), context, onboarding
    accounts/
    cards/                   credit card settings, invoices, installments, pay
    transactions/            CRUD, filters, trash, receipts
    transfers/               internal + owner transfers
    categories/
    budgets/
    recurring/
    dashboard/
    reports/
    notifications/
    forecast/
    yield_simulator/
    tax_reserve/
    receipt_ocr/
    import_export/
    currency/
    audit/
    settings/                theme, language, privacy, protection levels
      <each feature>/
        domain/    entities/  repositories/  usecases/
        data/      models/    datasources/ (remote_*, local_*)  repositories/
        presentation/ bloc/   pages/  widgets/
test/                        mirrors lib/
sql/                         authoritative schema + tests (see DATABASE.md)
docs/
```

Today the repo has `features/auth` holding `UserEntity` and `WorkspaceEntity`. Keep them there through Phase 1, then move workspace code to `features/workspaces` when the switch flow is built (one commit, imports only).

## 4. State management and workspace context

- **BLoC/Cubit** for all state (ADR-02). One Bloc per screen or flow; no business logic in widgets.
- A single app-level `WorkspaceSessionCubit` holds the active workspace. Everything workspace-scoped is created *below* a `BlocProvider` keyed by the workspace id:

```dart
BlocProvider(
  key: ValueKey(session.activeWorkspace.id),   // new id => all child blocs recreated
  create: (_) => sl<DashboardBloc>()..add(DashboardStarted(session.activeWorkspace.id)),
  child: const DashboardView(),
)
```

  Changing the key disposes every scoped bloc, stream and cached list of the old workspace. This is how FR-W05 ("no data from workspace A while B is active") is guaranteed structurally, not by discipline.
- Local cache rows are keyed by `workspace_id`; the cache of the other workspace is never read.

### Protected workspace switch (FR-W04)

```
user taps workspace chip
  -> SwitchWorkspaceRequested(target)
  -> read user_settings.switch_protection
       confirm   : show sheet (from -> to, colours)        -> confirmed?
       biometric : local_auth, fallback to password        -> ok?
       password  : ReauthenticateUseCase(password)          -> ok?
  -> SwitchWorkspaceUseCase(target)   // one RPC: switch_workspace(p_workspace_id)
  -> WorkspaceSessionCubit.emit(newActive)  // keyed providers rebuild
```

`ReauthenticateUseCase` calls `signInWithPassword(email, password)` and discards the new session object (the token simply refreshes). A failure counter lives in memory: 5 failures lock the flow for 5 minutes (FR-A09). Optional server hardening: the RPC can require that the session's password-sign-in time is recent (SRS OP-4).

## 5. Error handling

`Failure` hierarchy (domain):

| Failure | Typical source |
|---|---|
| `AuthFailure` | not signed in, wrong password, unverified e-mail (`28000`) |
| `PermissionFailure` | RLS / ownership (`42501`, `forbidden`) |
| `ValidationFailure` | invalid tax id (`22023`), bad input |
| `ConflictFailure` | duplicate / already exists (`23505`) |
| `RuleFailure` | business rule from a trigger or function (`23514`, `P0001`) |
| `NetworkFailure` | timeouts, offline |
| `ServerFailure` | anything else |

`error_mapper.dart` converts `PostgrestException.code` and the stable message keys the SQL raises (`invalid_tax_id`, `workspace_type_already_exists`, `invoice already paid`, ...) into these failures. UI shows localised text per failure type, never raw server messages.

## 6. Supabase usage

| Use case | Call |
|---|---|
| Sign up / in / out / reset | `supabase.auth.*` |
| Create workspace (seeds categories, sets active) | `rpc('create_workspace', {p_name, p_type, p_tax_id})` |
| Switch workspace | `rpc('switch_workspace', {p_workspace_id})` |
| Transfers (internal / owner) | `rpc('create_transfer', ...)`, `rpc('delete_transfer', ...)` |
| Installment purchase | `rpc('create_installments', ...)` |
| Pay invoice | `rpc('pay_invoice', ...)` |
| Generate recurring items on start | `rpc('generate_my_recurring')` |
| Delete account | `rpc('delete_my_account')` then local sign-out |
| Balances, invoice totals, category spend | `from('account_balances')`, `from('invoice_totals')`, `from('monthly_category_spend')` |
| Everything else | `from('<table>')` CRUD (RLS applies) |

Rules of thumb: simple single-row writes go straight to the table; anything touching several rows or needing a rule the client must not bypass goes through an RPC. The `service_role` key is never shipped in the app. The anon key is public by design; RLS is the protection.

E-mail confirmation note: if confirmation is enabled, `signUp` returns no session. The app shows the verification screen and creates the first workspace after the first verified sign-in (onboarding resumes; FR-W01).

## 7. Money

```dart
@immutable
class Money extends Equatable {
  final int cents;           // always integer
  final String currency;     // ISO 4217, e.g. 'BRL'
  const Money(this.cents, this.currency);

  Money operator +(Money o) => _same(o) ? Money(cents + o.cents, currency) : throw CurrencyMismatch();
  Money operator -(Money o) => _same(o) ? Money(cents - o.cents, currency) : throw CurrencyMismatch();
  List<Money> split(int parts);                       // first part takes the remainder (BR-14)
  factory Money.parse(String text, String currency);  // "1.234,56" -> 123456, no double involved
  String format(Locale l);                            // intl NumberFormat.currency
}
```

Rules: no `double` for money; percentages as basis points (`int`); yield and forecast use `Decimal` (package `decimal`) and round half up to the cent at the end of each period.

## 8. Offline strategy (ADR-04)

| Phase | Capability |
|---|---|
| 1-5 | Online writes. Reads are cached in Drift per workspace; screens show "offline / last updated". |
| 6 | Write queue: operations stored locally with client-generated UUIDs, replayed in order, idempotent (unique indexes and `on conflict` already exist for recurring and imports). Conflict rule: last write wins for descriptive fields; amount conflicts ask the user. |

Schema is already ready: UUID primary keys, `updated_at` on every table, soft delete on transactions.

## 9. Security checklist

- Tokens in `flutter_secure_storage`; never in shared preferences or logs.
- Lock on inactivity/background (FR-A07); hide content in app switcher (`FLAG_SECURE` on Android, blur overlay on iOS).
- Config via `--dart-define` (or a git-ignored env file); nothing sensitive committed. Add `hs_err_pid*.log`, `.env*` to `.gitignore`.
- No PII in analytics or crash reports; mask CPF/CNPJ in UI by default.
- Receipts bucket is private; path is `<user_id>/<file>`.
- Never trust the client: every rule has a database twin (see SRS NFR-01/02).

## 10. Testing and CI

| Level | Tooling | What |
|---|---|---|
| Database | `python sql/tests/run_db_tests.py` (embedded Postgres) | RLS, constraints, triggers, RPCs |
| Domain | `flutter_test` | validators, `Money`, use cases with mocked repositories (`mocktail`) |
| Data | `flutter_test` | model mappers, repository impl with fake datasources, error mapper |
| Presentation | `bloc_test`, golden tests | flows and key screens, light and dark |
| Device | manual checklist | biometrics, notifications, OCR, offline |

GitHub Actions on every PR to `develop`: `flutter analyze`, `flutter test --coverage`, DB tests job (Python + pgserver). Merge only when green.

## 11. Conventions

- Branches: `main` (releases) <- `develop` <- `feature/<name>`. Squash-merge features into `develop` by pull request.
- Commits: Conventional Commits (`feat(auth): ...`, `fix(db): ...`, `docs: ...`).
- Dart: `flutter_lints` + strict analysis (`strict-casts`, `strict-inference`); no `dynamic` in domain; files `snake_case.dart`; one public class per file for entities and use cases.
- Use cases: one class, one public method `call(Params)`, return `Future<Either<Failure, T>>`.
- Models extend or map to entities; entities never import models.

## 12. Planned packages (versions pinned when added)

`supabase_flutter`, `flutter_bloc`, `equatable`, `dartz`, `get_it`, `go_router`, `drift` + `sqlite3_flutter_libs`, `flutter_secure_storage`, `local_auth`, `intl`, `decimal`, `fl_chart`, `image_picker`, `google_mlkit_text_recognition`, `firebase_messaging`, `flutter_local_notifications`, `pdf`, `printing`, `csv`, `package_info_plus`, `mocktail`, `bloc_test`.

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
| ADR-10 | Drift for local cache | Typed SQL, migrations, works on mobile and later web/desktop |
| ADR-11 | `go_router` + guards (auth, lock, onboarding) | Declarative redirects for protected flows |
| ADR-12 | Tax-ID uniqueness not enforced globally | Avoids leaking whether a CPF/CNPJ is registered; revisit (SRS OP-1) |
