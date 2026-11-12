import 'package:bills_o9_time/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly bills roll to the next month and clamp short months', () {
    expect(nextDue(DateTime(2026, 1, 31), Repeat.monthly), DateTime(2026, 2, 28));
    expect(nextDue(DateTime(2026, 11, 15), Repeat.monthly), DateTime(2026, 12, 15));
    expect(nextDue(DateTime(2026, 12, 15), Repeat.monthly), DateTime(2027, 1, 15));
  });

  test('yearly and weekly repeats', () {
    expect(nextDue(DateTime(2026, 3, 1), Repeat.yearly), DateTime(2027, 3, 1));
    expect(nextDue(DateTime(2026, 3, 1), Repeat.weekly), DateTime(2026, 3, 8));
  });
}
