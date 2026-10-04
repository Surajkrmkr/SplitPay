import AppIntents
import Foundation

@available(iOS 16.0, *)
struct AddExpenseShortcutIntent: AppIntent {
  static let title: LocalizedStringResource = "Add New Expense"
  static let description = IntentDescription("Quickly add a personal expense in SplitPay.")
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    guard let defaults = UserDefaults(suiteName: "group.com.splitpay.expensetracker") else {
      throw ShortcutError.sharedStorageUnavailable
    }
    defaults.set("add-expense", forKey: "pendingAppShortcut")
    return .result()
  }
}

@available(iOS 16.0, *)
struct AddGroupExpenseShortcutIntent: AppIntent {
  static let title: LocalizedStringResource = "Add New Group Expense"
  static let description = IntentDescription("Choose a group and split a new expense in SplitPay.")
  static let openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    guard let defaults = UserDefaults(suiteName: "group.com.splitpay.expensetracker") else {
      throw ShortcutError.sharedStorageUnavailable
    }
    defaults.set("add-group-expense", forKey: "pendingAppShortcut")
    return .result()
  }
}

private enum ShortcutError: Error {
  case sharedStorageUnavailable
}

@available(iOS 16.0, *)
struct SplitPayAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddExpenseShortcutIntent(),
      phrases: [
        "Add a new expense in \(.applicationName)",
        "Add an expense with \(.applicationName)",
      ],
      shortTitle: "Add New Expense",
      systemImageName: "plus.circle"
    )
    AppShortcut(
      intent: AddGroupExpenseShortcutIntent(),
      phrases: [
        "Add a group expense in \(.applicationName)",
        "Split an expense with \(.applicationName)",
      ],
      shortTitle: "Add New Group Expense",
      systemImageName: "person.2"
    )
  }
}
