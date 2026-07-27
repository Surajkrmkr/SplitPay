# SplitPay — Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.7+8] — 2026-07-26 — Major Features & Backend Release

### 🚀 Added
- **Group Expense Splitting & Debt Simplification:**
  - Full Group management module (`lib/features/groups/`).
  - Equal, Percentage, and Exact split modes.
  - Automated debt simplification engine reducing $N$ member balances to minimal transactions.
  - Group activity audit feed tracking edits, deletions, and settlements.
  - Invite code and QR code scanner integration (`mobile_scanner`).

- **UPI Debt Settlement Integration:**
  - 1-tap debt settlement via native UPI apps (`upi_intent` package) including Google Pay, PhonePe, Paytm, and BHIM.
  - Manual settlement recording for offline/cash payments.

- **Multi-Period Budget Management:**
  - Multi-period budget tracking system (`lib/features/budget/`) supporting Daily, Weekly, Monthly, and Yearly periods.
  - Spent vs. remaining progress tracking with configurable alert thresholds (e.g. 80% warning color).
  - Budget archiving and history search.

- **Smart Bill Scanner (OCR) & SMS Parser:**
  - On-device text recognition with Google ML Kit (`google_mlkit_text_recognition`).
  - Automatic detection of total amounts and vendor names from receipt photos.
  - SMS parser service extracting debits, credits, and merchant names from bank notifications.

- **Authentication & Backend Integration:**
  - Firebase Authentication with Google Sign-In and Email/Password (`firebase_auth`, `google_sign_in`).
  - Node.js / Express REST API backend server with Prisma ORM and PostgreSQL database (`server/`).
  - Firebase ID Token verification middleware and session refresh token rotation.

- **Notifications & Biometrics:**
  - Firebase Cloud Messaging (`firebase_messaging`) for push notifications on group activity.
  - Scheduled daily local spending reminders (`flutter_local_notifications`).
  - Biometric Face ID / Touch ID / Fingerprint app lock screen (`local_auth`).

- **Data Import & Export:**
  - CSV transaction exporter and reverse-parsing CSV importer (`csv`, `file_picker`).

---

## [1.0.0] — 2026-05-15 — MVP Release

### Added
- **Onboarding & Home Dashboard:**
  - 3-page animated onboarding walkthrough with `SharedPreferences` persistence.
  - Time-aware greeting header, glassmorphism balance card, mini stats.
- **Personal Transactions:**
  - Add transaction modal bottom sheet.
  - 9 default categories with icons and colors.
  - History screen with filter tabs (All / Today / Week / Month), search, and swipe-to-delete.
- **Analytics & Settings:**
  - Interactive pie chart, weekly bar chart, 6-month trend line chart (`fl_chart`).
  - Dark / Light theme toggle persisted to Hive storage.
  - Currency selector (USD, EUR, GBP, JPY, INR, CAD, AUD).
