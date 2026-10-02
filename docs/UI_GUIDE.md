# Finly - UI Guide

Turns the *Guia de Identidade Visual* (March 2026) into rules a developer can code against. Palette and fonts come from the guide; the accessibility notes and extra tokens are additions needed to meet WCAG 2.1 AA (SRS NFR-08).

## 0. Logo

Official mark: a stylised **shield with two arrows in motion** (blue arrows, gold shield half) and the word **FINLY** in a bold geometric sans in Midnight Black, with the slogan **INTELIGÊNCIA FINANCEIRA**.

| File (`assets/`) | Use |
|---|---|
| `finly_logo_stacked.png` (1092 x 1092) | Documents, splash, login, README |
| `finly_logo_horizontal.png` (1568 x 560) | App bar / wide headers, e-mails, site |
| `finly_app_icon.png` (1092 x 1092) | Launcher icon source (shield only) |

- Use on **light backgrounds** only: the wordmark is dark and disappears on `midnight`. A white-wordmark version is needed for dark surfaces.
- Clear space around the logo equals the height of the "F"; never recolour, stretch, rotate or add effects. Do not redraw the shield in code.
- The PNGs have a white background (they are not transparent despite the file names) and are raster. Before Phase 7 get the **vector** files (SVG/PDF), a truly **transparent** PNG and a white-wordmark variant; the launcher icon needs adaptive-icon layers on Android.

## 1. Colour tokens

| Token | Hex | Brand meaning | Use |
|---|---|---|---|
| `midnight` | `#101820` | Sóbrio | Dark surfaces, desktop sidebar, text on gold |
| `white` | `#FFFFFF` | Clareza | Main background, text on dark |
| `techBlue` | `#1060E3` | Confiança | Primary actions, links, income, Personal accent |
| `gold` | `#F29D38` | Lucro | Highlights, expense bars, badges (not text on white) |
| `deepBlue` | `#1A2E44` | Empresa | Business workspace header and accents |
| `structure` | `#A8A8A8` | Estrutura | Borders, dividers, disabled (not text on white) |

Added tokens (not in the guide; needed for accessibility and states):

| Token | Hex | Use |
|---|---|---|
| `textSecondary` | `#4B5563` | Secondary text on white |
| `surfaceTint` | `#F3F6FC` | Card background on white pages |
| `success` | `#1E7A4F` | Goals reached, posted, text and icons |
| `danger` | `#B42318` | Overspent budget, failed, errors |
| `warning` | `#B54708` | 80-100 % budget, pending attention |
| `techBlueOnDark` | `#5B8DEF` | Blue text/icons on `midnight` (plain `techBlue` is only 3.2:1 there) |

### Contrast (computed)

| Pair | Ratio | Verdict |
|---|---|---|
| `techBlue` on white | 5.52 | passes text AA |
| white on `techBlue` | 5.52 | passes (buttons) |
| white on `deepBlue` | 13.83 | passes |
| white on `midnight` | 17.89 | passes |
| `midnight` on `gold` | 8.23 | passes (text on gold buttons/badges) |
| `gold` on `midnight` | 8.23 | passes (gold text is fine on dark) |
| `textSecondary` on white | 7.56 | passes |
| `gold` on white | **2.17** | fails: never text or icons that carry meaning on white |
| `structure` on white | **2.38** | fails: borders and disabled only |
| `structure` on `midnight` | 7.53 | passes on dark (captions in sidebar) |

Rule: **gold and structure never carry text on a light background.** On gold, text is `midnight`.

## 2. Typography

| Role | Font | Notes |
|---|---|---|
| Titles, section headers, big balances' labels | **Poppins** (500/600) | per guide |
| Body, labels, tables, **all numbers** | **Inter** (400/500) | enable tabular figures for money columns: `FontFeature.tabularFigures()` |

Scale (sp): display 32, title 22, subtitle 18, body 16, label 14, caption 12. Respect system font scaling up to 200 % (layouts must wrap, never clip). Bundle fonts as assets (no runtime download; works offline).

## 3. Spacing, shape, elevation

- 4-pt grid: 4, 8, 12, 16, 24, 32.
- Cards: radius 16, soft shadow (`blur 12, y 4, alpha 0.06`), padding 16. Page gutter 16 (phone), 24 (tablet).
- Buttons: radius 12, min height 48. Chips: radius 999.
- "Breathing room" (guide): prefer whitespace over dividers; white main background.
- Desktop/tablet (later): left navigation in `midnight`; phone uses a bottom bar.

## 4. Workspace theming (guide 4.3 and 5)

| | Personal (CPF) | Business (CNPJ) |
|---|---|---|
| Header / app bar | white, `techBlue` accent | `deepBlue`, white text |
| Workspace chip | `techBlue` outline, label "Pessoal" | `deepBlue` fill, label "Empresa" |
| Focus | daily spend, budgets, goals; simpler layout | cash flow, reports, tax reserve |

The chip (name + type) is on every screen. Switching changes the header colour immediately, so the user can always tell where they are. This is a visual aid, not decoration: it is the first defence against posting in the wrong workspace.

### Switch flow (FR-W04)

1. Tap the chip: a bottom sheet opens listing the other workspace.
2. Sheet shows **from -> to** (name, type, colour swatch) and a primary button "Mudar para Empresa".
3. Depending on the user's protection level: nothing more (confirm), biometric prompt, or password field.
4. On success the header animates to the new colour (200 ms) and the dashboard reloads.
5. Wrong password: inline error, attempts counter after the 3rd failure, lock message with remaining time after the 5th.

Default level is **Confirm**; users can raise it in Settings > Security.

## 5. Components

- **Money text**: Inter, tabular figures, sign always shown for transactions (`+ R$ 1.234,56`, `- R$ 89,90`), never colour alone. Large balances use Poppins only for the label, Inter for the figure.
- **Transaction row**: category icon in a tinted circle, description, account and time as caption, amount right-aligned, status icon (clock = pending, check = posted, alert = failed).
- **Status icons** (guide 4.2): discrete, 16 px, always with a text label available to screen readers.
- **Budget bar/ring**: neutral under 80 %, `warning` 80-100 %, `danger` above 100 % with "R$ X acima do limite" text.
- **Empty states**: illustration-free, one sentence + primary action ("Adicionar primeira conta").
- **Loading**: skeleton rows for lists; never a blank screen. **Offline**: slim banner "Offline - atualizado há 3 min".
- **Destructive actions**: confirm dialog naming the item, or snackbar with Undo (10 s) for transaction deletion.

## 6. Data visualisation (guide 4.2)

| Chart | Use | Colours |
|---|---|---|
| Bars | Income vs expense per period | income `techBlue`, expense `gold` (proposal, SRS OP-2) |
| Donut | Budgets and category share | category colours; centre shows percent and amount |
| Line | Forecast, balance trend | `techBlue` line, projected part dashed |

Always label values and add a legend with text; do not rely on colour alone. Charts get a text summary for screen readers ("Receitas R$ 5.000, despesas R$ 3.800").

## 7. Accessibility checklist

- Text contrast >= 4.5:1, large text and icons >= 3:1 (table above).
- Touch targets >= 48 x 48 dp.
- Every icon button has a `Semantics` label; every chart has a text alternative.
- Support dark mode with the same tokens (`midnight` surfaces, `techBlueOnDark` for blue text).
- Do not rely on colour alone for status, sign, or budget state.
- Test with TalkBack/VoiceOver and 200 % font scale before each release.

## 8. Screen inventory

Splash/lock · Sign in · Sign up · Verify e-mail · Reset password · Onboarding (type, tax ID, first account, categories) · Workspace switcher sheet · Dashboard · Accounts list/detail/form · Credit card (settings, invoices list, invoice detail, pay) · Installment purchase · Transactions list (search, filter chips) · Transaction form (with receipt scan) · Transfer form (internal / owner) · Trash · Categories · Budgets · Recurring bills · Reports · Forecast · Yield simulator · Tax reserve (Business) · Import OFX preview · Export · Notification centre · Audit log · Settings (profile, security: lock timeout, biometrics, switch protection, appearance, language, notifications, privacy & terms, export my data, delete account) · Force-update screen.

## 9. Flutter token starter

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const midnight = Color(0xFF101820);
  static const white = Color(0xFFFFFFFF);
  static const techBlue = Color(0xFF1060E3);
  static const gold = Color(0xFFF29D38);
  static const deepBlue = Color(0xFF1A2E44);
  static const structure = Color(0xFFA8A8A8);

  static const textSecondary = Color(0xFF4B5563);
  static const surfaceTint = Color(0xFFF3F6FC);
  static const success = Color(0xFF1E7A4F);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFB54708);
  static const techBlueOnDark = Color(0xFF5B8DEF);
}
```

Fonts: add Poppins and Inter files under `assets/fonts/`, declare them in `pubspec.yaml`, and set `ThemeData.textTheme` so titles use Poppins and everything else Inter. Widgets read colours from `Theme.of(context)`; no hard-coded colours in widget code (SRS FR-S01).
