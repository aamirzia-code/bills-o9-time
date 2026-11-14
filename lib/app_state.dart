import 'package:flutter/material.dart';

import 'db.dart';
import 'models.dart';
import 'notifications.dart';
import 'utils.dart';

class AppState extends ChangeNotifier {
  final _db = AppDb.instance;

  bool loaded = false;
  List<TxCategory> categories = [];
  List<Account> accounts = [];
  List<Bill> bills = [];
  List<Txn> txns = [];
  List<Budget> budgets = [];
  List<Goal> goals = [];
  List<GoalEntry> goalEntries = [];
  String currency = 'Rs';
  ThemeMode themeMode = ThemeMode.dark;
  String userName = '';
  double? incomeBudget;
  bool _autoPayRan = false;

  Future<void> load() async {
    categories = (await _db.all('categories', orderBy: 'name'))
        .map(TxCategory.fromMap)
        .toList();
    accounts =
        (await _db.all('accounts', orderBy: 'id')).map(Account.fromMap).toList();
    bills =
        (await _db.all('bills', orderBy: 'due_date')).map(Bill.fromMap).toList();
    txns = (await _db.all('txns', orderBy: 'date DESC, id DESC'))
        .map(Txn.fromMap)
        .toList();
    budgets = (await _db.all('budgets')).map(Budget.fromMap).toList();
    goals = (await _db.all('goals', orderBy: 'id')).map(Goal.fromMap).toList();
    goalEntries = (await _db.all('goal_entries', orderBy: 'date DESC'))
        .map(GoalEntry.fromMap)
        .toList();
    currency = await _db.getSetting('currency') ?? 'Rs';
    Fmt.symbol = currency;
    final tm = await _db.getSetting('theme');
    themeMode = ThemeMode.values[int.tryParse(tm ?? '') ?? ThemeMode.dark.index];
    userName = await _db.getSetting('name') ?? '';
    incomeBudget = double.tryParse(await _db.getSetting('income_budget') ?? '');
    loaded = true;
    notifyListeners();
    if (!_autoPayRan) {
      _autoPayRan = true;
      await runAutoPay();
    }
  }

  /// Records payments for auto-paid bills whose due date has arrived.
  Future<void> runAutoPay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59);
    var changed = false;
    for (final b in bills.where((b) => b.active && b.autoPay)) {
      var bill = b;
      var guard = 0;
      while (bill.active && !bill.dueDate.isAfter(today) && guard++ < 60) {
        await _db.insert(
            'txns',
            Txn(
              type: TxType.expense,
              amount: bill.amount,
              categoryId: bill.categoryId,
              accountId: bill.accountId,
              date: bill.dueDate,
              note: bill.name,
              billId: bill.id,
              dueDate: bill.dueDate,
            ).toMap());
        bill = bill.recurring
            ? bill.copyWith(dueDate: bill.followingDue)
            : bill.copyWith(active: false);
        changed = true;
      }
      if (!identical(bill, b)) {
        await _db.update('bills', bill.toMap());
        await Notifier.instance.scheduleBill(bill);
      }
    }
    if (changed) await load();
  }

  // Lookups -------------------------------------------------------------------

  TxCategory? category(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Account? account(int? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<TxCategory> categoriesOf(TxType t) =>
      categories.where((c) => c.type == t).toList();

  List<Bill> get activeBills {
    final list = bills.where((b) => b.active).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<Bill> get overdueBills {
    final now = DateTime.now();
    return activeBills.where((b) => b.daysUntilDue(now) < 0).toList();
  }

  List<Bill> billsDueWithin(int days) {
    final now = DateTime.now();
    return activeBills.where((b) {
      final d = b.daysUntilDue(now);
      return d >= 0 && d <= days;
    }).toList();
  }

  /// Payments recorded against bills, newest first.
  List<Txn> get billPayments => txns.where((t) => t.billId != null).toList();

  Txn? lastPayment(Bill b) {
    for (final t in txns) {
      if (t.billId == b.id) return t;
    }
    return null;
  }

  /// Change vs the last payment for this bill (positive = increased).
  double? amountChange(Bill b) {
    final last = lastPayment(b);
    if (last == null) return null;
    final diff = b.amount - last.amount;
    return diff.abs() < 0.005 ? null : diff;
  }

  /// Upcoming (not overdue) due dates of all active bills up to [until].
  List<BillDue> upcomingDues(DateTime until) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <BillDue>[];
    for (final b in activeBills) {
      for (final d in b.occurrencesUntil(until)) {
        if (DateTime(d.year, d.month, d.day).isBefore(today)) continue;
        out.add(BillDue(b, d));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Unpaid amounts still due in [month] from today on.
  double upcomingInMonth(DateTime month) {
    final end = DateTime(month.year, month.month + 1, 0, 23, 59);
    return upcomingDues(end)
        .where((d) => d.date.year == month.year && d.date.month == month.month)
        .fold(0.0, (s, d) => s + d.bill.amount);
  }

  double billsPaidInMonth(DateTime month) => billPayments
      .where((t) => _sameMonth(t.date, month))
      .fold(0.0, (s, t) => s + t.amount);

  double get overdueTotal =>
      overdueBills.fold(0.0, (s, b) => s + b.amount);

  /// Total balance at the end of [month] (today's balance for this month).
  double balanceAt(DateTime month) {
    final end = DateTime(month.year, month.month + 1, 1);
    var bal = totalBalance;
    for (final t in txns) {
      if (t.accountId == null || account(t.accountId) == null) continue;
      if (!t.date.isBefore(end)) {
        bal -= t.type == TxType.income ? t.amount : -t.amount;
      }
    }
    return bal;
  }

  Map<int?, double> incomeByCategory(DateTime month) {
    final map = <int?, double>{};
    for (final t in txns) {
      if (t.type == TxType.income && _sameMonth(t.date, month)) {
        map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
      }
    }
    return map;
  }

  bool _sameMonth(DateTime a, DateTime m) =>
      a.year == m.year && a.month == m.month;

  List<Txn> txnsInMonth(DateTime month) =>
      txns.where((t) => _sameMonth(t.date, month)).toList();

  double expenseInMonth(DateTime month, {int? categoryId}) => txns
      .where((t) =>
          t.type == TxType.expense &&
          _sameMonth(t.date, month) &&
          (categoryId == null || t.categoryId == categoryId))
      .fold(0.0, (s, t) => s + t.amount);

  double incomeInMonth(DateTime month) => txns
      .where((t) => t.type == TxType.income && _sameMonth(t.date, month))
      .fold(0.0, (s, t) => s + t.amount);

  Map<int?, double> expenseByCategory(DateTime month) {
    final map = <int?, double>{};
    for (final t in txns) {
      if (t.type == TxType.expense && _sameMonth(t.date, month)) {
        map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
      }
    }
    return map;
  }

  double accountBalance(Account a) {
    var bal = a.openingBalance;
    for (final t in txns) {
      if (t.accountId != a.id) continue;
      bal += t.type == TxType.income ? t.amount : -t.amount;
    }
    return bal;
  }

  double get totalBalance =>
      accounts.fold(0.0, (s, a) => s + accountBalance(a));

  double goalProgress(Goal g) => goalEntries
      .where((e) => e.goalId == g.id)
      .fold(0.0, (s, e) => s + e.amount);

  List<GoalEntry> entriesFor(Goal g) =>
      goalEntries.where((e) => e.goalId == g.id).toList();

  Budget? overallBudget() {
    for (final b in budgets) {
      if (b.categoryId == null) return b;
    }
    return null;
  }

  List<Budget> get categoryBudgets =>
      budgets.where((b) => b.categoryId != null).toList();

  // Mutations -----------------------------------------------------------------

  Future<void> saveTxn(Txn t) async {
    if (t.id == null) {
      await _db.insert('txns', t.toMap());
    } else {
      await _db.update('txns', t.toMap());
    }
    await load();
  }

  Future<void> deleteTxn(Txn t) async {
    await _db.delete('txns', t.id!);
    await load();
  }

  Future<void> saveBill(Bill b) async {
    int id;
    if (b.id == null) {
      id = await _db.insert('bills', b.toMap());
    } else {
      id = b.id!;
      await _db.update('bills', b.toMap());
    }
    await load();
    final saved = bills.firstWhere((x) => x.id == id);
    await Notifier.instance.scheduleBill(saved);
  }

  Future<void> deleteBill(Bill b) async {
    await Notifier.instance.cancelBill(b.id!);
    await _db.delete('bills', b.id!);
    await load();
  }

  Future<void> markBillPaid(Bill b,
      {required double amount, required DateTime date, int? accountId}) async {
    await _db.insert(
        'txns',
        Txn(
          type: TxType.expense,
          amount: amount,
          categoryId: b.categoryId,
          accountId: accountId ?? b.accountId,
          date: date,
          note: b.name,
          billId: b.id,
          dueDate: b.dueDate,
        ).toMap());
    await _advanceBill(b);
  }

  Future<void> skipBill(Bill b) => _advanceBill(b);

  Future<void> _advanceBill(Bill b) async {
    final updated = b.repeat == Repeat.none
        ? b.copyWith(active: false)
        : b.copyWith(dueDate: b.followingDue);
    await _db.update('bills', updated.toMap());
    await load();
    await Notifier.instance.scheduleBill(updated);
  }

  List<Txn> paymentsFor(Bill b) => txns.where((t) => t.billId == b.id).toList();

  Future<void> saveBudget(Budget b) async {
    if (b.id == null) {
      await _db.insert('budgets', b.toMap());
    } else {
      await _db.update('budgets', b.toMap());
    }
    await load();
  }

  Future<void> deleteBudget(Budget b) async {
    await _db.delete('budgets', b.id!);
    await load();
  }

  Future<void> saveGoal(Goal g) async {
    if (g.id == null) {
      await _db.insert('goals', g.toMap());
    } else {
      await _db.update('goals', g.toMap());
    }
    await load();
  }

  Future<void> deleteGoal(Goal g) async {
    await _db.delete('goals', g.id!);
    await load();
  }

  Future<void> addGoalEntry(GoalEntry e) async {
    await _db.insert('goal_entries', e.toMap());
    await load();
  }

  Future<void> deleteGoalEntry(GoalEntry e) async {
    await _db.delete('goal_entries', e.id!);
    await load();
  }

  Future<void> saveCategory(TxCategory c) async {
    if (c.id == null) {
      await _db.insert('categories', c.toMap());
    } else {
      await _db.update('categories', c.toMap());
    }
    await load();
  }

  Future<void> deleteCategory(TxCategory c) async {
    await _db.delete('categories', c.id!);
    await load();
  }

  Future<void> saveAccount(Account a) async {
    if (a.id == null) {
      await _db.insert('accounts', a.toMap());
    } else {
      await _db.update('accounts', a.toMap());
    }
    await load();
  }

  Future<void> deleteAccount(Account a) async {
    await _db.delete('accounts', a.id!);
    await load();
  }

  Future<void> setCurrency(String symbol) async {
    await _db.setSetting('currency', symbol);
    await load();
    await Notifier.instance.rescheduleAll(activeBills);
  }

  Future<void> setUserName(String name) async {
    await _db.setSetting('name', name.trim());
    userName = name.trim();
    notifyListeners();
  }

  Future<void> setIncomeBudget(double? v) async {
    await _db.setSetting('income_budget', v?.toString() ?? '');
    incomeBudget = v;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    await _db.setSetting('theme', m.index.toString());
    themeMode = m;
    notifyListeners();
  }

  Future<void> wipeData() async {
    await _db.wipe();
    await load();
    await Notifier.instance.rescheduleAll(const []);
  }
}

class BillDue {
  final Bill bill;
  final DateTime date;
  const BillDue(this.bill, this.date);

  /// True for the bill's current due date (the one that can be marked paid).
  bool get isCurrent => date == bill.dueDate;
}
