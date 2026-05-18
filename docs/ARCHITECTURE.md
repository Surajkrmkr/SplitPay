# DimeFlow — Architecture Reference

---

## Folder Structure

```
lib/
├── main.dart                         ← App entry: Hive init, dummy seed, ProviderScope
├── app.dart                          ← MaterialApp.router, theme, router wiring
│
├── core/                             ← App-wide constants and utilities
│   ├── constants/
│   │   ├── app_colors.dart           ← All color tokens (dark/light/semantic/category)
│   │   └── app_sizes.dart            ← Spacing, radius, icon size constants
│   ├── theme/
│   │   └── app_theme.dart            ← AppTheme.darkTheme / AppTheme.lightTheme
│   ├── extensions/
│   │   └── context_ext.dart          ← BuildContext shortcuts (isDark, width, etc.)
│   └── utils/
│       ├── currency_formatter.dart   ← format(), formatCompact(), currency map
│       └── date_formatter.dart       ← formatDate(), formatShort(), isSameDay(), etc.
│
├── data/                             ← Data layer (models + persistence)
│   ├── models/
│   │   └── transaction_model.dart    ← Transaction, TransactionType, Category + extensions
│   └── services/
│       └── hive_service.dart         ← Hive box management, CRUD, dummy seed
│
├── providers/                        ← Riverpod state layer
│   ├── transaction_provider.dart     ← All transaction providers + computed derivations
│   ├── theme_provider.dart           ← ThemeModeNotifier (dark/light, persisted)
│   └── settings_provider.dart        ← onboardingCompleted, CurrencyNotifier
│
├── router/
│   └── app_router.dart               ← GoRouter with StatefulShellRoute
│
├── features/                         ← One folder per screen/feature
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   ├── main_shell/
│   │   └── main_shell.dart           ← Bottom nav + center FAB shell
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── widgets/
│   │       ├── greeting_header.dart
│   │       ├── balance_card.dart
│   │       ├── category_overview.dart
│   │       └── recent_transactions.dart
│   ├── add_transaction/
│   │   └── add_transaction_sheet.dart
│   ├── transactions/
│   │   ├── transactions_screen.dart
│   │   └── widgets/
│   │       └── transaction_tile.dart
│   ├── analytics/
│   │   ├── analytics_screen.dart
│   │   └── widgets/
│   │       ├── spending_pie_chart.dart
│   │       ├── weekly_bar_chart.dart
│   │       └── monthly_trend.dart
│   └── settings/
│       └── settings_screen.dart
│
└── shared/
    └── widgets/                      ← Reusable cross-feature widgets
        ├── glass_card.dart           ← GlassCard + SurfaceCard
        ├── empty_state.dart          ← EmptyState with icon, text, CTA
        ├── shimmer_loading.dart      ← ShimmerBox + ShimmerTransactionList
        └── ad_placeholder.dart      ← Banner, Native, Rewarded placeholders
```

---

## Data Flow

```
User Action
    │
    ▼
Screen / Widget (ConsumerWidget)
    │  ref.read(provider.notifier).method()
    ▼
StateNotifier (TransactionNotifier)
    │  calls HiveService
    ▼
HiveService (Hive Box)
    │  persists Map to disk
    │  notifier reloads from box
    ▼
StateNotifier emits new state
    │
    ▼
Computed Providers re-evaluate
(balance, breakdown, weekly, monthly…)
    │
    ▼
Widgets rebuild automatically
```

---

## Provider Dependency Graph

```
transactionProvider (StateNotifier)
    ├── totalIncomeProvider       ← month filter + income type
    ├── totalExpenseProvider      ← month filter + expense type
    ├── balanceProvider           ← income - expense
    ├── recentTransactionsProvider ← take(5)
    ├── categoryBreakdownProvider ← month expenses, grouped by Category
    ├── weeklySpendingProvider    ← 7-day array by weekday index
    ├── monthlyTrendProvider      ← 6-element array by month
    │
    ├── filterProvider (StateProvider) ─┐
    │                                   ├── filteredTransactionsProvider
    └── searchQueryProvider (State) ───┘
                                        └── searchedTransactionsProvider
```

---

## Theme System

`AppTheme.darkTheme` and `AppTheme.lightTheme` are full `ThemeData` objects with:
- `ColorScheme` using Material 3
- `TextTheme` via `GoogleFonts.plusJakartaSansTextTheme()`
- Custom `AppBarTheme`, `CardThemeData`, `InputDecorationTheme`, `BottomSheetThemeData`, `FloatingActionButtonThemeData`, `SwitchTheme`, `ChipTheme`

`themeModeProvider` is a `StateNotifier<ThemeMode>` persisted in Hive. Toggled via `ref.read(themeModeProvider.notifier).toggle()`.

`MaterialApp.router` watches `themeModeProvider` and rebuilds on toggle — the entire app theme changes with a single provider write.

---

## Hive Storage Schema

**Box: `transactions_v1`**

Key: UUID string (`String`)
Value: `Map<String, dynamic>`

```dart
{
  'id':        String,   // UUID v4
  'amount':    double,
  'type':      String,   // 'income' | 'expense'
  'category':  String,   // enum name (e.g. 'food')
  'note':      String?,  // nullable
  'date':      int,      // millisecondsSinceEpoch
  'createdAt': int,      // millisecondsSinceEpoch
}
```

**Box: `settings_v1`**

| Key | Type | Default |
|---|---|---|
| `isDarkMode` | `bool` | `true` |
| `currency` | `String` | `'\$'` |

**Migration strategy:** When the schema changes, increment the box name suffix (`_v1` → `_v2`) and run a migration in `HiveService.init()`.

---

## Animation Patterns

All entrance animations use `flutter_animate` `.animate()` chains.

**Standard card entrance:**
```dart
widget.animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
```

**Staggered list items:**
```dart
item.animate(delay: (index * 60).ms).fadeIn().slideX(begin: 0.05)
```

**Spring-out scale (FAB, profile badge):**
```dart
widget.animate().scale(duration: 400.ms, curve: Curves.elasticOut)
```

**Animated numeric counter:**
```dart
TweenAnimationBuilder<double>(
  duration: 1200.ms,
  tween: Tween(begin: 0, end: value),
  curve: Curves.easeOutCubic,
  builder: (context, v, _) => Text(format(v)),
)
```

**Chart animations:**
- `PieChart`: `swapAnimationDuration: 400.ms, curve: Curves.easeInOutCubic`
- `BarChart`: `swapAnimationDuration: 600.ms, curve: Curves.easeInOutCubic`
- `LineChart`: `duration: 600.ms, curve: Curves.easeInOutCubic`

---

## Routing

```
/onboarding       ← shown if onboarding_completed == false
/home             ─┐
/transactions      ├─ StatefulShellRoute (indexed stack, keeps state)
/analytics         │  wrapped in MainShell (bottom nav + FAB)
/settings         ─┘
```

Page transition: `CustomTransitionPage` with `FadeTransition`. Tab switches use `NoTransitionPage` for instant swap (standard mobile UX).

`initialLocation` is set once at router creation from `onboardingCompletedProvider`. After onboarding, the provider state is updated to `true` and `context.go('/home')` is called manually.

---

## Adding a New Feature — Checklist

1. Create `lib/features/<name>/<name>_screen.dart`
2. Add widgets in `lib/features/<name>/widgets/`
3. Add providers to `lib/providers/<name>_provider.dart` (or extend existing)
4. Register route in `lib/router/app_router.dart`
5. If it's a new tab, add a `StatefulShellBranch` and nav item in `main_shell.dart`
6. Add to `docs/FEATURES.md`
7. Remove from `docs/TODO.md`
