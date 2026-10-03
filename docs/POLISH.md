# Finly - Polish and gaps

Things known to be rough or missing. Cosmetic items are done in one batch
(Phase 7); anything wrong or risky is fixed when found.

## Visual
- [ ] Transfer form: label "Entre contas deste workspace" when it is the only mode
- [ ] Transfer form: show the implied exchange rate between currencies (catches typos)
- [ ] Transfer form: helper text "informe os dois valores" is cut off
- [ ] Selected chips are gold (brand secondary); consider Tech Blue via a chip theme
- [ ] Poppins and Inter fonts are not bundled yet (default font is used)
- [ ] Tabular figures for money columns
- [ ] Check dark and light mode, 200% font scale and TalkBack on every screen

## Missing in finished features
- [ ] Transactions: edit, search and filters, pagination (20 per page)
- [ ] Transfers: undo after delete (needs a database function)
- [ ] Accounts: rename, list and unarchive archived accounts
- [ ] Categories: create, rename, recolour, archive (FR-G02)
- [ ] Credit cards (account type exists, no settings or invoices yet)

## Auth and privacy
- [ ] Password reset, change e-mail and password, delete account
- [ ] E-mail confirmation link opens a localhost error (needs a landing page or deep link)
- [ ] Session lock, biometrics, protected switch beyond "confirm" (FR-A07, FR-A08, FR-W04)
- [ ] Terms acceptance version, settings screen

## Technical
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] GitHub Actions: analyze, tests, database tests
- [ ] Widget and golden tests for the main screens
- [ ] Update ARCHITECTURE.md, DATABASE.md and ROADMAP.md to match what was built# Finly - Polish and gaps

Things known to be rough or missing. Cosmetic items are done in one batch
(Phase 7); anything wrong or risky is fixed when found.

## Visual
- [ ] Transfer form: label "Entre contas deste workspace" when it is the only mode
- [ ] Transfer form: show the implied exchange rate between currencies (catches typos)
- [ ] Transfer form: helper text "informe os dois valores" is cut off
- [ ] Selected chips are gold (brand secondary); consider Tech Blue via a chip theme
- [ ] Poppins and Inter fonts are not bundled yet (default font is used)
- [ ] Tabular figures for money columns
- [ ] Check dark and light mode, 200% font scale and TalkBack on every screen

## Missing in finished features
- [ ] Transactions: edit, search and filters, pagination (20 per page)
- [ ] Transfers: undo after delete (needs a database function)
- [ ] Accounts: rename, list and unarchive archived accounts
- [ ] Categories: create, rename, recolour, archive (FR-G02)
- [ ] Credit cards (account type exists, no settings or invoices yet)

## Auth and privacy
- [ ] Password reset, change e-mail and password, delete account
- [ ] E-mail confirmation link opens a localhost error (needs a landing page or deep link)
- [ ] Session lock, biometrics, protected switch beyond "confirm" (FR-A07, FR-A08, FR-W04)
- [ ] Terms acceptance version, settings screen

## Technical
- [ ] All texts are hard-coded in Portuguese (move to localisation: pt-BR and en)
- [ ] Offline: no local cache yet (FR-Y01)
- [ ] Dates use the phone's time zone; the database uses America/Sao_Paulo for budget months
- [ ] Move switchWorkspace from the auth repository to the workspace repository
- [ ] GitHub Actions: analyze, tests, database tests
- [ ] Widget and golden tests for the main screens
- [ ] Update ARCHITECTURE.md, DATABASE.md and ROADMAP.md to match what was built