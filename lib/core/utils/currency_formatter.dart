import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Converts minor units (integer cents/paisas) to standard major amount (double).
  /// E.g. 2500000 -> 25000.0
  static double minorToAmount(int minorUnits) {
    return minorUnits / 100.0;
  }

  /// Converts standard major amount to minor units (integer).
  /// E.g. 25000.0 -> 2500000
  static int amountToMinor(double amount) {
    return (amount * 100).round();
  }

  /// Formats minor units into a clean currency string.
  /// E.g. 2500000 minor units with '₨' -> '₨ 25,000' (or '₨ 25,000.50' if non-zero decimal)
  static String formatMinor(
    int minorUnits, {
    String symbol = '₨',
    bool forceDecimals = false,
  }) {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final major = absolute ~/ 100;
    final cents = absolute % 100;
    final grouped = NumberFormat.decimalPattern('en_US').format(major);
    final decimals = forceDecimals || cents != 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
    return '${negative ? '-' : ''}$symbol $grouped$decimals';
  }

  /// Formats a double amount into a formatted currency string.
  static String formatAmount(
    double amount, {
    String symbol = '₨',
    bool forceDecimals = false,
  }) {
    final NumberFormat formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: forceDecimals || (amount % 1 != 0) ? 2 : 0,
    );
    return formatter.format(amount).trim();
  }

  /// Parses input text into integer minor units safely.
  /// Returns null if invalid.
  static int? parseToMinor(String text) {
    final cleanText = text.replaceAll(',', '').replaceAll(' ', '').trim();
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(cleanText)) return null;
    final negative = cleanText.startsWith('-');
    final unsigned = negative ? cleanText.substring(1) : cleanText;
    final parts = unsigned.split('.');
    final major = int.tryParse(parts[0]);
    if (major == null) return null;
    final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    final result = major * 100 + cents;
    return negative ? -result : result;
  }
}
