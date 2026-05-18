# DimeFlow — Changelog

All notable changes to this project are documented here.
Format: [Semantic Versioning](https://semver.org/)

---

## [1.0.0] — 2026-05-15 — MVP Release

### Added

**Onboarding**
- 3-page animated onboarding with page indicator dots
- One-time display logic using `SharedPreferences`
- Gradient backgrounds per page with emoji illustrations

**Home Dashboard**
- Time-aware greeting header with notification bell
- Glassmorphism balance card with animated counter
- Income / Expense mini stats on balance card
- Top-4 category grid with animated progress bars
- Recent transactions list (last 5)
- Banner ad placeholder

**Add Transaction**
- Modal bottom sheet triggered from FAB
- Income / Expense type toggle
- 9 categories with icons and colors
- Optional note field, date picker
- Form validation + animated save button

**Transaction History**
- Filter tabs: All / Today / Week / Month
- Live search by category or note
- Grouped by date (Today / Yesterday / date)
- Swipe-to-delete with red background
- Empty state widget

**Analytics**
- Savings rate, avg/day, total transactions insight cards
- Interactive pie chart by category (touch to expand + show badge)
- Weekly spending bar chart (today highlighted)
- 6-month trend line chart with gradient fill
- Top spending category card

**Settings / Profile**
- Profile card with gradient
- Dark / Light mode toggle (persisted to Hive)
- Currency selector — USD, EUR, GBP, JPY, INR, CAD, AUD
- Export / Backup placeholders
- App version, Rate app, Privacy policy (placeholders)

**Architecture**
- Riverpod 2.x state management with `StateNotifier` + computed providers
- Hive local database (no code generation, Map-based storage)
- go_router with `StatefulShellRoute` (indexed tab stack)
- flutter_animate staggered entrance animations throughout
- Material 3 with full dark + light `ThemeData`
- Plus Jakarta Sans typography via google_fonts
- 15-item dummy data seed on first launch
- Ad placeholder widgets ready for AdMob integration

---

## [Unreleased]

See [TODO.md](./TODO.md) for planned features and known issues.
