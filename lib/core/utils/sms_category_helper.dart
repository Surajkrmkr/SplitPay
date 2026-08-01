import '../../data/models/transaction_model.dart';

/// Helper to auto-suggest an appropriate [Category] based on merchant name,
/// sender ID, or SMS text body keywords.
class SmsCategoryHelper {
  static Category suggestCategory({
    required String title,
    required String sender,
    required String body,
    required TransactionType type,
  }) {
    if (type == TransactionType.income) {
      final combined = '$title $sender $body'.toLowerCase();
      if (combined.contains('salary') ||
          combined.contains('payroll') ||
          combined.contains('stipend') ||
          combined.contains('dividend')) {
        return Category.salary;
      }
      return Category.other;
    }

    final text = '$title $sender $body'.toLowerCase();

    // Food & Dining
    if (_hasAny(text, [
      'swiggy',
      'zomato',
      'mcdonald',
      'domino',
      'starbucks',
      'kfc',
      'burger',
      'pizza',
      'cafe',
      'restaurant',
      'diner',
      'eats',
      'bakery',
      'food',
      'bistro',
    ])) {
      return Category.food;
    }

    // Travel & Transit
    if (_hasAny(text, [
      'uber',
      'ola',
      'rapido',
      'irctc',
      'makemytrip',
      'goibibo',
      'redbus',
      'cleartrip',
      'flight',
      'airline',
      'fastag',
      'toll',
      'petrol',
      'diesel',
      'fuel',
      'metro',
      'cab',
      'taxi',
    ])) {
      return Category.travel;
    }

    // Shopping
    if (_hasAny(text, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'tatacliq',
      'nykaa',
      'meesho',
      'zudio',
      'dmart',
      'bazaar',
      'retail',
      'store',
      'mall',
      'supermarket',
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
    ])) {
      return Category.shopping;
    }

    // Bills & Utilities
    if (_hasAny(text, [
      'bescom',
      'electricity',
      'water bill',
      'gas bill',
      'broadband',
      'wifi',
      'airtel',
      'jio',
      'vodafone',
      'vi ',
      'recharge',
      'postpaid',
      'tata play',
      'dth',
      'credit card bill',
      'loan',
      'emi',
    ])) {
      return Category.bills;
    }

    // Subscriptions
    if (_hasAny(text, [
      'netflix',
      'spotify',
      'prime',
      'hotstar',
      'youtube',
      'apple.com',
      'google play',
      'icloud',
      'patreon',
      'subscription',
    ])) {
      return Category.subscription;
    }

    // Health & Wellness
    if (_hasAny(text, [
      'apollo',
      'pharmeasy',
      '1mg',
      'netmeds',
      'pharmacy',
      'chemist',
      'hospital',
      'clinic',
      'lab',
      'pathology',
      'doctor',
      'medicals',
    ])) {
      return Category.health;
    }

    // Entertainment
    if (_hasAny(text, [
      'bookmyshow',
      'pvr',
      'inox',
      'cinema',
      'movie',
      'gaming',
      'steam',
      'playstation',
    ])) {
      return Category.entertainment;
    }

    return Category.other;
  }

  static bool _hasAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
