import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:splitpay/data/services/upi_image_import_service.dart';

void main() {
  group('UpiImageImportService.parseOcrText', () {
    test('extracts amount, merchant, date, and UPI reference', () {
      final draft = UpiImageImportService.parseOcrText('''
Payment successful
Paid to Swiggy
₹1,250
03 Oct 2026, 09:32 AM
UPI Ref: 123456789012
''');

      expect(draft.amount, 1250);
      expect(draft.merchant, 'Swiggy');
      expect(draft.dateTime, DateTime(2026, 10, 3, 9, 32));
      expect(draft.reference, '123456789012');
    });

    test('returns missing fields as null without logging OCR text', () {
      final draft =
          UpiImageImportService.parseOcrText('Payment successful\nThank you');

      expect(draft.amount, isNull);
      expect(draft.merchant, isNull);
      expect(draft.dateTime, isNull);
      expect(draft.reference, isNull);
    });

    test('uses the current year for a date without a year', () {
      final draft = UpiImageImportService.parseOcrText(
        'Paid to Cafe\n₹240\n03 Oct\n09:32 AM',
      );

      expect(draft.dateTime, DateTime(DateTime.now().year, 10, 3, 9, 32));
    });

    test('extracts common OCR variants of currency amounts', () {
      for (final receipt in [
        'Paid to Swiggy\n₹ 1,250.00',
        'Paid to Swiggy\nRs. 1 250',
        'Paid to Swiggy\n1,250 INR',
      ]) {
        expect(
          UpiImageImportService.parseOcrText(receipt).amount,
          1250,
          reason: receipt,
        );
      }
    });

    test('extracts a labeled amount when OCR puts the number on its own line',
        () {
      final draft = UpiImageImportService.parseOcrText(
        'Payment successful\nAmount paid\n1,250.00\nUPI Ref: 123456789012',
      );

      expect(draft.amount, 1250);
    });

    test('uses a sole standalone number when OCR loses its currency marker',
        () {
      final draft = UpiImageImportService.parseOcrText(
        'Payment successful\nSwiggy\n1,250.00\n03 Oct 2026, 09:32 AM',
      );

      expect(draft.amount, 1250);
    });

    test('does not guess when multiple unlabeled amounts are present', () {
      final draft = UpiImageImportService.parseOcrText(
        'Payment successful\n1,250.00\n3,000.00',
      );

      expect(draft.amount, isNull);
    });
  });

  group('categoryForMerchant', () {
    test('maps common merchant names to expense categories', () {
      expect(categoryForMerchant('Swiggy'), Category.food);
      expect(categoryForMerchant('Uber'), Category.travel);
      expect(categoryForMerchant('Amazon'), Category.shopping);
      expect(categoryForMerchant('Unknown UPI merchant'), Category.other);
    });
  });
}
