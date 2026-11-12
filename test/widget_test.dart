import 'package:bills_o9_time/models.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day, 9);

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
    expect(scheduleLabel(Repeat.monthly, 1), 'Monthly on the 1st');
    expect(scheduleLabel(Repeat.monthly, 22), 'Monthly on the 22nd');
    expect(scheduleLabel(Repeat.monthly, 13), 'Monthly on the 13th');
    expect(scheduleLabel(Repeat.monthly, kLastDay), 'Monthly on the last day');
    expect(scheduleLabel(Repeat.weekly, 5), 'Weekly');
  });
}
