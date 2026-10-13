/// Form field validators for Rentify.
/// All validators return null on success, a string message on failure.
library;

class Validators {
  Validators._();

  // ── Generic required field ────────────────────────────────────────
  static String? required(String? v, {String fieldName = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  // ── Email ─────────────────────────────────────────────────────────
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final trimmed = v.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  // ── Password ──────────────────────────────────────────────────────
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  // ── Mobile number ─────────────────────────────────────────────────
  static String? mobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  // ── Positive monetary amount (₹) ─────────────────────────────────
  static String? positiveAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final cleaned = v.replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than zero';
    return null;
  }

  // ── Unit / Room ID ────────────────────────────────────────────────
  static String? unitId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Unit ID is required';
    if (v.trim().length < 1) return 'Enter a valid unit ID';
    if (v.trim().length > 50) return 'Unit ID is too long';
    return null;
  }

  // ── Date (DD/MM/YYYY) ─────────────────────────────────────────────
  static String? date(String? v) {
    if (v == null || v.trim().isEmpty) return 'Date is required';
    final parts = v.split('/');
    if (parts.length != 3) return 'Enter a valid date (DD/MM/YYYY)';
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return 'Enter a valid date';
    }
    if (month < 1 || month > 12) return 'Invalid month';
    if (day < 1 || day > 31) return 'Invalid day';
    if (year < 2000 || year > 2100) return 'Invalid year';
    return null;
  }

  // ── Meter reading ─────────────────────────────────────────────────
  /// [previousReading] is the last accepted reading. Current must be ≥ previous.
  static String? meterReading(String? v, {double? previousReading}) {
    if (v == null || v.trim().isEmpty) return 'Current reading is required';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid meter reading';
    if (parsed < 0) return 'Reading cannot be negative';
    if (previousReading != null && parsed < previousReading) {
      return 'Reading must be ≥ previous reading (${previousReading.toStringAsFixed(1)})';
    }
    return null;
  }

  // ── Reference / UPI ID ────────────────────────────────────────────
  static String? reference(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    if (v.trim().length > 100) return 'Reference is too long';
    return null;
  }

  // ── Name ──────────────────────────────────────────────────────────
  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    if (v.trim().length > 100) return 'Name is too long';
    return null;
  }
}
