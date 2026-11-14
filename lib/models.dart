// Data models for Bills O9 Time.

enum TxType { expense, income }

/// Stored by index in the database: only ever append new values.
enum Repeat { none, weekly, biweekly, monthly, quarterly, yearly, daily }

enum GoalKind { saving, debt }

/// Repeat choices offered in the bill form. Legacy biweekly/quarterly are
/// shown as "every 2 weeks" / "every 3 months".
const kRepeatChoices = [
  Repeat.none,
  Repeat.daily,
  Repeat.weekly,
  Repeat.monthly,
  Repeat.yearly,
];

String repeatLabel(Repeat r) {
  switch (r) {
    case Repeat.none:
      return 'One-time';
    case Repeat.daily:
      return 'Daily';
    case Repeat.weekly:
      return 'Weekly';
    case Repeat.biweekly:
      return 'Every 2 weeks';
    case Repeat.monthly:
      return 'Monthly';
    case Repeat.quarterly:
      return 'Quarterly';
    case Repeat.yearly:
      return 'Yearly';
  }
}

String _unit(Repeat r) {
  switch (r) {
    case Repeat.daily:
      return 'Day';
    case Repeat.weekly:
    case Repeat.biweekly:
      return 'Week';
    case Repeat.monthly:
    case Repeat.quarterly:
      return 'Month';
    case Repeat.yearly:
      return 'Year';
    case Repeat.none:
      return '';
  }
}

/// Converts legacy presets to a base unit + multiplier.
(Repeat, int) normalizeRepeat(Repeat r, int every) {
  final n = every < 1 ? 1 : every;
  if (r == Repeat.biweekly) return (Repeat.weekly, 2 * n);
  if (r == Repeat.quarterly) return (Repeat.monthly, 3 * n);
  return (r, n);
}

/// Special [Bill.dueDay] value meaning "last day of the month".
const int kLastDay = 32;

bool repeatsByMonth(Repeat r) =>
    r == Repeat.monthly || r == Repeat.quarterly || r == Repeat.yearly;

String ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

String dueDayLabel(int dueDay) =>
    dueDay == kLastDay ? 'last day' : ordinal(dueDay);

/// The date in [year]/[month] for a due day (1-31 or [kLastDay]),
/// clamped to short months (e.g. the 31st becomes 30 Apr / 28 Feb).
DateTime dateForDueDay(int year, int month, int dueDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = dueDay >= lastDay ? lastDay : dueDay;
  return DateTime(year, month, day, 9);
}

/// Next date (today or later) that falls on [dueDay] of a month.
DateTime nextOccurrenceOfDay(int dueDay, [DateTime? from]) {
  final now = from ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonth = dateForDueDay(now.year, now.month, dueDay);
  if (!DateTime(thisMonth.year, thisMonth.month, thisMonth.day)
      .isBefore(today)) {
    return thisMonth;
  }
  return dateForDueDay(now.year, now.month + 1, dueDay);
}

DateTime _addMonths(DateTime d, int months, int dueDay) {
  final target = DateTime(d.year, d.month + months);
  return dateForDueDay(
      target.year, target.month, dueDay > 0 ? dueDay : d.day);
}

/// Next due date after [d], repeating every [every] units of [r].
/// For month-based bills the [dueDay] is kept every cycle, so a bill due on
/// the 31st returns to the 31st after a short month instead of drifting.
DateTime nextDue(DateTime d, Repeat r, {int dueDay = 0, int every = 1}) {
  final (base, n) = normalizeRepeat(r, every);
  switch (base) {
    case Repeat.none:
      return d;
    case Repeat.daily:
      return DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
    case Repeat.weekly:
    case Repeat.biweekly:
      return DateTime(d.year, d.month, d.day + 7 * n, d.hour, d.minute);
    case Repeat.monthly:
    case Repeat.quarterly:
      return _addMonths(d, n, dueDay);
    case Repeat.yearly:
      return _addMonths(d, 12 * n, dueDay);
  }
}

/// e.g. "Every Month on 10th", "Every 3 Months on 1st", "Every 2 Days".
String scheduleLabel(Repeat r, int dueDay, {int every = 1}) {
  if (r == Repeat.none) return 'One-time';
  final (base, n) = normalizeRepeat(r, every);
  final unit = _unit(base);
  final head = n == 1 ? 'Every $unit' : 'Every $n ${unit}s';
  if (repeatsByMonth(base) && dueDay > 0) {
    return '$head on ${dueDayLabel(dueDay)}';
  }
  return head;
}

class TxCategory {
  final int? id;
  final String name;
  final TxType type;
  final String icon;
  final int color;

  const TxCategory({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'icon': icon,
        'color': color,
      };

  factory TxCategory.fromMap(Map<String, Object?> m) => TxCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        type: TxType.values[m['type'] as int],
        icon: m['icon'] as String,
        color: m['color'] as int,
      );
}

class Account {
  final int? id;
  final String name;
  final String kind; // Cash, Bank, Card, Wallet
  final double openingBalance;
  final int color;

  const Account({
    this.id,
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.color,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'opening_balance': openingBalance,
        'color': color,
      };

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int,
        name: m['name'] as String,
        kind: m['kind'] as String,
        openingBalance: (m['opening_balance'] as num).toDouble(),
        color: m['color'] as int,
      );
}

class Txn {
  final int? id;
  final TxType type;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final DateTime date;
  final String note;
  final int? billId;
  final DateTime? dueDate; // for bill payments: the due date that was paid

  const Txn({
    this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.accountId,
    required this.date,
    this.note = '',
    this.billId,
    this.dueDate,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.index,
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'bill_id': billId,
        'due_date': dueDate?.millisecondsSinceEpoch,
      };

  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int,
        type: TxType.values[m['type'] as int],
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int?,
        accountId: m['account_id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: (m['note'] as String?) ?? '',
        billId: m['bill_id'] as int?,
        dueDate: m['due_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int),
      );
}

class Bill {
  final int? id;
  final String name;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final DateTime dueDate;
  final Repeat repeat;
  final int dueDay; // 1-31, kLastDay, or 0 = follow dueDate
  final int every; // repeat every N days/weeks/months/years
  final bool autoPay; // record the payment automatically on the due date
  final int remindDaysBefore;
  final String notes;
  final bool active;

  const Bill({
    this.id,
    required this.name,
    required this.amount,
    this.categoryId,
    this.accountId,
    required this.dueDate,
    this.repeat = Repeat.monthly,
    this.dueDay = 0,
    this.every = 1,
    this.autoPay = false,
    this.remindDaysBefore = 2,
    this.notes = '',
    this.active = true,
  });

  Bill copyWith({DateTime? dueDate, bool? active}) => Bill(
        id: id,
        name: name,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        dueDate: dueDate ?? this.dueDate,
        repeat: repeat,
        dueDay: dueDay,
        every: every,
        autoPay: autoPay,
        remindDaysBefore: remindDaysBefore,
        notes: notes,
        active: active ?? this.active,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'due_date': dueDate.millisecondsSinceEpoch,
        'repeat': repeat.index,
        'due_day': dueDay,
        'repeat_every': every,
        'auto_pay': autoPay ? 1 : 0,
        'remind_days': remindDaysBefore,
        'notes': notes,
        'active': active ? 1 : 0,
      };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as int,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int?,
        accountId: m['account_id'] as int?,
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int),
        repeat: Repeat.values[m['repeat'] as int],
        dueDay: (m['due_day'] as int?) ?? 0,
        every: (m['repeat_every'] as int?) ?? 1,
        autoPay: ((m['auto_pay'] as int?) ?? 0) == 1,
        remindDaysBefore: m['remind_days'] as int,
        notes: (m['notes'] as String?) ?? '',
        active: (m['active'] as int) == 1,
      );

  String get schedule => scheduleLabel(repeat, dueDay, every: every);

  bool get recurring => repeat != Repeat.none;

  DateTime get followingDue =>
      nextDue(dueDate, repeat, dueDay: dueDay, every: every);

  /// This bill's due dates from the current one up to and including [until].
  List<DateTime> occurrencesUntil(DateTime until, {int max = 120}) {
    final out = <DateTime>[];
    var d = dueDate;
    while (!d.isAfter(until) && out.length < max) {
      out.add(d);
      if (!recurring) break;
      d = nextDue(d, repeat, dueDay: dueDay, every: every);
    }
    return out;
  }

  int daysUntilDue(DateTime now) {
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return b.difference(a).inDays;
  }
}

class Budget {
  final int? id;
  final int? categoryId; // null = overall monthly budget
  final double amount;

  const Budget({this.id, this.categoryId, required this.amount});

  Map<String, Object?> toMap() => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int,
        categoryId: m['category_id'] as int?,
        amount: (m['amount'] as num).toDouble(),
      );
}

class Goal {
  final int? id;
  final String name;
  final GoalKind kind;
  final double target; // goal amount or total debt
  final double interestRate; // annual %, debts only
  final DateTime? deadline;
  final int color;
  final String icon;

  const Goal({
    this.id,
    required this.name,
    required this.kind,
    required this.target,
    this.interestRate = 0,
    this.deadline,
    required this.color,
    this.icon = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.index,
        'target': target,
        'interest': interestRate,
        'deadline': deadline?.millisecondsSinceEpoch,
        'color': color,
        'icon': icon,
      };

  factory Goal.fromMap(Map<String, Object?> m) => Goal(
        id: m['id'] as int,
        name: m['name'] as String,
        kind: GoalKind.values[m['kind'] as int],
        target: (m['target'] as num).toDouble(),
        interestRate: (m['interest'] as num).toDouble(),
        deadline: m['deadline'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['deadline'] as int),
        color: m['color'] as int,
        icon: (m['icon'] as String?) ?? '',
      );

  /// Amount to put aside each month to finish by the deadline (0 if none).
  double monthlyNeed(double done, [DateTime? now]) {
    final left = target - done;
    if (deadline == null || left <= 0) return 0;
    final n = now ?? DateTime.now();
    final months =
        (deadline!.year - n.year) * 12 + deadline!.month - n.month;
    return months <= 0 ? left : left / months;
  }
}

class GoalEntry {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime date;
  final String note;

  const GoalEntry({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'goal_id': goalId,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };

  factory GoalEntry.fromMap(Map<String, Object?> m) => GoalEntry(
        id: m['id'] as int,
        goalId: m['goal_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: (m['note'] as String?) ?? '',
      );
}
