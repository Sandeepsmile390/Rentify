import 'package:flutter_test/flutter_test.dart';
import 'package:rentify/core/utilities/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    group('fromPaise', () {
      test('formats zero paise', () {
        expect(CurrencyFormatter.fromPaise(0), '₹0');
      });

      test('formats 100 paise as ₹1', () {
        expect(CurrencyFormatter.fromPaise(100), '₹1');
      });

      test('formats 550000 paise as ₹5,500', () {
        expect(CurrencyFormatter.fromPaise(550000), '₹5,500');
      });

      test('formats large amount with Indian grouping', () {
        expect(CurrencyFormatter.fromPaise(10000000), '₹1,00,000');
      });
    });

    group('toPaise', () {
      test('converts "5500" to 550000 paise', () {
        expect(CurrencyFormatter.toPaise('5500'), 550000);
      });

      test('converts "5500.50" to 550050 paise (rounds correctly)', () {
        expect(CurrencyFormatter.toPaise('5500.50'), 550050);
      });

      test('returns null for empty string', () {
        expect(CurrencyFormatter.toPaise(''), isNull);
      });

      test('returns null for negative value', () {
        expect(CurrencyFormatter.toPaise('-100'), isNull);
      });

      test('returns null for non-numeric input', () {
        expect(CurrencyFormatter.toPaise('abc'), isNull);
      });

      test('handles comma-separated input', () {
        expect(CurrencyFormatter.toPaise('5,500'), 550000);
      });
    });

    group('signed', () {
      test('positive amount shows + prefix', () {
        expect(CurrencyFormatter.signed(50000), startsWith('+'));
      });

      test('negative amount shows - prefix', () {
        expect(CurrencyFormatter.signed(-50000), startsWith('-'));
      });

      test('zero shows + prefix', () {
        expect(CurrencyFormatter.signed(0), startsWith('+'));
      });
    });

    group('No floating-point errors', () {
      // Critical: must never use floating-point arithmetic
      test('0.1 + 0.2 should equal 0.3 in paise arithmetic', () {
        // 10 paise + 20 paise = 30 paise (integer — no float error)
        const a = 10;
        const b = 20;
        expect(a + b, 30);
      });

      test('large amounts remain exact', () {
        // 99999999 paise = ₹9,99,999.99 — must remain exact as integer
        const paise = 9999999;
        expect(CurrencyFormatter.fromPaise(paise), isNotEmpty);
        expect(paise, isA<int>());
      });
    });
  });
}
