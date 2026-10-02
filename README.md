<p align="center"><img src="assets/finly_logo_stacked.png" alt="Finly - Inteligência Financeira" width="220"></p>

# Finly - Financial Intelligence System

**Finly** is a personal and business finance manager built with **Flutter** and **Supabase**. One login gives access to two isolated workspaces - **Personal (CPF)** and **Business (CNPJ)** - with accounts, credit cards, budgets, recurring bills, forecasting and more.

## Developer

* **Name:** Ottavio Lucri de Souza
* **Education:** Student at Federal University of Itajubá (UNIFEI)
* **Focus:** Mobile development and software architecture

## Documentation

| Document | What it is |
|---|---|
| [`Finly_SRS_v4`](Finly_SRS_v4.tex) | Requirements: what the system does and the rules it follows |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, folders, state management, error handling, decisions (ADRs) |
| [`docs/DATABASE.md`](docs/DATABASE.md) | ERD, security model, RPC functions, how to apply the SQL |
| [`docs/UI_GUIDE.md`](docs/UI_GUIDE.md) | Brand tokens, accessibility, components, screens |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Build order and checklists (single place for status) |
| [`sql/`](sql) | Authoritative schema, RLS, triggers, RPCs, DB tests |

## Architecture in one paragraph

Clean Architecture, feature-first. `presentation` (BLoC) -> `domain` (entities, use cases, repository interfaces, pure Dart) <- `data` (Supabase and local cache). Errors are values (`Either<Failure, T>` with `dartz`). Money is an integer number of cents. The database enforces isolation and integrity itself (RLS, constraints, triggers, RPC functions), so a bug in the app cannot leak or corrupt data.

## Key features

* **Dual workspaces** with protected switching and strict data isolation
* **Accounts and credit cards** with automatic invoices, installments and invoice payment
* **Transactions and transfers** (pending/posted/failed, trash with undo, owner withdrawals between workspaces)
* **Budgets, recurring bills, dashboard and reports**
* **Intelligence:** 12-month forecast, yield simulator, tax reserve for businesses, receipt OCR, smart categories
* **Security and privacy:** biometric/PIN lock, audit trail, LGPD erasure and export
* **Brazilian specifics:** CPF and CNPJ (including alphanumeric CNPJ) validation by check digits

## Tech stack

Flutter and Dart · Supabase (PostgreSQL, Auth, Storage, Edge Functions) · BLoC · get_it · go_router · Drift · dartz and equatable · Google ML Kit · FCM

## Getting started

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Database: apply `sql/00` to `sql/05` in the Supabase SQL editor (see `docs/DATABASE.md`). Check the rules locally with:

```bash
pip install pgserver "psycopg[binary]"
python sql/tests/run_db_tests.py
```

## Roadmap

Tracked in [`docs/ROADMAP.md`](docs/ROADMAP.md): Phase 0 foundation · 1 identity and workspaces · 2 core ledger · 3 cards, budgets, recurring · 4 overview and alerts · 5 intelligence · 6 data and currency · 7 hardening and release.
