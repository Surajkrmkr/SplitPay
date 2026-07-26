import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String symbol = '₹'}) {
    final formatter = NumberFormat.currency(
      locale: symbol == '₹' ? 'en_IN' : 'en_US',
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatWithCommas(double amount, {String symbol = '₹', int decimalDigits = 0}) {
    final locale = symbol == '₹' ? 'en_IN' : 'en_US';
    final pattern = decimalDigits > 0
        ? (symbol == '₹' ? '#,##,##0.${'0' * decimalDigits}' : '#,##0.${'0' * decimalDigits}')
        : (symbol == '₹' ? '#,##,##0' : '#,##0');
    final formatter = NumberFormat(pattern, locale);
    return '$symbol${formatter.format(amount)}';
  }

  static String formatAmountWithCommas(
    double amount, {
    String symbol = '',
    int decimalDigits = 2,
  }) {
    final absAmount = amount.abs();
    final pattern = decimalDigits > 0
        ? '#,##,##0.${'0' * decimalDigits}'
        : '#,##,##0';
    final formatter = NumberFormat(pattern, 'en_IN');
    final formatted = formatter.format(absAmount);
    final sign = amount < 0 ? '-' : '';
    return symbol.isEmpty ? '$sign$formatted' : '$sign$symbol$formatted';
  }

  static String formatCompact(double amount, {String symbol = '₹'}) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return formatWithCommas(amount, symbol: symbol);
  }

  static String formatAmount(double amount) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(amount);
  }

  static const Map<String, String> currencies = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'INR': '₹',
    'CAD': 'CA\$',
    'AUD': 'A\$',
  };
}

