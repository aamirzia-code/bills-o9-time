// Data models for Bills O9 Time.

enum TxType { expense, income }

enum Repeat { none, weekly, biweekly, monthly, quarterly, yearly }

enum GoalKind { saving, debt }

String repeatLabel(Repeat r) {
  switch (r) {
    case Repeat.none:
      return 'One-time';
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

/// Next due date after [d]. For monthly/quarterly/yearly bills the [dueDay]
/// is kept every cycle, so a bill due on the 31st returns to the 31st after
/// a short month instead of drifting to the 28th.
DateTime nextDue(DateTime d, Repeat r, {int dueDay = 0}) {
  switch (r) {
    case Repeat.none:
      return d;
    case Repeat.weekly:
      return d.add(const Duration(days: 7));
    case Repeat.biweekly:
      return d.add(const Duration(days: 14));
    case Repeat.monthly:
      return _addMonths(d, 1, dueDay);
    case Repeat.quarterly:
      return _addMonths(d, 3, dueDay);
    case Repeat.yearly:
      return _addMonths(d, 12, dueDay);
  }
}

/// e.g. "Monthly on the 10th", "Quarterly on the last day".
String scheduleLabel(Repeat r, int dueDay) {
  if (!repeatsByMonth(r) || dueDay == 0) return repeatLabel(r);
  return '${repeatLabel(r)} on the ${dueDayLabel(dueDay)}';
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

  const Txn({
    this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.accountId,
    required this.date,
    this.note = '',
    this.billId,
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
        remindDaysBefore: m['remind_days'] as int,
        notes: (m['notes'] as String?) ?? '',
        active: (m['active'] as int) == 1,
      );

  String get schedule => scheduleLabel(repeat, dueDay);

  DateTime get followingDue => nextDue(dueDate, repeat, dueDay: dueDay);

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

  const Goal({
    this.id,
    required this.name,
    required this.kind,
    required this.target,
    this.interestRate = 0,
    this.deadline,
    required this.color,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.index,
        'target': target,
        'interest': interestRate,
        'deadline': deadline?.millisecondsSinceEpoch,
        'color': color,
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
      );
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
