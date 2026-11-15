import 'package:bills_o9_time/features/logic.dart';
import 'package:bills_o9_time/features/heatmap.dart';
import 'package:bills_o9_time/features/fuel.dart';
import 'package:bills_o9_time/features/daily_models.dart';
import 'package:bills_o9_time/features/quick_add.dart';
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

  group('quick entry', () {
    final cats = [
      const TxCategory(id: 1, name: 'Fuel', type: TxType.expense, icon: 'fuel', color: 0),
      const TxCategory(id: 2, name: 'Food & Dining', type: TxType.expense, icon: 'food', color: 0),
      const TxCategory(id: 3, name: 'Salary', type: TxType.income, icon: 'salary', color: 0),
    ];
    final accts = [
      const Account(id: 10, name: 'Cash', kind: 'Cash', openingBalance: 0, color: 0),
      const Account(id: 11, name: 'Meezan', kind: 'Bank', openingBalance: 0, color: 0),
    ];
    final now = DateTime(2026, 11, 15, 10);

    test('amount, category and account', () {
      final q = parseQuickEntry('500 petrol cash', categories: cats, accounts: accts, now: now);
      expect(q.amount, 500);
      expect(q.categoryId, 1);
      expect(q.accountId, 10);
      expect(q.type, TxType.expense);
      expect(q.note, 'Petrol');
    });

    test('k suffix and yesterday', () {
      final q = parseQuickEntry('lunch 1.2k yesterday meezan', categories: cats, accounts: accts, now: now);
      expect(q.amount, 1200);
      expect(q.categoryId, 2);
      expect(q.accountId, 11);
      expect(q.date, DateTime(2026, 11, 14, 12));
    });

    test('income', () {
      final q = parseQuickEntry('salary 150,000', categories: cats, accounts: accts, now: now);
      expect(q.amount, 150000);
      expect(q.type, TxType.income);
      expect(q.categoryId, 3);
    });
  });

  group('daily tools', () {
    Txn e(DateTime d, double a, {int? bill, TxType type = TxType.expense, String note = ''}) =>
        Txn(type: type, amount: a, date: d, billId: bill, note: note);

    test('no-spend streak ignores bill payments', () {
      final today = DateTime(2026, 11, 15, 20);
      final txns = [
        e(DateTime(2026, 11, 10, 9), 500),
        e(DateTime(2026, 11, 13, 9), 9000, bill: 1),
        e(DateTime(2026, 11, 12, 9), 50000, type: TxType.income),
      ];
      expect(noSpendStreak(txns, today), 5);
      expect(noSpendStreak([...txns, e(DateTime(2026, 11, 15, 8), 20)], today), 0);
    });

    test('daily spend buckets by day', () {
      final m = dailySpend([
        e(DateTime(2026, 11, 3, 9), 100),
        e(DateTime(2026, 11, 3, 18), 50),
        e(DateTime(2026, 11, 4, 9), 70, bill: 2),
      ], DateTime(2026, 11, 1), DateTime(2026, 12, 1));
      expect(m[DateTime(2026, 11, 3)], 150);
      expect(m.containsKey(DateTime(2026, 11, 4)), isFalse);
    });

    test('fuel mileage', () {
      final logs = [
        FuelLog(vehicle: 'Car', date: DateTime(2026, 11, 1), litres: 30, price: 270, odometer: 10000),
        FuelLog(vehicle: 'Car', date: DateTime(2026, 11, 10), litres: 25, price: 270, odometer: 10350),
        FuelLog(vehicle: 'Car', date: DateTime(2026, 11, 20), litres: 25, price: 270, odometer: 10700),
      ];
      final st = fuelStats(logs, now: DateTime(2026, 11, 25));
      expect(st.kmPerLitre, closeTo(14, 0.01));
      expect(st.costPerKm, closeTo(270 / 14, 0.01));
      expect(st.monthLitres, 80);
    });

    test('frequent entries need at least two repeats', () {
      final now = DateTime(2026, 11, 15);
      final f = frequentEntries([
        e(DateTime(2026, 11, 1), 120, note: 'Chai'),
        e(DateTime(2026, 11, 2), 120, note: 'chai'),
        e(DateTime(2026, 11, 3), 120, note: 'Chai'),
        e(DateTime(2026, 11, 4), 900, note: 'Pizza'),
      ], now: now);
      expect(f.length, 1);
      expect(f.first.count, 3);
      expect(f.first.amount, 120);
    });

    test('renewal days left and renew', () {
      final r = Renewal(name: 'Token', kind: 'vehicle', expiry: DateTime(2026, 11, 25));
      expect(r.daysLeft(DateTime(2026, 11, 15, 22)), 10);
      expect(r.renewed().expiry, DateTime(2027, 11, 25));
    });
  });
}
