import 'package:intl/intl.dart';

/// Currency formatting utilities.
/// All amounts are stored as integer paise (1 INR = 100 paise).
/// NEVER use floating-point arithmetic for monetary calculations.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _rupeeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _rupeeFormatDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Format paise as a ₹ string with Indian number grouping.
  /// Example: 550000 → "₹5,500"
  /// Example: 10000000 → "₹1,00,000"
  static String fromPaise(int paise) {
    // Avoid float arithmetic: divide using integer math
    final rupees = paise ~/ 100;
    final paiseRemainder = paise % 100;

    if (paiseRemainder == 0) {
      return _rupeeFormat.format(rupees);
    }
    // Show decimals only if there's a remainder
    final value = rupees + (paiseRemainder / 100.0);
    return _rupeeFormatDecimal.format(value);
  }

  /// Parse a user-entered rupee string to integer paise.
  /// Accepts: "5500", "5,500", "5500.50"
  /// Returns null if the string is invalid or non-positive.
  static int? toPaise(String input) {
    if (input.trim().isEmpty) return null;
    final cleaned = input.trim().replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed < 0) return null;
    // Round to avoid floating-point errors when multiplying by 100
    final paise = (parsed * 100).round();
    return paise;
  }

  /// Format paise with a +/- sign prefix.
  /// Positive → "+₹5,500", Negative → "-₹5,500"
  static String signed(int paise) {
    final prefix = paise >= 0 ? '+' : '-';
    return '$prefix${fromPaise(paise.abs())}';
  }

  /// Format paise as a plain rupee amount string (no symbol).
  static String rupeesOnly(int paise) {
    final rupees = paise ~/ 100;
    return NumberFormat('#,##,###', 'en_IN').format(rupees);
  }
}
