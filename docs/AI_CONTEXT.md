# SplitPay — AI Integration & Context Guide

This document serves as a structured reference guide for **AI Coding Assistants**, **LLM Agents**, and **Autonomous Subagents** developing upcoming AI features for the **SplitPay** platform.

---

## 🎯 Purpose & AI Vision

SplitPay is designed to evolve into an **AI-first personal and group financial assistant**. The system currently features on-device ML Kit OCR receipt scanning and SMS text parsing. Upcoming AI features will leverage multimodal vision models (e.g. Gemini 1.5 Flash), Natural Language Processing (NLP) prompt interpretation, and generative financial insights.

---

## 🗺 Codebase Context Map for AI Agents

When implementing or extending features, refer to these authoritative source locations:

| Subsystem / Feature Area | Key Source Files | Description |
|---|---|---|
| **Personal Transactions** | [transaction_model.dart](../lib/data/models/transaction_model.dart)<br>[transaction_provider.dart](../lib/providers/transaction_provider.dart)<br>[add_transaction_sheet.dart](../lib/features/add_transaction/add_transaction_sheet.dart) | Personal income/expense models, Riverpod state notifier, and entry modal sheet. |
| **Group Expenses & Debt** | [group_model.dart](../lib/data/models/group_model.dart)<br>[group_expense_model.dart](../lib/data/models/group_expense_model.dart)<br>[group_provider.dart](../lib/providers/group_provider.dart)<br>[settlement_model.dart](../lib/data/models/settlement_model.dart) | Group structures, expense split types (Equal, Percentage, Exact), debt simplification algorithm, and settlements. |
| **Budget System** | [budget_model.dart](../lib/data/models/budget_model.dart)<br>[budget_provider.dart](../lib/providers/budget_provider.dart)<br>[budget_screen.dart](../lib/features/budget/budget_screen.dart) | Multi-period budgets (Daily, Weekly, Monthly, Yearly), alert thresholds, and remaining calculations. |
| **OCR & SMS Services** | [bill_scanner_service.dart](../lib/data/services/bill_scanner_service.dart)<br>[sms_parser_service.dart](../lib/data/services/sms_parser_service.dart) | Text recognition using Google ML Kit and regex SMS financial extraction engine. |
| **Backend REST Server** | [schema.prisma](../server/prisma/schema.prisma)<br>[app.ts](../server/src/app.ts)<br>[server modules](../server/src/modules/) | Node.js / Express server modules for auth, groups, expenses, budgets, and PostgreSQL ORM. |

---

## 🗄 Core Data Schemas

### 1. Personal Transaction (`lib/data/models/transaction_model.dart`)
```dart
class Transaction {
  final String id;
  final double amount;
  final TransactionType type; // income, expense, transfer
  final Category category;
  final String? customCategoryId;
  final String? appIcon; // e.g. 'zomato', 'swiggy', 'swish'
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final String? groupId;
}
```

### 2. Group Expense (`lib/data/models/group_expense_model.dart`)
```dart
enum SplitType { equal, percentage, exact }

class GroupExpense {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidById;
  final SplitType splitType;
  final List<ExpenseParticipant> participants;
  final DateTime date;
  final String? notes;
}
```

### 3. Budget (`lib/data/models/budget_model.dart`)
```dart
enum BudgetPeriod { daily, weekly, monthly, yearly }

class Budget {
  final String id;
  final String title;
  final double amount;
  final List<String> categoryIds;
  final BudgetPeriod period;
  final DateTime startDate;
  final double alertThreshold; // Default 0.8 (80%)
  final bool isArchived;
}
```

---

## 🤖 Upcoming AI Features & Architecture Blueprint

### 1. Multimodal Gemini Bill & Receipt Itemizer
- **Target Location:** `lib/data/services/gemini_receipt_service.dart` (To be created)
- **Goal:** Replace/enhance `BillScannerService` by passing receipt image bytes to Gemini Vision API (`@google/genai` or Firebase AI Logic SDK).
- **Expected JSON Output Schema:**
```json
{
  "merchant": "Supermarket Target",
  "totalAmount": 45.90,
  "date": "2026-07-26",
  "items": [
    { "name": "Milk 1L", "price": 3.50, "quantity": 2 },
    { "name": "Organic Bread", "price": 4.90, "quantity": 1 },
    { "name": "Chicken Breast 1kg", "price": 14.00, "quantity": 1 }
  ],
  "tax": 3.40,
  "suggestedCategory": "groceries"
}
```
- **UI Integration Point:** Wire into `AddGroupExpenseSheet` to allow users to assign individual receipt line items to different group participants automatically.

---

### 2. Natural Language Expense Prompt Parser
- **Target Location:** `lib/providers/ai_expense_parser_provider.dart` (To be created)
- **Goal:** Interpret natural language text or voice transcripts into structured transaction payloads.
- **Example Prompts:**
  - *"Paid $60 for sushi with Piyush yesterday, I paid full"* $\rightarrow$ Creates `GroupExpense` (Title: "Sushi", Amount: 60.0, PaidBy: CurrentUser, SplitType: Equal, Participants: [CurrentUser, Piyush]).
  - *"Uber ride to airport $35"* $\rightarrow$ Creates personal `Transaction` (Category: Transport, Amount: 35.0, Note: "Uber ride to airport").
- **Implementation Strategy:**
  Use structured JSON output prompt templates with a small, fast model (e.g. `gemini-1.5-flash`).

---

### 3. Conversational AI Financial Advisor & Insights
- **Target Location:** `lib/features/analytics/widgets/ai_financial_insights_card.dart`
- **Goal:** Analyze current month spending data (`transactionProvider` & `budgetProvider` state) and generate personalized financial advice.
- **Input Data Payload to LLM:**
```json
{
  "currentMonthSpend": 1250.00,
  "previousMonthSpend": 980.00,
  "topCategories": [
    { "category": "food", "amount": 540.00, "percentage": 43.2 },
    { "category": "shopping", "amount": 310.00, "percentage": 24.8 }
  ],
  "budgetStatus": [
    { "title": "Food Budget", "limit": 500.00, "spent": 540.00, "overBudget": true }
  ]
}
```
- **Generated Output:** Concise, actionable 2-sentence financial tips rendered in a glassmorphism widget on the Analytics screen.

---

### 4. Smart Debt Settlement Optimization
- **Target Location:** `lib/providers/group_provider.dart`
- **Goal:** Combine debt simplification math with user payment behavior insights to recommend optimal settlement orders (e.g. prioritizing participants with active UPI handles or largest net debts).

---

## 🛠 Guidelines for AI Subagents Modifying SplitPay

1. **State Management:** Always use Riverpod `ref.read` inside callbacks and `ref.watch` inside `build()` methods. Do not introduce legacy `ScopedModel` or `StatefulWidget` boilerplate for shared global state.
2. **Offline-First Resilience:** Ensure all newly created data objects (transactions, expenses, budgets) are saved to Hive local box storage before firing backend API sync network calls.
3. **Form & Validation:** Use standard Material form validation and `TextEditingController` disposal patterns.
4. **Theme Tokens:** Always extract colors from `AppColors` (`lib/core/constants/app_colors.dart`) or `Theme.of(context)` to preserve dark/light mode compatibility.
5. **No Breaking Schema Changes:** When expanding models, add optional nullable fields or defaults to preserve backward compatibility with existing Hive box data (`_v1`).
