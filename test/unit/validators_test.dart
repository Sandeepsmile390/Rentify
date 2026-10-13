import 'package:test/test.dart';
import 'package:rentify/core/utilities/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts valid email', () => expect(Validators.email('a@b.com'), isNull));
    test('rejects empty', () => expect(Validators.email(''), isNotNull));
    test('rejects no @', () => expect(Validators.email('notanemail'), isNotNull));
    test('rejects no domain', () => expect(Validators.email('a@'), isNotNull));
    test('trims before validating', () => expect(Validators.email('  a@b.com  '), isNull));
  });

  group('Validators.password', () {
    test('accepts 8+ chars', () => expect(Validators.password('abcdefgh'), isNull));
    test('rejects empty', () => expect(Validators.password(''), isNotNull));
    test('rejects 7 chars', () => expect(Validators.password('1234567'), isNotNull));
    test('accepts exactly 8 chars', () => expect(Validators.password('12345678'), isNull));
  });

  group('Validators.mobile', () {
    test('accepts 10 digit number', () => expect(Validators.mobile('9876543210'), isNull));
    test('accepts number with spaces', () => expect(Validators.mobile('98765 43210'), isNull));
    test('rejects 9 digit number', () => expect(Validators.mobile('987654321'), isNotNull));
    test('rejects empty', () => expect(Validators.mobile(''), isNotNull));
  });

  group('Validators.positiveAmount', () {
    test('accepts positive integer', () => expect(Validators.positiveAmount('5500'), isNull));
    test('accepts positive decimal', () => expect(Validators.positiveAmount('5500.50'), isNull));
    test('rejects zero', () => expect(Validators.positiveAmount('0'), isNotNull));
    test('rejects negative', () => expect(Validators.positiveAmount('-100'), isNotNull));
    test('rejects empty', () => expect(Validators.positiveAmount(''), isNotNull));
    test('rejects text', () => expect(Validators.positiveAmount('abc'), isNotNull));
  });

  group('Validators.meterReading', () {
    test('accepts valid reading above previous', () {
      expect(Validators.meterReading('500', previousReading: 400), isNull);
    });
    test('accepts same as previous (no consumption)', () {
      expect(Validators.meterReading('400', previousReading: 400), isNull);
    });
    test('rejects reading below previous', () {
      expect(Validators.meterReading('300', previousReading: 400), isNotNull);
    });
    test('accepts zero with no previous', () {
      expect(Validators.meterReading('0'), isNull);
    });
    test('rejects negative reading', () {
      expect(Validators.meterReading('-1'), isNotNull);
    });
    test('rejects empty', () {
      expect(Validators.meterReading(''), isNotNull);
    });
  });
}
