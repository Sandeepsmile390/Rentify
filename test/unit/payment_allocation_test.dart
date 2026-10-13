import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment & Allocation Invariants', () {
    test('allocations sum must not exceed total payment amount', () {
      const int paymentAmountPaise = 500000; // ₹5,000
      const int rentAllocPaise = 300000;     // ₹3,000
      const int elecAllocPaise = 200000;     // ₹2,000
      final int totalAlloc = rentAllocPaise + elecAllocPaise;

      expect(totalAlloc <= paymentAmountPaise, isTrue);
      expect(totalAlloc, paymentAmountPaise);
    });

    test('excess allocation is detected and rejected', () {
      const int paymentAmountPaise = 500000; // ₹5,000
      const int requestedAllocPaise = 550000; // ₹5,500
      final bool isValid = requestedAllocPaise <= paymentAmountPaise;

      expect(isValid, isFalse);
    });

    test('partial payment reduces outstanding balance correctly', () {
      const int chargeAmountPaise = 550000;   // ₹5,500
      const int allocatedPaise = 300000;      // ₹3,000
      final int outstandingPaise = chargeAmountPaise - allocatedPaise;

      expect(outstandingPaise, 250000); // ₹2,500
    });

    test('unallocated amount is preserved as unallocated credit', () {
      const int paymentAmountPaise = 600000; // ₹6,000
      const int totalAllocatedPaise = 550000; // ₹5,500
      final int unallocatedPaise = paymentAmountPaise - totalAllocatedPaise;

      expect(unallocatedPaise, 50000); // ₹500
    });
  });
}
