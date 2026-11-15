import 'package:bills_o9_time/features/logic.dart';
import 'package:bills_o9_time/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bank SMS', () {
    test('debit with card digits and merchant', () {
      final p = parseBankSms(
          'PKR 2,450.00 spent on your HBL Debit Card ending 1234 at IMTIAZ SUPER MARKET on 12-11-2026.',
          now: DateTime(2026, 11, 15));
      expect(p.amount, 2450.0);
      expect(p.type, TxType.expense);
      expect(p.last4, '1234');
      expect(p.merchant, 'IMTIAZ SUPER MARKET');
      expect(p.date, DateTime(2026, 11, 12, 12));
    });

    test('credit', () {
      final p = parseBankSms(
          'Dear Customer, your A/C ****5678 has been credited with Rs.150,000 on 01-Nov-26. Salary.',
          now: DateTime(2026, 11, 15));
      expect(p.amount, 150000);
      expect(p.type, TxType.income);
      expect(p.last4, '5678');
      expect(p.date, DateTime(2026, 11, 1, 12));
    });

    test('Gulf format, amount before currency', () {
      final p = parseBankSms('Purchase of 85.50 AED with Card ending 4321 at CARREFOUR.');
      expect(p.amount, 85.5);
      expect(p.currency, 'AED');
      expect(p.type, TxType.expense);
    });
  });

  test('zakat', () {
    final r = computeZakat(
      cashAndBank: 500000,
      savings: 200000,
      goldGrams: 0,
      silverGrams: 0,
      goldPricePerGram: 25000,
      silverPricePerGram: 250,
      otherAssets: 0,
      receivables: 0,
      liabilities: 100000,
      silverNisab: true,
    );
    expect(r.net, 600000);
    expect(r.due, isTrue); // nisab = 612.36 * 250 = 153,090
    expect(r.zakat, closeTo(15000, 0.01));
  });

  test('subscription finder', () {
    Txn t(int m, double a) => Txn(
        type: TxType.expense, amount: a, date: DateTime(2026, m, 5), note: 'Netflix');
    final guesses = findSubscriptions([t(7, 1100), t(8, 1100), t(9, 1150), t(10, 1100)], []);
    expect(guesses.length, 1);
    expect(guesses.first.repeat, Repeat.monthly);
  });

  test('calendar file', () {
    final bill = Bill(
        id: 1,
        name: 'Rent',
        amount: 46000,
        dueDate: DateTime(2026, 12, 10, 9),
        repeat: Repeat.monthly,
        dueDay: 10,
        remindDaysBefore: 2);
    final ics = buildIcs([bill], money: (v) => 'Rs $v', now: DateTime(2026, 11, 15));
    expect(ics, contains('RRULE:FREQ=MONTHLY;BYMONTHDAY=10'));
    expect(ics, contains('TRIGGER:-P2D'));
    expect(ics, contains('DTSTART:20261210T090000'));
  });
}
