import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Advance & Security Deposit Ledger', () {
    test('calculates running advance balance from append-only transactions', () {
      final transactions = [
        {'type': 'received', 'amount_paise': 2000000}, // +₹20,000
        {'type': 'applied', 'amount_paise': -500000},  // -₹5,000
        {'type': 'refunded', 'amount_paise': -1000000},// -₹10,000
      ];

      final int balancePaise = transactions.fold<int>(
        0,
        (sum, txn) => sum + (txn['amount_paise'] as int),
      );

      expect(balancePaise, 500000); // Remaining ₹5,000
    });

    test('advance cannot be applied in excess of available deposit', () {
      const int currentBalancePaise = 500000;  // ₹5,000 available
      const int chargeDuePaise = 700000;       // ₹7,000 due
      const int requestedAdvancePaise = 600000;// Attempt to use ₹6,000

      final bool canApply = requestedAdvancePaise <= currentBalancePaise &&
          requestedAdvancePaise <= chargeDuePaise;

      expect(canApply, isFalse);
    });
  });
}
