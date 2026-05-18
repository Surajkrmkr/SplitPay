# DimeFlow — Feature Documentation

> Current version: **1.0.0 (MVP)**
> Last updated: May 2026

---

## 1. Onboarding

**File:** `lib/features/onboarding/onboarding_screen.dart`

| Detail | Value |
|---|---|
| Pages | 3 |
| Shown | First launch only |
| Persistence | `SharedPreferences` key `onboarding_completed` |
| Animation | Page slide + emoji scale (spring curve) |

**Pages:**
1. *Track Every Penny* — introduces expense logging
2. *Visualize Spending* — teases analytics
3. *Stay on Budget* — CTA to get started

Each page has a gradient background, large emoji illustration, title, subtitle, and animated page indicator dots. The accent color shifts per page (emerald → indigo → pink).

---

## 2. Home Dashboard

**File:** `lib/features/home/home_screen.dart`

**Widgets:**

| Widget | File | Description |
|---|---|---|
| `GreetingHeader` | `widgets/greeting_header.dart` | Time-aware greeting + notification bell |
| `BalanceCard` | `widgets/balance_card.dart` | Glassmorphism card with animated balance counter |
| `CategoryOverview` | `widgets/category_overview.dart` | Top-4 category grid with animated progress bars |
| `RecentTransactions` | `widgets/recent_transactions.dart` | Last 5 transactions, "See all" link |

**Balance card features:**
- Glassmorphism using `BackdropFilter` + `ImageFilter.blur`
- Deep emerald gradient background (`#1A3A2A → #0F1D16`)
- Animated balance counter via `TweenAnimationBuilder<double>`
- Income / Expense mini stats with colored arrow icons
- "This Month" badge with green dot indicator

**Animations:**
- All cards: `.animate().fadeIn().slideY()` with staggered delays
- Balance counter: 1200ms ease-out cubic tween
- Category progress bars: 800ms tween on mount

---

## 3. Add Transaction

**File:** `lib/features/add_transaction/add_transaction_sheet.dart`

Presented as a **modal bottom sheet** from the FAB in `MainShell`.

**Fields:**

| Field | Type | Notes |
|---|---|---|
| Amount | `TextFormField` | Large styled input, number keyboard, 2 decimal places |
| Type | Custom toggle | Expense (red) / Income (green), animated container swap |
| Category | Chip grid | Filtered by type — income shows only Salary + Other |
| Note | `TextFormField` | Optional, 2-line, sentence case |
| Date | Date picker | Material date picker, max = today |

**UX details:**
- Autofocuses amount field on open
- Animated save button (gradient, glow shadow)
- Loading spinner while saving
- Form validates before saving
- UUID v4 for each transaction ID

**Data flow:** `AddTransactionSheet` → `ref.read(transactionProvider.notifier).add(tx)` → `HiveService.addTransaction()` → state updates reactively across all screens

---

## 4. Transaction History

**File:** `lib/features/transactions/transactions_screen.dart`

**Features:**

| Feature | Implementation |
|---|---|
| Filter tabs | `TransactionFilter` enum — All / Today / Week / Month |
| Live search | `searchQueryProvider` — filters by category label or note |
| Grouped by date | Map bucketed by "Today" / "Yesterday" / date string |
| Swipe to delete | `Dismissible` widget, end-to-start direction |
| Empty state | Custom `EmptyState` widget with context-aware message |

**Transaction tile** (`widgets/transaction_tile.dart`):
- Category icon in rounded colored container
- Category + note + date text hierarchy
- Colored amount (green = income, red = expense)
- Type badge pill
- Staggered entrance animation per item index

---

## 5. Analytics

**File:** `lib/features/analytics/analytics_screen.dart`

**Insight cards (top row):**

| Card | Calculation |
|---|---|
| Savings Rate | `(income - expense) / income × 100` (clamped 0–100) |
| Avg/Day | `expense / 30` |
| Total Transactions | `transactionProvider.length` |

**Charts:**

| Chart | Widget | Data source |
|---|---|---|
| Spending by Category | `SpendingPieChart` | `categoryBreakdownProvider` |
| This Week | `WeeklyBarChart` | `weeklySpendingProvider` |
| 6-Month Trend | `MonthlyTrendChart` | `monthlyTrendProvider` |

**Pie chart details:**
- Interactive touch — touched section expands + shows badge icon
- Custom legend below chart with category color chips
- Animated swap on data change (400ms ease-in-out-cubic)

**Bar chart details:**
- Today's bar highlighted in emerald, others in secondary blue
- Background bars show chart max
- Tooltip on touch with currency-formatted value

**Line chart details:**
- Smooth curved line, current month dot enlarged
- Gradient fill below line
- Month labels (MMM) on X axis
- Touch tooltip with currency value

**Top Category card:** Gradient tinted card showing highest-spend category with icon, label, percentage, and amount.

---

## 6. Settings / Profile

**File:** `lib/features/settings/settings_screen.dart`

**Sections:**

| Section | Items |
|---|---|
| Profile card | Avatar, username placeholder, tagline |
| Preferences | Dark/light mode toggle, currency selector |
| Data | Export CSV (placeholder), Backup (placeholder) |
| About | App version, Rate app (placeholder), Privacy policy (placeholder) |

**Currency selector:** Bottom sheet modal with 7 currencies — USD, EUR, GBP, JPY, INR, CAD, AUD. Selection persisted via `HiveService`.

**Theme toggle:** Switches `ThemeMode` between dark/light, persisted to Hive. Takes effect immediately across the whole app via `themeModeProvider`.

---

## 7. Shared Widgets

**File location:** `lib/shared/widgets/`

| Widget | File | Purpose |
|---|---|---|
| `GlassCard` | `glass_card.dart` | Reusable glassmorphism container |
| `SurfaceCard` | `glass_card.dart` | Standard elevated card with border |
| `EmptyState` | `empty_state.dart` | Icon + title + subtitle + optional CTA |
| `ShimmerBox` | `shimmer_loading.dart` | Single shimmer placeholder rectangle |
| `ShimmerTransactionList` | `shimmer_loading.dart` | Pre-built shimmer list (5 items) |
| `BannerAdPlaceholder` | `ad_placeholder.dart` | 50px banner slot |
| `NativeAdPlaceholder` | `ad_placeholder.dart` | 100px native card slot |
| `RewardedAdButton` | `ad_placeholder.dart` | Rewarded ad trigger button |

---

## 8. Data Layer

**Transaction model** (`lib/data/models/transaction_model.dart`):
- `TransactionType`: `income` / `expense`
- `Category`: 9 values with `.label`, `.icon`, `.color`, `.isIncome` extensions
- `Transaction.toMap()` / `Transaction.fromMap()` — Hive-compatible flat Map

**HiveService** (`lib/data/services/hive_service.dart`):
- Box `transactions_v1` — keyed by UUID, value = `Map`
- Box `settings_v1` — keyed by string, generic value
- `seedDummyData()` — 15 realistic transactions, runs only if box is empty

**Providers** (`lib/providers/transaction_provider.dart`):

| Provider | Type | Value |
|---|---|---|
| `transactionProvider` | `StateNotifierProvider` | `List<Transaction>` sorted date desc |
| `totalIncomeProvider` | `Provider<double>` | Current month income sum |
| `totalExpenseProvider` | `Provider<double>` | Current month expense sum |
| `balanceProvider` | `Provider<double>` | income − expense |
| `recentTransactionsProvider` | `Provider<List>` | Latest 5 |
| `categoryBreakdownProvider` | `Provider<Map>` | Category → amount (current month expenses) |
| `weeklySpendingProvider` | `Provider<List<double>>` | 7-day spending by weekday |
| `monthlyTrendProvider` | `Provider<List<double>>` | 6-month expense totals |
| `filterProvider` | `StateProvider` | Selected `TransactionFilter` |
| `searchQueryProvider` | `StateProvider<String>` | Live search string |
| `filteredTransactionsProvider` | `Provider<List>` | Filter applied |
| `searchedTransactionsProvider` | `Provider<List>` | Filter + search applied |

---

## 9. Navigation

**Router** (`lib/router/app_router.dart`):
- `go_router` with `StatefulShellRoute.indexedStack`
- Initial location: `/onboarding` (first launch) or `/home`
- 4 shell branches: `/home`, `/transactions`, `/analytics`, `/settings`
- Fade page transitions

**Bottom nav** (inside `MainShell`):
- 4 items with active/inactive icon swap animation
- FAB docked at center above nav bar
- FAB opens `AddTransactionSheet` as modal bottom sheet

---

## 10. Ads Integration (Placeholders)

Ready-to-swap placeholder components in `lib/shared/widgets/ad_placeholder.dart`.

To activate AdMob:
1. Add `google_mobile_ads` to `pubspec.yaml`
2. Swap `BannerAdPlaceholder` → real `AdWidget(ad: BannerAd(...))`
3. Swap `NativeAdPlaceholder` → real `AdWidget(ad: NativeAd(...))`
4. Wire `RewardedAdButton.onPressed` → `RewardedAd.load(...)`
5. Add AdMob App IDs to `AndroidManifest.xml` and `ios/Runner/Info.plist`
