import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class OutstandingRentMonth {
  const OutstandingRentMonth({
    required this.billingMonth, // Canonical YYYY-MM-01
    required this.duePaise,
  });

  final String billingMonth;
  final int duePaise;

  int get year {
    try {
      return int.parse(billingMonth.split('-')[0]);
    } catch (_) {
      return DateTime.now().year;
    }
  }

  int get monthNumber {
    try {
      return int.parse(billingMonth.split('-')[1]);
    } catch (_) {
      return 1;
    }
  }

  String get shortMonthName {
    try {
      final dt = DateTime(year, monthNumber, 1);
      return DateFormat('MMM').format(dt);
    } catch (_) {
      return 'Mon';
    }
  }

  int get dueRupees => (duePaise / 100).round();
}

class WhatsAppDuesSummaryPayload {
  const WhatsAppDuesSummaryPayload({
    required this.tenantName,
    required this.mobile,
    required this.outstandingRentMonths,
    required this.totalRentDuePaise,
    required this.totalElecDuePaise,
  });

  final String tenantName;
  final String mobile;
  final List<OutstandingRentMonth> outstandingRentMonths;
  final int totalRentDuePaise;
  final int totalElecDuePaise;

  int get totalRentDueRupees => (totalRentDuePaise / 100).round();
  int get totalElecDueRupees => (totalElecDuePaise / 100).round();
  int get grandTotalDueRupees => totalRentDueRupees + totalElecDueRupees;
  bool get isFullyPaid => grandTotalDueRupees <= 0;
}

class WhatsAppService {
  /// Generates the exact message text according to specification.
  static String generateMessage(WhatsAppDuesSummaryPayload payload) {
    final buffer = StringBuffer();

    if (payload.isFullyPaid) {
      buffer.write(
        'Hello ${payload.tenantName}, *Good news!* Your rent account is fully cleared with *no pending dues*.\n'
        'Thank you for paying on time. We truly appreciate your cooperation!',
      );
      return buffer.toString();
    }

    buffer.writeln('Hello ${payload.tenantName},');
    buffer.writeln('');
    buffer.writeln('This is your pending dues summary.');
    buffer.writeln('');

    if (payload.outstandingRentMonths.isNotEmpty) {
      buffer.writeln('*ROOM RENT DUES*');
      buffer.writeln('━━━━━━━━━━━━━━━');

      // Sort chronologically
      final sortedMonths = List<OutstandingRentMonth>.from(payload.outstandingRentMonths)
        ..sort((a, b) => a.billingMonth.compareTo(b.billingMonth));

      // Group by year
      final Map<int, List<OutstandingRentMonth>> byYear = {};
      for (final m in sortedMonths) {
        if (m.dueRupees > 0) {
          byYear.putIfAbsent(m.year, () => []).add(m);
        }
      }

      final sortedYears = byYear.keys.toList()..sort();
      for (final y in sortedYears) {
        buffer.writeln('*$y*');
        for (final m in byYear[y]!) {
          buffer.writeln('• ${m.shortMonthName} → ₹${m.dueRupees}');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('*TOTAL PENDING*');
    buffer.writeln('━━━━━━━━━━━━━━━');
    buffer.writeln('Room Rent Due : ₹${payload.totalRentDueRupees}');
    buffer.writeln('Electricity Due : ₹${payload.totalElecDueRupees}');
    buffer.writeln('*Grand Total Due : ₹${payload.grandTotalDueRupees}*');
    buffer.writeln('');
    buffer.write('Please clear the dues at the earliest. Thank you.');

    return buffer.toString();
  }

  /// Opens WhatsApp with recipient and encoded message, with clipboard/browser fallback.
  static Future<void> shareDuesSummary({
    required BuildContext context,
    required WhatsAppDuesSummaryPayload payload,
  }) async {
    final messageText = generateMessage(payload);
    final cleanMobile = payload.mobile.replaceAll(RegExp(r'\D'), '');
    final phone = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;
    final encodedMsg = Uri.encodeComponent(messageText);

    final uri = Uri.parse(
      phone.isNotEmpty
          ? 'https://wa.me/$phone?text=$encodedMsg'
          : 'https://wa.me/?text=$encodedMsg',
    );

    try {
      bool launched = false;
      if (kIsWeb) {
        launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      }

      if (!launched && context.mounted) {
        await _fallbackCopy(context, messageText);
      }
    } catch (_) {
      if (context.mounted) {
        await _fallbackCopy(context, messageText);
      }
    }
  }

  /// Convenience helper to generate cleared message
  static String buildClearedMessage({required String tenantName}) {
    return generateMessage(
      WhatsAppDuesSummaryPayload(
        tenantName: tenantName,
        mobile: '',
        outstandingRentMonths: const [],
        totalRentDuePaise: 0,
        totalElecDuePaise: 0,
      ),
    );
  }

  /// Convenience helper to construct WhatsApp URI
  static Uri buildWhatsAppUri({required String phone, required String message}) {
    final cleanMobile = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;
    return Uri.https('wa.me', '/$fullPhone', {'text': message});
  }

  /// Convenience helper to construct message from raw charge maps
  static String buildDuesSummaryMessage({
    required String tenantName,
    required List<Map<String, dynamic>> rentCharges,
    required List<Map<String, dynamic>> elecCharges,
  }) {
    final outstandingMonths = <OutstandingRentMonth>[];
    int totalRentPaise = 0;
    int totalElecPaise = 0;

    for (final r in rentCharges) {
      final due = (r['outstanding_paise'] as num?)?.toInt() ?? 0;
      if (due > 0) {
        outstandingMonths.add(
          OutstandingRentMonth(
            billingMonth: r['billing_month']?.toString() ?? '',
            duePaise: due,
          ),
        );
        totalRentPaise += due;
      }
    }

    for (final e in elecCharges) {
      final due = (e['outstanding_paise'] as num?)?.toInt() ?? 0;
      totalElecPaise += due;
    }

    return generateMessage(
      WhatsAppDuesSummaryPayload(
        tenantName: tenantName,
        mobile: '',
        outstandingRentMonths: outstandingMonths,
        totalRentDuePaise: totalRentPaise,
        totalElecDuePaise: totalElecPaise,
      ),
    );
  }

  static Future<void> _fallbackCopy(BuildContext context, String messageText) async {
    await Clipboard.setData(ClipboardData(text: messageText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp app directly. Dues notice copied to clipboard!'),
          backgroundColor: AppColors.action,
        ),
      );
    }
  }
}
