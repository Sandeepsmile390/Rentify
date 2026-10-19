import 'package:flutter_test/flutter_test.dart';
import 'package:rentify/core/services/whatsapp_service.dart';

void main() {
  group('WhatsAppService Dues Summary Tests', () {
    test('formats fully cleared tenant message exactly as specified', () {
      final msg = WhatsAppService.buildClearedMessage(tenantName: 'Mahendra');
      expect(
        msg,
        'Hello Mahendra, *Good news!* Your rent account is fully cleared with *no pending dues*.\n'
        'Thank you for paying on time. We truly appreciate your cooperation!',
      );
    });

    test('formats pending dues summary with room rent breakdown and totals', () {
      final rentCharges = [
        {'billing_month': '2025-08-01', 'outstanding_paise': 170700},
        {'billing_month': '2025-09-01', 'outstanding_paise': 225000},
        {'billing_month': '2025-10-01', 'outstanding_paise': 225000},
        {'billing_month': '2025-11-01', 'outstanding_paise': 225000},
        {'billing_month': '2025-12-01', 'outstanding_paise': 225000},
        {'billing_month': '2026-05-01', 'outstanding_paise': 11200},
        {'billing_month': '2026-06-01', 'outstanding_paise': 225000},
        {'billing_month': '2026-07-01', 'outstanding_paise': 225000},
        {'billing_month': '2026-08-01', 'outstanding_paise': 225000},
        {'billing_month': '2026-09-01', 'outstanding_paise': 225000},
      ];
      final elecCharges = <Map<String, dynamic>>[];

      final msg = WhatsAppService.buildDuesSummaryMessage(
        tenantName: 'Madhu',
        rentCharges: rentCharges,
        elecCharges: elecCharges,
      );

      expect(msg, contains('Hello Madhu,'));
      expect(msg, contains('This is your pending dues summary.'));
      expect(msg, contains('*ROOM RENT DUES*'));
      expect(msg, contains('━━━━━━━━━━━━━━━'));
      expect(msg, contains('*2025*'));
      expect(msg, contains('• Aug → ₹1707'));
      expect(msg, contains('• Sep → ₹2250'));
      expect(msg, contains('*2026*'));
      expect(msg, contains('• May → ₹112'));
      expect(msg, contains('*TOTAL PENDING*'));
      expect(msg, contains('Room Rent Due : ₹19819'));
      expect(msg, contains('Electricity Due : ₹0'));
      expect(msg, contains('*Grand Total Due : ₹19819*'));
      expect(msg, contains('Please clear the dues at the earliest. Thank you.'));
    });

    test('returns fully cleared message if all outstanding balances are 0', () {
      final rentCharges = [
        {'billing_month': '2025-08-01', 'outstanding_paise': 0},
      ];
      final elecCharges = [
        {'billing_month': '2025-08-01', 'outstanding_paise': 0},
      ];

      final msg = WhatsAppService.buildDuesSummaryMessage(
        tenantName: 'Mahendra',
        rentCharges: rentCharges,
        elecCharges: elecCharges,
      );

      expect(msg, contains('*Good news!*'));
      expect(msg, contains('no pending dues'));
    });

    test('buildWhatsAppUri normalizes phone number and URL-encodes message', () {
      final uri = WhatsAppService.buildWhatsAppUri(
        phone: '9876543210',
        message: 'Hello Madhu, *ROOM RENT DUES*',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.queryParameters['text'], 'Hello Madhu, *ROOM RENT DUES*');
    });
  });
}
