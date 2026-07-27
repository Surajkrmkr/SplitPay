# SplitPay — Feature Documentation & Implementation Reference

> Current Version: **1.0.7+8**
> Last Updated: July 2026

---

## Table of Contents
1. [Authentication & Onboarding](#1-authentication--onboarding)
2. [Home Dashboard](#2-home-dashboard)
3. [Personal Expense Tracking & Custom Categories](#3-personal-expense-tracking--custom-categories)
4. [Smart Bill Scanner (OCR) & SMS Parser](#4-smart-bill-scanner-ocr--sms-parser)
5. [Group Bill Splitting & Shared Expenses](#5-group-bill-splitting--shared-expenses)
6. [Debt Settlements & UPI Payment Integration](#6-debt-settlements--upi-payment-integration)
7. [Multi-Period Budgeting & Threshold Alerts](#7-multi-period-budgeting--threshold-alerts)
8. [Transaction History, Search & Filtering](#8-transaction-history-search--filtering)
9. [Analytics & Data Visualization](#9-analytics--data-visualization)
10. [Notifications & Daily Reminders](#10-notifications--daily-reminders)
11. [CSV Data Import/Export & Biometrics](#11-csv-data-importexport--biometrics)
12. [Node.js / Prisma Backend Server API](#12-nodejs--prisma-backend-server-api)

---

## 1. Authentication & Onboarding

### Files:
- `lib/features/auth/splash_screen.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/providers/auth_provider.dart`
- `lib/data/services/firebase_auth_service.dart`

### Key Capabilities:
- **Splash Screen:** Checks Firebase authentication status and `onboarding_completed` preference. Animates SplitPay logo with smooth entrance.
- **Firebase Auth:** Supports Google Sign-In via `google_sign_in` SDK and Email/Password sign-in. Syncs user profile with the Node.js backend to retrieve session tokens.
- **Guest / Offline Mode:** Allows instant entry as a local offline user without signing in.
- **Onboarding Carousel:** 3-page interactive onboarding introducing key concepts (*Track Expenses*, *Split with Friends*, *Master Your Budget*).

---

## 2. Home Dashboard

### Files:
- `lib/features/home/home_screen.dart`
- `lib/features/home/widgets/greeting_header.dart`
- `lib/features/home/widgets/balance_card.dart`
- `lib/features/home/widgets/category_overview.dart`
- `lib/features/home/widgets/recent_transactions.dart`

### Key Capabilities:
- **Time-Aware Header:** Greeting adjusts dynamically (*Good Morning*, *Good Afternoon*, *Good Evening*) with user profile avatar and notification badge indicator.
- **Glassmorphism Balance Card:** Displays current month total balance with animated number counter, monthly percentage change badge (*"183% higher than last month"*), and mini income/expense counters.
- **Group Split Promo Banner:** Quick access banner navigating directly to the Groups tab (`/groups`).
- **Recent Activity Feed:** Displays the 5 latest personal transactions with merchant icons, date headers, and colored expense/income tags.

---

## 3. Personal Expense Tracking & Custom Categories

### Files:
- `lib/features/add_transaction/add_transaction_sheet.dart`
- `lib/data/models/transaction_model.dart`
- `lib/data/models/custom_category.dart`
- `lib/providers/transaction_provider.dart`

### Key Capabilities:
- **Add Expense Modal Sheet:** Modal bottom sheet accessible via the center Floating Action Button (FAB) or quick action buttons.
- **Type Selector:** Toggle between Income, Expense, and Transfer modes.
- **App Icons & Brands:** Pre-built brand shortcuts (e.g. Zomato, Swiggy, Swish, Blinkit, Zepto) for instant visual identifier assignment.
- **Categories Grid:** 15+ default categories (Food, Shopping, Bills, Travel, Salary, Entertainment, Subscriptions, Rent, etc.) plus custom user-created categories with icon and color customization.

---

## 4. Smart Bill Scanner (OCR) & SMS Parser

### Files:
- `lib/data/services/bill_scanner_service.dart`
- `lib/data/services/sms_parser_service.dart`

### Key Capabilities:
- **ML Kit Bill Scanner:** Uses `google_mlkit_text_recognition` to scan camera images or receipts. Extracts total currency values (e.g., `₹354.00`) and vendor headers automatically.
- **SMS Transaction Parser:** Regex parsing engine that extracts debit/credit amounts, dates, and vendor names from bank SMS text, providing a 1-tap *"Autofill from bill or SMS"* button on the add expense sheet.

---

## 5. Group Bill Splitting & Shared Expenses

### Files:
- `lib/features/groups/groups_screen.dart`
- `lib/features/groups/group_detail/group_detail_screen.dart`
- `lib/features/groups/add_expense/add_group_expense_sheet.dart`
- `lib/features/groups/invite/invite_screen.dart`
- `lib/features/groups/qr_scanner_screen.dart`
- `lib/data/models/group_model.dart`
- `lib/data/models/group_expense_model.dart`
- `lib/providers/group_provider.dart`

### Key Capabilities:
- **Group Dashboard:** Lists all active groups with overall summary cards (*"You're owed ₹2,857.72"*, *"You owe ₹3,700.00"*, *"Net balance -₹842.28"*).
- **Group Detail Tabs:**
  1. **Balances:** Debt simplification view (*"Suraj owes You ₹66.66"*), total lent/borrowed cards, and recent settlement logs.
  2. **Expenses:** Paginated list of shared group expenses with badges (*"you paid"*, *"owe ₹3,333.33"*).
  3. **Activity:** Real-time event log tracking expense creations, edits, deletions, and settlements.
  4. **Total & Analytics:** Group total expense header, member breakdown with net balance pills, and monthly spend charts.
- **Split Modes:** Supports **Equal**, **Percentage**, and **Exact Amount** split modes among selected group participants.
- **Invites & QR Code:** Join groups via 6-digit invite code or built-in mobile scanner QR code (`mobile_scanner`).

---

## 6. Debt Settlements & UPI Payment Integration

### Files:
- `lib/features/groups/settle_up/settle_up_dialog.dart`
- `lib/data/services/upi_service.dart`
- `lib/data/repositories/payment_repository.dart`
- `lib/data/models/settlement_model.dart`

### Key Capabilities:
- **1-Tap Settle Up Dialog:** Pre-fills payer, payee, and calculated debt amount.
- **UPI Intent Launching:** Seamless integration with `upi_intent` package. Allows direct launching of installed UPI apps (Google Pay, PhonePe, Paytm, BHIM) with pre-filled VPA and amount.
- **Manual Settlement Recording:** Mark debts as settled manually for cash or external bank transfers.

---

## 7. Multi-Period Budgeting & Threshold Alerts

### Files:
- `lib/features/budget/budget_screen.dart`
- `lib/features/budget/add_budget_sheet.dart`
- `lib/features/budget/budget_detail_screen.dart`
- `lib/data/models/budget_model.dart`
- `lib/providers/budget_provider.dart`

### Key Capabilities:
- **Total Budget Overview:** Glass card displaying total active budget, total spent, remaining balance, and % used progress bar.
- **Period Filtering:** Create and filter budgets by **Daily**, **Weekly**, **Monthly**, or **Yearly** periods.
- **Category Association:** Link a budget to single or multiple expense categories.
- **Threshold Warnings:** Color-coded alert bars turning red when spending exceeds the configured threshold (default 80%).
- **Archiving System:** Move completed or inactive budgets into the Archived tab.

---

## 8. Transaction History, Search & Filtering

### Files:
- `lib/features/transactions/transactions_screen.dart`
- `lib/features/transactions/widgets/transaction_tile.dart`
- `lib/features/transactions/widgets/transaction_filter_sheet.dart`

### Key Capabilities:
- **Live Search Bar:** Real-time search by category title, note, or merchant name.
- **Date Bucketing:** Automatically groups transactions by *"Today"*, *"Yesterday"*, or formatted date headers.
- **Filter & Sort Modal:** Bottom sheet offering:
  - **Sort Options:** Newest first, Oldest first, Highest amount, Lowest amount.
  - **Type Filter:** All, Income, Expense, Transfer.
  - **Multi-Category Selection Grid:** Select specific categories to isolate spending.
- **Swipe to Delete:** `Dismissible` widget for quick item deletion.

---

## 9. Analytics & Data Visualization

### Files:
- `lib/features/analytics/analytics_screen.dart`
- `lib/features/analytics/widgets/spending_pie_chart.dart`
- `lib/features/analytics/widgets/weekly_bar_chart.dart`
- `lib/features/analytics/widgets/monthly_trend.dart`

### Key Capabilities:
- **Interactive Pie Chart:** Spending breakdown by category using `fl_chart`. Touch interaction expands selected slice and displays legend details.
- **Weekly Spending Bar Chart:** 7-day bar chart highlighting today's spending bar in primary emerald.
- **6-Month Trend Line Chart:** Curved line chart showing monthly expense trends with gradient fill.
- **Key Financial Ratios:** Displays Savings Rate percentage, Average Daily Spend, and Total Transaction Count.

---

## 10. Notifications & Daily Reminders

### Files:
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/settings/notification_settings_screen.dart`
- `lib/data/services/notification_service.dart`
- `lib/data/services/reminder_service.dart`
- `lib/providers/notification_provider.dart`

### Key Capabilities:
- **In-App Activity Feed:** Filterable notifications list (*All*, *Unread*, *Groups*, *Reminders*).
- **Push Notifications (FCM):** Integration with `firebase_messaging` for real-time alerts when group expenses or settlements are added.
- **Scheduled Local Reminders:** `flutter_local_notifications` setup for daily spending log reminders at user-defined times.

---

## 11. CSV Data Import/Export & Biometrics

### Files:
- `lib/features/settings/settings_screen.dart`
- `lib/features/settings/import_data_screen.dart`
- `lib/data/services/biometric_service.dart`
- `lib/data/services/transaction_import_service.dart`

### Key Capabilities:
- **CSV Data Export:** Generate downloadable `.csv` file containing all personal transactions.
- **CSV Data Import:** Reverse-parse imported CSV files (`file_picker` + `csv` package) with field mapping validation.
- **Biometric Security:** Enable native Face ID / Touch ID lock screen on app resume using `local_auth`.

---

## 12. Node.js / Prisma Backend Server API

### Files:
- `server/src/app.ts`
- `server/src/modules/auth/`
- `server/src/modules/groups/`
- `server/src/modules/expenses/`
- `server/src/modules/settlements/`
- `server/src/modules/budgets/`
- `server/prisma/schema.prisma`

### API Endpoints Summary:

| Module | Route | Method | Description |
|---|---|---|---|
| Auth | `/api/v1/auth/google` | `POST` | Authenticate with Firebase Google token |
| Auth | `/api/v1/auth/session` | `POST` | Exchange refresh token for access token |
| Groups | `/api/v1/groups` | `GET / POST` | Fetch user groups / Create new group |
| Groups | `/api/v1/groups/:id` | `GET / PUT / DELETE` | Group details & admin operations |
| Groups | `/api/v1/groups/:id/join` | `POST` | Join group via invite code |
| Expenses | `/api/v1/groups/:id/expenses` | `GET / POST` | Fetch group expenses / Add new split expense |
| Settlements | `/api/v1/groups/:id/settlements` | `POST` | Record debt settlement transaction |
| Budgets | `/api/v1/budgets` | `GET / POST` | Fetch / Create user budgets |
| Transactions | `/api/v1/transactions` | `GET / POST` | Sync personal transactions with cloud |
