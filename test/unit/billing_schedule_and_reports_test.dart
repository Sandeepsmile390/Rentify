import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Billing Schedule & Canonical Month Logic', () {
    test('canonical billing month is always YYYY-MM-01 format', () {
      final date = DateTime(2026, 2, 28);
      final canonical = '${date.year}-${date.month.toString().padLeft(2, '0')}-01';
      expect(canonical, '2026-02-01');
    });

    test('short month day-of-month clamp logic clamps day 31 in February', () {
      int getScheduledExecutionDay(int year, int month, int targetDay) {
        // days in month
        final lastDay = DateTime(year, month + 1, 0).day;
        return targetDay > lastDay ? lastDay : targetDay;
      }

      // In non-leap year (e.g. 2025 Feb has 28 days)
      expect(getScheduledExecutionDay(2025, 2, 31), 28);
      // In leap year (2024 Feb has 29 days)
      expect(getScheduledExecutionDay(2024, 2, 31), 29);
      // In April (30 days)
      expect(getScheduledExecutionDay(2026, 4, 31), 30);
      // In May (31 days)
      expect(getScheduledExecutionDay(2026, 5, 31), 31);
    });

    test('month report boundary is inclusive start and exclusive next month', () {
      const selectedMonth = '2026-09-01';
      final start = DateTime.parse(selectedMonth);
      final end = DateTime(start.year, start.month + 1, 1);

      expect(start.toIso8601String().startsWith('2026-09-01'), isTrue);
      expect(end.toIso8601String().startsWith('2026-10-01'), isTrue);
    });
  });
}
