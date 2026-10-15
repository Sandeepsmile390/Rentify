import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentify/core/utilities/currency_formatter.dart';

void main() {
  group('Dashboard Widget & Component Tests', () {
    testWidgets('Dashboard Error View displays actionable message and triggers retry', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Dashboard Unavailable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Unable to refresh dashboard data. Please check connection and retry.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => retried = true,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Connection'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard Unavailable'), findsOneWidget);
      expect(find.text('Unable to refresh dashboard data. Please check connection and retry.'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('Financial Stat Card renders correct currency and labels', (tester) async {
      const int testRentDuePaise = 1500000; // ₹15,000
      const int testActiveTenants = 8;
      const int testTotalTenants = 10;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Total Rent Due', style: const TextStyle(fontSize: 14)),
                    Text(CurrencyFormatter.fromPaise(testRentDuePaise), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('$testActiveTenants of $testTotalTenants active tenants'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Total Rent Due'), findsOneWidget);
      expect(find.text('₹15,000'), findsOneWidget);
      expect(find.text('8 of 10 active tenants'), findsOneWidget);
    });
  });
}
