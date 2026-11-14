import 'package:bills_o9_time/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day, 9);

final _due = DateTime(2026, 11, 10, 9);

void main() {
  test('monthly bill keeps its due day across short months', () {
    var due = d(2026, 1, 31);
    due = nextDue(due, Repeat.monthly, dueDay: 31);
    expect(due, d(2026, 2, 28));
    due = nextDue(due, Repeat.monthly, dueDay: 31);
    expect(due, d(2026, 3, 31)); // back to the 31st, no drift
    due = nextDue(due, Repeat.monthly, dueDay: 31);
    expect(due, d(2026, 4, 30));
  });

  test('last day of month', () {
    expect(nextDue(d(2026, 1, 31), Repeat.monthly, dueDay: kLastDay),
        d(2026, 2, 28));
    expect(nextDue(d(2026, 2, 28), Repeat.monthly, dueDay: kLastDay),
        d(2026, 3, 31));
  });

  test('year rollover, quarterly and yearly', () {
    expect(nextDue(d(2026, 12, 10), Repeat.monthly, dueDay: 10),
        d(2027, 1, 10));
    expect(nextDue(d(2026, 11, 30), Repeat.quarterly, dueDay: 30),
        d(2027, 2, 28));
    expect(nextDue(d(2028, 2, 29), Repeat.yearly, dueDay: 29),
        d(2029, 2, 28));
  });

  test('next occurrence of a due day', () {
    expect(nextOccurrenceOfDay(20, DateTime(2026, 11, 13)), d(2026, 11, 20));
    expect(nextOccurrenceOfDay(13, DateTime(2026, 11, 13)), d(2026, 11, 13));
    expect(nextOccurrenceOfDay(5, DateTime(2026, 11, 13)), d(2026, 12, 5));
    expect(nextOccurrenceOfDay(31, DateTime(2026, 11, 13)), d(2026, 11, 30));
  });

  test('labels', () {
    expect(scheduleLabel(Repeat.monthly, 1), 'Every Month on 1st');
    expect(scheduleLabel(Repeat.monthly, 22), 'Every Month on 22nd');
    expect(scheduleLabel(Repeat.monthly, 1, every: 3), 'Every 3 Months on 1st');
    expect(scheduleLabel(Repeat.monthly, kLastDay), 'Every Month on last day');
    expect(scheduleLabel(Repeat.daily, 0, every: 2), 'Every 2 Days');
    expect(scheduleLabel(Repeat.weekly, 5), 'Every Week');
    expect(scheduleLabel(Repeat.quarterly, 15), 'Every 3 Months on 15th');
    expect(scheduleLabel(Repeat.none, 0), 'One-time');
  });

  test('every N units', () {
    expect(nextDue(d(2026, 11, 1), Repeat.monthly, dueDay: 1, every: 2),
        d(2027, 1, 1));
    expect(nextDue(d(2026, 11, 30), Repeat.daily, every: 2), d(2026, 12, 2));
    expect(nextDue(d(2026, 11, 13), Repeat.weekly, every: 2), d(2026, 11, 27));
    expect(nextDue(d(2026, 11, 13), Repeat.biweekly), d(2026, 11, 27));
  });

  test('occurrences until a date', () {
    final b = Bill(
        name: 'Rent',
        amount: 100,
        dueDate: _due,
        repeat: Repeat.monthly,
        dueDay: 10);
    final list = b.occurrencesUntil(DateTime(2027, 1, 31));
    expect(list, [d(2026, 11, 10), d(2026, 12, 10), d(2027, 1, 10)]);
  });
}
