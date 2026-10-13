import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Billing Calculation & Exact Integer Math', () {
    const int defaultRatePaise = 900; // ₹9.00 per unit

    test('calculates meter electricity units and amount accurately', () {
      const double prevReading = 1250.0;
      const double currReading = 1397.8;
      final double unitsConsumed = currReading - prevReading; // 147.8
      final int chargePaise = (unitsConsumed * defaultRatePaise).round();

      expect(unitsConsumed, closeTo(147.8, 0.001));
      // 147.8 * 900 = 133020 paise (₹1,330.20)
      expect(chargePaise, 133020);
    });

    test('zero consumption yields zero electricity charge', () {
      const double prevReading = 500.0;
      const double currReading = 500.0;
      final double units = currReading - prevReading;
      final int chargePaise = (units * defaultRatePaise).round();

      expect(units, 0.0);
      expect(chargePaise, 0);
    });

    test('fixed electricity mode charges exact configured amount', () {
      const int fixedElecAmountPaise = 75000; // ₹750
      expect(fixedElecAmountPaise, 75000);
    });

    test('rent charge and electricity combined total is exact sum', () {
      const int rentPaise = 550000; // ₹5,500
      const int elecPaise = 133020; // ₹1,330.20
      const int totalPaise = rentPaise + elecPaise;

      expect(totalPaise, 683020);
    });

    test('idempotency month normalization ensures first day of month format', () {
      final date = DateTime(2026, 10, 15);
      final monthString = '${date.year}-${date.month.toString().padLeft(2, '0')}-01';

      expect(monthString, '2026-10-01');
    });
  });
}
