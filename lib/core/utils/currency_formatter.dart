import 'package:flutter/services.dart';
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

/// A TextInputFormatter that formats numbers with commas as the user types
/// (e.g. 1000 -> 1,000, 100000 -> 1,00,000).
class CurrencyInputFormatter extends TextInputFormatter {
  final bool isIndianFormat;

  CurrencyInputFormatter({this.isIndianFormat = true});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final cleanText = newValue.text.replaceAll(',', '');

    final parts = cleanText.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    if (parts.length == 2 && parts[1].length > 2) {
      return oldValue;
    }

    final integerStr = parts[0];
    final doubleVal = double.tryParse(integerStr);
    if (integerStr.isNotEmpty && doubleVal == null) {
      return oldValue;
    }

    String formattedInt = '';
    if (integerStr.isNotEmpty && doubleVal != null) {
      final formatter = NumberFormat(
        isIndianFormat ? '#,##,##0' : '#,##0',
        isIndianFormat ? 'en_IN' : 'en_US',
      );
      formattedInt = formatter.format(doubleVal);
    }

    final newText = parts.length == 2
        ? '$formattedInt.${parts[1]}'
        : formattedInt;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

