# DimeFlow — Todo & Future Roadmap

> Status key: `[ ]` Planned · `[~]` In progress · `[x]` Done · `[!]` Blocked

---

## 🔴 Priority 1 — Core Completions (MVP polish)

- [ ] **Edit transaction** — tap any tile to open pre-filled `AddTransactionSheet`
- [ ] **Delete confirmation dialog** — confirm before dismissing a transaction (swipe shows dialog)
- [ ] **Transaction detail screen** — full-screen view of a single transaction
- [ ] **Input haptics** — `HapticFeedback.lightImpact()` on save, delete, tab change
- [ ] **Error handling** — catch Hive write failures, show snackbar feedback
- [ ] **Keyboard dismiss on tap outside** — wrap screens in `GestureDetector` with `FocusScope.unfocus()`
- [ ] **Recurring transactions badge** — show a "recurring" icon on seeded subscription entries

---

## 🟠 Priority 2 — Feature Additions

### Budget Goals
- [ ] `Budget` model — `category`, `limitAmount`, `period` (monthly/weekly)
- [ ] Budget progress bar on home screen CategoryCard
- [ ] Over-budget warning color (red) when spending > 90% of limit
- [ ] Budget screen under Settings or Analytics

### Export & Backup
- [ ] CSV export using `csv` package — all transactions, date range selector
- [ ] PDF export using `pdf` + `printing` packages — monthly statement layout
- [ ] Share via native share sheet (`share_plus`)
- [ ] Import from CSV (reverse parsing)

### Recurring Transactions
- [ ] `isRecurring` + `recurrenceInterval` fields on Transaction model
- [ ] Auto-create next occurrence on app launch
- [ ] Manage recurring list in Settings

### Search & Filtering
- [ ] Amount range filter (e.g. > $50)
- [ ] Date range picker filter
- [ ] Multi-category filter (select multiple categories)
- [ ] Sort options — by amount, by date asc/desc

### Notifications
- [ ] Daily spending reminder using `flutter_local_notifications`
- [ ] Budget limit alert when approaching 80% of budget
- [ ] Monthly summary push notification on 1st of month

---

## 🟡 Priority 3 — Analytics Enhancements

- [ ] **Income vs Expense bar chart** — side-by-side comparison per month
- [ ] **Spending velocity** — "You're spending 23% faster than last month"
- [ ] **Average transaction value** per category
- [ ] **Calendar heatmap** — spending intensity by day (like GitHub contributions)
- [ ] **Custom date range** selector for all charts
- [ ] **Animate chart number changes** — when switching month/period, tween old → new values
- [ ] **Export chart as image** — screenshot to gallery

---

## 🔵 Priority 4 — UX Polish

- [ ] **Hero transitions** — category icon animates from tile to detail screen
- [ ] **Pull-to-refresh** animation on home dashboard
- [ ] **Skeleton shimmer** — show `ShimmerTransactionList` on first load instead of empty list
- [ ] **Haptic patterns** — different patterns for save, delete, error
- [ ] **Bottom sheet drag indicator** — improve drag feel with snap points
- [ ] **Smooth theme transition** — cross-fade instead of instant switch
- [ ] **Custom splash screen** — animated DimeFlow logo on launch
- [ ] **App icon** — design and apply custom icon for iOS/Android
- [ ] **Adaptive icon** — Android 8+ adaptive icon support
- [ ] **iPad layout** — two-column layout on wider screens
- [ ] **Landscape support** — currently portrait-only

---

## 🟢 Priority 5 — Monetization & Growth

### Ads (Placeholders Ready)
- [ ] Integrate `google_mobile_ads` package
- [ ] Wire `BannerAdPlaceholder` in home screen
- [ ] Wire `NativeAdPlaceholder` in transaction list (every ~10 items)
- [ ] Wire `RewardedAdButton` in Settings for premium unlock
- [ ] Configure AdMob App ID in `AndroidManifest.xml` + `Info.plist`
- [ ] Add GDPR consent form (`google_mobile_ads` User Messaging Platform)

### Premium / IAP
- [ ] `in_app_purchase` package setup
- [ ] Premium feature: unlimited budgets, CSV export, no ads
- [ ] Premium badge in profile card
- [ ] Restore purchases support

### App Store Readiness
- [ ] Privacy policy URL (required for both stores)
- [ ] App store screenshots (6.7", 6.1", iPad 12.9")
- [ ] App Store description copy
- [ ] Keywords research
- [ ] `NSPrivacyAccessedAPITypes` — add required reason keys for iOS 17+

---

## ⚫ Priority 6 — Advanced (Post-MVP)

### Cloud & Sync
- [ ] Firebase Auth (anonymous + Google sign-in)
- [ ] Firestore sync for transactions
- [ ] Conflict resolution strategy (last-write-wins or merge)
- [ ] Offline queue — sync pending writes when connectivity restored
- [ ] Multi-device support

### Security
- [ ] Biometric / Face ID lock screen using `local_auth`
- [ ] Auto-lock after configurable idle timeout
- [ ] Data encryption at rest (Hive encrypted box)

### Multi-Account
- [ ] Account model — personal, business, joint
- [ ] Account switcher in header
- [ ] Per-account totals and analytics
- [ ] Transfer between accounts

### Widgets
- [ ] iOS home screen widget — balance + today's spend
- [ ] Android home screen widget
- [ ] Lockscreen widget (iOS 16+)

### AI Insights
- [ ] On-device spending anomaly detection
- [ ] "Unusual spend" badge on transaction
- [ ] Monthly insight summary ("You spent 40% more on food this month")

---

## 🐛 Known Issues & Tech Debt

| Issue | File | Severity |
|---|---|---|
| `withOpacity` deprecated — use `.withValues(alpha:)` | Multiple files | Low — compiles fine, future API |
| `activeColor` deprecated on Switch | `settings_screen.dart` | Low — using `activeThumbColor` already |
| Category breakdown counts income categories | `transaction_provider.dart:categoryBreakdownProvider` | Minor — only expenses filtered in provider, correct |
| No Hive migration strategy | `hive_service.dart` | Medium — box is named `_v1`, increment name for schema changes |
| `google_fonts` downloads at runtime | `app_theme.dart` | Low — add fonts as bundled assets for offline first launch |
| No pagination in transaction list | `transactions_screen.dart` | Low — fine for MVP, add `ListView.builder` pagination at ~1000+ items |

---

## 📦 Package Upgrade Watchlist

| Package | Current | Available | Notes |
|---|---|---|---|
| `flutter_riverpod` | 2.6.1 | 3.3.1 | v3 has breaking changes — migrate when stable |
| `go_router` | 14.8.1 | 17.2.3 | Check route API changes before upgrading |
| `fl_chart` | 0.68.0 | 1.2.0 | 1.x may have API changes — test charts |
| `google_fonts` | 6.3.3 | 8.1.0 | Safe to upgrade |
| `intl` | 0.19.0 | 0.20.2 | Safe to upgrade |

Run `flutter pub outdated` to see full list.

---

## 🗂 File Naming Conventions (for new features)

```
lib/
  features/
    <feature_name>/
      <feature_name>_screen.dart     ← main screen widget
      widgets/
        <component_name>.dart        ← sub-widgets
  data/
    models/
      <model_name>_model.dart
    services/
      <service_name>_service.dart
  providers/
    <feature>_provider.dart
```

All new Riverpod providers go in `lib/providers/`. Keep providers file-grouped by feature area, not one-class-per-file.
