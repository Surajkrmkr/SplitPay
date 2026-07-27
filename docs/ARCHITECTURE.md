# SplitPay — Architecture Reference

---

## 🌐 System Overview

SplitPay is engineered as a decoupled, multi-tier financial platform comprising:
1. **Flutter Mobile Application:** Cross-platform (iOS/Android) mobile client featuring Material 3, glassmorphism design system, Riverpod 2.x reactive state management, and an offline-first data model.
2. **Node.js / Express REST Backend:** TypeScript server with Prisma ORM and PostgreSQL database, handling user sessions, Firebase token verification, group expense synchronization, budget sync, and push notifications.
3. **On-Device Intelligent Services:** Google ML Kit Text Recognition for real-time receipt scanning and regex-based SMS financial notification parsing.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER CLIENT (MOBILE)                          │
│                                                                             │
│  ┌────────────────────┐   ┌────────────────────┐   ┌─────────────────────┐  │
│  │   UI & Shell       │   │  Riverpod State    │   │  Local Storage      │  │
│  │ (GoRouter, Glass)  │◄─►│ (StateNotifiers)   │◄─►│ (Hive Box Cache)    │  │
│  └────────────────────┘   └─────────┬──────────┘   └─────────────────────┘  │
│                                     │                                       │
│                           ┌─────────▼──────────┐                            │
│                           │ Repositories &     │                            │
│                           │ Services (Dio)     │                            │
│                           └─────────┬──────────┘                            │
└─────────────────────────────────────┼───────────────────────────────────────┘
                                      │ HTTP / REST
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       NODE.JS / EXPRESS BACKEND SERVER                      │
│                                                                             │
│  ┌────────────────────┐   ┌────────────────────┐   ┌─────────────────────┐  │
│  │ Firebase Auth      │   │ Express Routers &  │   │ Prisma ORM          │  │
│  │ Middleware         │──►│ Controllers        │──►│ Client              │  │
│  └────────────────────┘   └────────────────────┘   └─────────┬───────────┘  │
└──────────────────────────────────────────────────────────────┼──────────────┘
                                                               │ PostgreSQL
                                                               ▼
                                                     ┌───────────────────┐
                                                     │ PostgreSQL DB     │
                                                     └───────────────────┘
```

---

## 📁 Codebase Layout

### 1. Flutter Client (`lib/`)

```
lib/
├── main.dart                         ← App entrypoint: Hive init, Firebase init, ProviderScope
├── app.dart                          ← MaterialApp.router, AppTheme, GoRouter wiring
│
├── core/                             ← App-wide tokens & utilities
│   ├── constants/                    # app_colors.dart, app_sizes.dart
│   ├── theme/                        # app_theme.dart (Material 3 Dark & Light theme)
│   ├── extensions/                   # context_ext.dart (BuildContext shortcuts)
│   └── utils/                        # currency_formatter.dart, date_formatter.dart
│
├── data/                             ← Data models, services & repositories
│   ├── models/                       # transaction_model.dart, group_model.dart, budget_model.dart, etc.
│   ├── services/                     # bill_scanner_service.dart, sms_parser_service.dart, upi_service.dart, hive_service.dart, firebase_auth_service.dart, notification_service.dart, biometric_service.dart
│   └── repositories/                 # transaction_repository.dart, budget_repository.dart, payment_repository.dart, notification_repository.dart
│
├── providers/                        ← Riverpod state management layer
│   ├── auth_provider.dart            # AuthStateNotifier (Firebase Google/Email sign-in)
│   ├── transaction_provider.dart     # Personal transactions, filters, computed totals
│   ├── group_provider.dart           # Group expense management, member balances, debt simplification
│   ├── budget_provider.dart          # Multi-period budget tracking & remaining calculations
│   ├── reminder_provider.dart        # Local notification schedules & daily reminder timers
│   ├── notification_provider.dart    # System & activity notifications state
│   ├── settings_provider.dart        # Onboarding state, currency preference
│   └── theme_provider.dart           # Dark/Light theme mode persistence
│
├── router/
│   └── app_router.dart               ← GoRouter configuration with StatefulShellRoute tabs
│
├── features/                         ← Screen & feature modules
│   ├── auth/                         # Splash screen & Login screen (Google/Email sign-in)
│   ├── onboarding/                   # 3-page onboarding walkthrough
│   ├── main_shell/                   # MainShell container with bottom navigation bar & center FAB
│   ├── home/                         # Dashboard header, balance card, mini stats, recent transactions
│   ├── add_transaction/              # Personal expense sheet, OCR scan button, SMS autofill
│   ├── transactions/                 # History screen, live search, multi-criteria filter modal
│   ├── groups/                       # Groups list, Group detail (Balances, Expenses, Activity, Totals), Add Group Expense sheet, Settle Up dialog, Invite code/QR scanner
│   ├── budget/                       # Budget screen, Add budget sheet, Budget detail analytics
│   ├── analytics/                    # Interactive fl_chart visualizer (Pie, Bar, Line charts)
│   ├── notifications/                # Activity feed screen & push notification settings
│   ├── settings/                     # App settings, currency modal, CSV import/export, biometrics toggle
│   └── debug/                        # Debug log viewer screen
│
└── shared/
    └── widgets/                      ← Reusable cross-feature UI widgets
        ├── glass_card.dart           # GlassCard + SurfaceCard containers
        ├── empty_state.dart          # Generic empty state widget
        ├── shimmer_loading.dart      # Shimmer box loading indicators
        └── ad_placeholder.dart       # AdMob banner/native ad placeholders
```

### 2. Backend Server (`server/`)

```
server/
├── prisma/
│   └── schema.prisma                 ← PostgreSQL schema definition (User, Group, Expense, Budget, Settlement, Transaction)
├── src/
│   ├── server.ts                     ← Server entrypoint & port listener
│   ├── app.ts                        ← Express configuration, CORS, rate limiting, route mounting
│   ├── configs/                      # Environment variables, Firebase admin setup, Prisma client
│   ├── middlewares/                  # Auth middleware (Firebase ID token / Session verification), error handler
│   ├── modules/                      # Business logic modules
│   │   ├── auth/                     # Session creation, refresh tokens, Google token exchange
│   │   ├── users/                    # Profile management, FCM token registration
│   │   ├── transactions/             # Personal transaction REST API
│   │   ├── groups/                   # Group CRUD, member roles, invite code generation & validation
│   │   ├── expenses/                 # Shared group expense creation & split calculation
│   │   ├── settlements/              # Debt settlement record creation & balance update
│   │   ├── budgets/                  # Budget CRUD API
│   │   ├── categories/               # User custom category management
│   │   ├── activity/                 # Group activity timeline logging
│   │   └── notifications/            # Push notification delivery via FCM
│   └── utils/                        # Response formatters, logger, debt calculation utilities
├── docker-compose.yml                # PostgreSQL container orchestration
└── Dockerfile                        # Node.js production Docker container build file
```

---

## 🔄 State Management & Reactive Data Flow

SplitPay uses **Riverpod 2.x** with `StateNotifier` and declarative computed `Provider` selectors for ultra-responsive UI updates.

```
User Action (e.g. Add Expense / Settle Up)
                     │
                     ▼
Screen / Widget (ConsumerWidget)
                     │ ref.read(provider.notifier).addExpense(...)
                     ▼
StateNotifier (GroupNotifier / TransactionNotifier)
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
Local Hive Box Storage    Backend REST API (Dio)
 (Instant disk write)     (Async server sync)
        │
        └────────────┬────────────┘
                     │ Emits new state list
                     ▼
Computed Selectors re-evaluate automatically:
├── balanceProvider (income - expense)
├── groupBalancesProvider (calculates who owes whom)
├── budgetProgressProvider (calculates % spent vs limit)
└── categoryBreakdownProvider (groups expenses by category)
                     │
                     ▼
UI Widgets rebuild reactively (No manual setState)
```

---

## 🧮 Group Debt Simplification Algorithm

When group members add expenses with arbitrary splits, calculating minimal payment transfers is handled by the **Debt Simplification Engine** in `lib/providers/group_provider.dart` and `server/src/modules/groups/`:

### Steps:
1. **Net Balance Calculation:** For each member $i$, compute net balance:
   $$\text{NetBalance}_i = \text{TotalPaid}_i - \text{TotalShare}_i$$
2. **Partitioning:** Separate members into two lists:
   - **Debtors:** Members with $\text{NetBalance} < 0$ (they owe money)
   - **Creditors:** Members with $\text{NetBalance} > 0$ (they are owed money)
3. **Greedy Matching:** Sort debtors by ascending balance (most negative first) and creditors by descending balance (most positive first).
4. **Iterative Settlement:** Match the largest debtor with the largest creditor:
   - Settle $\text{Amount} = \min(|\text{DebtorBalance}|, \text{CreditorBalance})$.
   - Generate a simplified debt edge: `Debtor -> Creditor: Amount`.
   - Update balances and repeat until all balances are zeroed.

This reduces $N(N-1)$ potential debt pairs down to at most $N-1$ transactions.

---

## 📷 ML Kit Bill Scanner & SMS Parsing Engines

### 1. Bill Scanner OCR Pipeline (`lib/data/services/bill_scanner_service.dart`)
1. **Image Capture:** `ImagePicker` captures receipt image from camera or gallery.
2. **Text Recognition:** Image passed to `google_mlkit_text_recognition` `TextRecognizer`.
3. **Regex Extraction:**
   - Detects currency patterns: `(?:₹|Rs\.?|INR|\$)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)`
   - Scans line text for total keywords (`TOTAL`, `GRAND TOTAL`, `AMOUNT DUE`, `NET AMOUNT`).
   - Picks maximum matching monetary value as the primary transaction amount.
4. **Title Suggestion:** Extracts top line vendor name or merchant header text.

### 2. SMS Parser Pipeline (`lib/data/services/sms_parser_service.dart`)
1. **SMS Body Input:** Reads incoming or pasted bank SMS alert text.
2. **Pattern Matching:**
   - Detects debit triggers: `debited`, `spent`, `paid to`, `transferred`.
   - Detects credit triggers: `credited`, `received`, `deposited`.
   - Extracts amount: `(?i)(?:Rs|INR|USD|\$)\.?\s*([\d,]+(?:\.\d{1,2})?)`.
   - Extracts merchant: `(?i)(?:at|to|info)\s+([A-Za-z0-9\s&]+?)(?=\s+on|\s+ref|\s+avail|\.|\$)`.
3. **Draft Auto-Fill:** Auto-populates `AddTransactionSheet` fields for instant confirmation.

---

## 🗄 Database Schema Reference

### Prisma PostgreSQL Schema (`server/prisma/schema.prisma`)

| Model | Table Name | Key Fields | Description |
|---|---|---|---|
| `User` | `users` | `id`, `email`, `name`, `avatar`, `googleId` | User accounts and auth credentials |
| `Session` | `sessions` | `id`, `userId`, `refreshToken`, `expiresAt` | Server refresh token sessions |
| `Group` | `groups` | `id`, `name`, `description`, `avatar`, `createdById` | Shared expense group metadata |
| `GroupMember` | `group_members` | `id`, `groupId`, `userId`, `role` | Group membership & admin roles |
| `Expense` | `expenses` | `id`, `groupId`, `title`, `amount`, `paidById`, `splitType` | Shared group expenses |
| `ExpenseParticipant` | `expense_participants` | `id`, `expenseId`, `userId`, `share`, `percentage` | Per-user share allocation |
| `Settlement` | `settlements` | `id`, `groupId`, `payerId`, `payeeId`, `amount`, `paymentMethod` | Debt settlement logs |
| `Activity` | `activities` | `id`, `groupId`, `userId`, `type`, `expenseId`, `settlementId` | Group activity audit feed |
| `GroupInvite` | `group_invites` | `id`, `code`, `groupId`, `expiresAt`, `maxUses` | Group invite code generator |
| `Transaction` | `transactions` | `id`, `userId`, `amount`, `type`, `categoryKey`, `date` | Personal income/expense logs |
| `Budget` | `budgets` | `id`, `userId`, `title`, `amount`, `categoryIds`, `period` | Multi-period user budgets |

### Local Hive Boxes (`lib/data/services/hive_service.dart`)

- **`transactions_v1`**: Local personal transaction records (keyed by UUID).
- **`settings_v1`**: App preferences (`isDarkMode`, `currency`, `onboardingCompleted`, `biometricsEnabled`).
- **`budgets_v1`**: Cached active and archived user budgets.
- **`groups_v1`**: Cached group metadata for offline viewing.

---

## 🤖 AI / LLM Extension Points

SplitPay is structured to integrate with upcoming AI models (e.g. Gemini API / Firebase AI Logic):

```
                   ┌──────────────────────────────────────┐
                   │    AI Assistant / Gemini Pipeline    │
                   └──────────────────┬───────────────────┘
                                      │
       ┌──────────────────────────────┼──────────────────────────────┐
       ▼                              ▼                              ▼
┌───────────────┐              ┌───────────────┐              ┌───────────────┐
│ Multimodal    │              │ Natural Lang. │              │ Generative    │
│ Receipt OCR   │              │ Intent Engine │              │ Financial Bot │
│ (Vision LLM)  │              │ (Text Prompt) │              │ (Insights)    │
└───────┬───────┘              └───────┬───────┘              └───────┬───────┘
        │                              │                              │
        ▼                              ▼                              ▼
`BillScannerService`         `AddTransactionSheet`         `AnalyticsScreen`
```

For complete integration guidelines, see [docs/AI_CONTEXT.md](./AI_CONTEXT.md).
