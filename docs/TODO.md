# SplitPay — Development Roadmap & TODO

> Status Key: `[x]` Completed · `[~]` In Progress · `[ ]` Planned · `[!]` Blocked

---

## 🟢 Completed in v1.0.7+8

- [x] **Group Expense Splitting** — Groups, equal/percentage/exact splits, member balances, activity feed
- [x] **Debt Simplification Engine** — Minimal transaction matrix algorithm
- [x] **UPI Payment Settlement** — Launch native GPay / PhonePe / Paytm / BHIM via `upi_intent`
- [x] **Multi-Period Budgets** — Daily, Weekly, Monthly, Yearly budgets with category associations & threshold alerts
- [x] **Smart OCR Receipt Scanner** — Google ML Kit Text Recognition for total & vendor extraction
- [x] **SMS Parser Service** — Extract bank transaction alerts into autofilled transaction drafts
- [x] **Firebase Authentication** — Google Sign-In, Email/Password, and Guest access
- [x] **Node.js / Express Backend Server** — Prisma ORM + PostgreSQL REST API in `server/`
- [x] **Biometric Security** — Face ID / Touch ID / Fingerprint lock using `local_auth`
- [x] **CSV Data Import & Export** — Download & upload CSV backups using `file_picker` + `csv`
- [x] **FCM Push Notifications** — Real-time group activity & settlement notifications

---

## 🤖 Priority 1 — Upcoming AI & LLM Features (Context Ready)

- [ ] **Multimodal Gemini Bill OCR Parser:**
  - Send receipt photos to Gemini 1.5 Flash via Firebase AI Logic / REST API.
  - Extract itemized product lists with quantities, individual prices, and tax breakdown.
  - Auto-assign items to specific group participants in shared expenses.

- [ ] **Natural Language Expense Ingestion:**
  - Voice & Text prompt parser: *"I paid $42 for dinner with Piyush and Rahul at Olive Garden"*.
  - Convert prompt into pre-filled `AddGroupExpenseSheet` with auto-matched participants and category.

- [ ] **Smart Financial Advisory Assistant:**
  - AI chat screen under Analytics providing spending velocity analysis (*"You're spending 28% faster on food this month"*).
  - Intelligent budget recommendations based on past 3-month spending trends.

- [ ] **On-Device Anomaly & Duplicate Detection:**
  - Highlight potential duplicate debits or unusually large transactions.

---

## 🟠 Priority 2 — Analytics & UX Polish

- [ ] **Hero Transitions:** Animate category icons from transaction tiles to detail view.
- [ ] **Income vs Expense Bar Chart:** Side-by-side bar chart comparison per month.
- [ ] **Calendar Heatmap:** Contribution-style spending intensity grid.
- [ ] **PDF Statement Generator:** Export monthly financial statements using `pdf` + `printing`.
- [ ] **iPad / Tablet Layout:** Adaptive multi-column layout for large screens.

---

## 🔵 Priority 3 — Platform & Monetization

- [ ] **Google Mobile Ads Integration:** Activate production AdMob IDs in ready `ad_placeholder.dart` slots.
- [ ] **In-App Purchases (IAP):** Premium tier for unlimited groups, automated cloud sync, and advanced AI features.
- [ ] **iOS & Android Widgets:** Home screen widget displaying current monthly balance and budget progress bars.
