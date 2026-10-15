import 'package:flutter_test/flutter_test.dart';
import 'package:rentify/core/utilities/currency_formatter.dart';
import 'package:rentify/core/utilities/validators.dart';

void main() {
  group('WhatsApp Message Formatting & Tenant Phone Logic', () {
    test('cleans 10-digit Indian phone number to 91XXXXXXXXXX format', () {
      const rawMobile = '98765 43210';
      final clean = rawMobile.replaceAll(RegExp(r'\D'), '');
      final formatted = clean.length == 10 ? '91$clean' : clean;
      expect(formatted, equals('919876543210'));
    });

    test('generates correct WhatsApp dues summary text', () {
      final name = 'Test Tenant';
      final unitId = 'Room 101';
      final rentDuePaise = 1500000;
      final elecDuePaise = 120000;
      final totalDuePaise = rentDuePaise + elecDuePaise;

      final message = StringBuffer();
      message.writeln('📋 *Rentify Payment Notice*');
      message.writeln('Dear $name,');
      message.writeln('Here is your dues summary for *$unitId*:');
      message.writeln('');
      message.writeln('• *Rent Due:* ${CurrencyFormatter.fromPaise(rentDuePaise)}');
      message.writeln('• *Electricity Due:* ${CurrencyFormatter.fromPaise(elecDuePaise)}');
      message.writeln('━━━━━━━━━━━━━━━━━');
      message.writeln('👉 *Total Outstanding: ${CurrencyFormatter.fromPaise(totalDuePaise)}*');

      final text = message.toString();
      expect(text, contains('Room 101'));
      expect(text, contains('₹15,000'));
      expect(text, contains('₹1,200'));
      expect(text, contains('₹16,200'));
    });
  });

  group('Payment Validation & Over-allocation Detection', () {
    test('detects when allocation exceeds payment amount', () {
      final paymentAmountPaise = 1000000; // ₹10,000
      final allocations = {
        'charge-1': 800000, // ₹8,000
        'charge-2': 300000, // ₹3,000
      };
      final totalAllocated = allocations.values.fold(0, (s, v) => s + v);
      final exceeds = totalAllocated > paymentAmountPaise;

      expect(totalAllocated, equals(1100000));
      expect(exceeds, isTrue);
    });

    test('accepts when allocation is equal or less than payment amount', () {
      final paymentAmountPaise = 1000000; // ₹10,000
      final allocations = {
        'charge-1': 600000, // ₹6,000
        'charge-2': 400000, // ₹4,000
      };
      final totalAllocated = allocations.values.fold(0, (s, v) => s + v);
      final exceeds = totalAllocated > paymentAmountPaise;

      expect(totalAllocated, equals(1000000));
      expect(exceeds, isFalse);
    });
  });

  group('Advance and Deposit Math', () {
    test('deposits and refunds calculate running balance correctly', () {
      int balance = 0;
      final txns = [
        {'type': 'deposit', 'amount': 2500000},
        {'type': 'adjustment', 'amount': -500000},
        {'type': 'deposit', 'amount': 1000000},
      ];

      for (final t in txns) {
        if (t['type'] == 'deposit') {
          balance += t['amount'] as int;
        } else if (t['type'] == 'adjustment' || t['type'] == 'refund') {
          balance += t['amount'] as int; // negative
        }
      }

      expect(balance, equals(3000000)); // ₹30,000
    });
  });

  group('Electricity Consumption Calculation', () {
    test('units consumed multiplied by rate in paise', () {
      const prevReading = 100.0;
      const currReading = 150.0;
      const ratePaise = 900; // ₹9.00 / unit

      final units = currReading - prevReading;
      final amountPaise = (units * ratePaise).round();

      expect(units, equals(50.0));
      expect(amountPaise, equals(45000)); // ₹450
      expect(CurrencyFormatter.fromPaise(amountPaise), equals('₹450'));
    });
  });
}
