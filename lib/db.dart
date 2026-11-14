import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_factory_stub.dart' if (dart.library.js_interop) 'db_factory_web.dart';

import 'models.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async => _db ??= await _openAndMaybeDemo();

  Future<Database> _openAndMaybeDemo() async {
    final d = await _open();
    // Web preview only: open the app with ?demo=1 to fill an empty database
    // with sample data (used for screenshots and trying the app out).
    if (kIsWeb && Uri.base.queryParameters['demo'] == '1') {
      final n = Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM bills'));
      if ((n ?? 0) == 0) await _seedDemo(d);
    }
    return d;
  }

  Future<void> _seedDemo(Database d) async {
    Future<int?> cat(String name) async {
      final r = await d.query('categories', where: 'name = ?', whereArgs: [name], limit: 1);
      return r.isEmpty ? null : r.first['id'] as int;
    }
    final now = DateTime.now();
    DateTime on(int monthOffset, int day) =>
        dateForDueDay(now.year, now.month + monthOffset, day);
    final bank = (await d.query('accounts', where: 'kind = ?', whereArgs: ['Bank'], limit: 1)).first['id'] as int;
    final cash = (await d.query('accounts', where: 'kind = ?', whereArgs: ['Cash'], limit: 1)).first['id'] as int;
    await d.update('accounts', {'opening_balance': 250000}, where: 'id = ?', whereArgs: [bank]);
    await d.update('accounts', {'opening_balance': 40000}, where: 'id = ?', whereArgs: [cash]);

    final bills = [
      // name, amount, category, day, monthOffset, every, autoPay, lastPaid
      ['House Rent', 46000.0, 'Rent', 10, 1, 1, 0, 46000.0],
      ['Electricity', 15000.0, 'Electricity', 24, 0, 1, 0, 5700.0],
      ['Gas', 2500.0, 'Gas', 10, 1, 1, 0, 2500.0],
      ['Internet', 3500.0, 'Internet', now.day + 2, 0, 2, 0, 3204.0],
      ['Mobile Package', 1500.0, 'Mobile', 1, 1, 1, 1, 1500.0],
      ['Credit Card', 100000.0, 'Credit Card', 27, 0, 1, 0, 55000.0],
      ['School Fee', 37000.0, 'Education', 8, 1, 1, 0, 37000.0],
      ['Car Installment', 18000.0, 'Loan / EMI', 5, 0, 1, 0, 18000.0],
      ['Fuel Card', 12000.0, 'Fuel', now.day + 1, 0, 1, 0, 12000.0],
      ['Cloud Storage', 2500.0, 'Subscriptions', 1, 1, 3, 1, 2500.0],
    ];
    for (final b in bills) {
      var due = on(b[4] as int, b[3] as int);
      if ((b[0] as String) == 'Car Installment') due = on(-1, 5); // overdue
      final id = await d.insert('bills', {
        'name': b[0], 'amount': b[1], 'category_id': await cat(b[2] as String),
        'account_id': bank, 'due_date': due.millisecondsSinceEpoch,
        'repeat': Repeat.monthly.index, 'due_day': (b[3] as int).clamp(1, 28),
        'repeat_every': b[5], 'auto_pay': b[6], 'remind_days': 2, 'notes': '', 'active': 1,
      });
      final prevDue = DateTime(due.year, due.month - (b[5] as int), due.day, 9);
      await d.insert('txns', {
        'type': TxType.expense.index, 'amount': b[7], 'category_id': await cat(b[2] as String),
        'account_id': bank, 'date': prevDue.add(const Duration(days: 1)).millisecondsSinceEpoch,
        'note': b[0], 'bill_id': id, 'due_date': prevDue.millisecondsSinceEpoch,
      });
    }
    final spends = [
      ['Groceries', 'Weekly groceries', 9800.0, 2],
      ['Food & Dining', 'Dinner out', 6500.0, 5],
      ['Fuel', 'Petrol', 7000.0, 6],
      ['Groceries', 'Milk & bread', 1800.0, 8],
      ['Shopping', 'Clothes', 14500.0, 9],
      ['Health', 'Pharmacy', 3200.0, 11],
      ['Transport', 'Ride hailing', 2100.0, 12],
    ];
    for (var m = -5; m <= 0; m++) {
      await d.insert('txns', {
        'type': TxType.income.index, 'amount': 380000.0 + (m * 4000), 'category_id': await cat('Salary'),
        'account_id': bank, 'date': on(m, 1).millisecondsSinceEpoch, 'note': 'Salary',
      });
      for (final x in spends) {
        final day = x[3] as int;
        if (m == 0 && day > now.day) continue;
        await d.insert('txns', {
          'type': TxType.expense.index,
          'amount': (x[2] as double) * (1 + (m % 3) * 0.12),
          'category_id': await cat(x[0] as String),
          'account_id': day.isEven ? bank : cash,
          'date': on(m, day).millisecondsSinceEpoch, 'note': x[1],
        });
      }
    }
    await d.insert('budgets', {'category_id': null, 'amount': 300000.0});
    await d.insert('budgets', {'category_id': await cat('Groceries'), 'amount': 20000.0});
    await d.insert('budgets', {'category_id': await cat('Food & Dining'), 'amount': 8000.0});
    final g = await d.insert('goals', {
      'name': 'Buy a car', 'kind': GoalKind.saving.index, 'target': 2500000.0, 'interest': 0,
      'deadline': on(18, 1).millisecondsSinceEpoch, 'color': 0xFF2563EB, 'icon': 'car',
    });
    await d.insert('goal_entries', {'goal_id': g, 'amount': 600000.0, 'date': on(-2, 3).millisecondsSinceEpoch, 'note': ''});
    final debt = await d.insert('goals', {
      'name': 'Payoff debt', 'kind': GoalKind.debt.index, 'target': 300000.0, 'interest': 18,
      'deadline': on(10, 1).millisecondsSinceEpoch, 'color': 0xFFDC2626, 'icon': 'debt',
    });
    await d.insert('goal_entries', {'goal_id': debt, 'amount': 90000.0, 'date': on(-1, 3).millisecondsSinceEpoch, 'note': ''});
    await d.insert('settings', {'key': 'name', 'value': 'Aamir'},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database> _open() async {
    final factory = appDatabaseFactory;
    final path = kIsWeb
        ? 'bills_o9_time.db'
        : p.join(await factory.getDatabasesPath(), 'bills_o9_time.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, type INTEGER NOT NULL,
            icon TEXT NOT NULL, color INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, kind TEXT NOT NULL,
            opening_balance REAL NOT NULL DEFAULT 0, color INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, amount REAL NOT NULL,
            category_id INTEGER, account_id INTEGER,
            due_date INTEGER NOT NULL, repeat INTEGER NOT NULL,
            due_day INTEGER NOT NULL DEFAULT 0,
            repeat_every INTEGER NOT NULL DEFAULT 1,
            auto_pay INTEGER NOT NULL DEFAULT 0,
            remind_days INTEGER NOT NULL DEFAULT 2,
            notes TEXT, active INTEGER NOT NULL DEFAULT 1)''');
        await db.execute('''
          CREATE TABLE txns(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL, amount REAL NOT NULL,
            category_id INTEGER, account_id INTEGER,
            date INTEGER NOT NULL, note TEXT, bill_id INTEGER,
            due_date INTEGER)''');
        await db.execute('''
          CREATE TABLE budgets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER, amount REAL NOT NULL)''');
        await db.execute('''
          CREATE TABLE goals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, kind INTEGER NOT NULL,
            target REAL NOT NULL, interest REAL NOT NULL DEFAULT 0,
            deadline INTEGER, color INTEGER NOT NULL, icon TEXT)''');
        await db.execute('''
          CREATE TABLE goal_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
            amount REAL NOT NULL, date INTEGER NOT NULL, note TEXT)''');
        await db.execute('''
          CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)''');
        await _seed(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // v2: bills remember the day of the month they're due on.
          await db.execute(
              'ALTER TABLE bills ADD COLUMN due_day INTEGER NOT NULL DEFAULT 0');
          final rows = await db.query('bills', columns: ['id', 'due_date', 'repeat']);
          for (final r in rows) {
            final rep = Repeat.values[r['repeat'] as int];
            if (!repeatsByMonth(rep)) continue;
            final d = DateTime.fromMillisecondsSinceEpoch(r['due_date'] as int);
            await db.update('bills', {'due_day': d.day},
                where: 'id = ?', whereArgs: [r['id']]);
          }
        }
        if (oldV < 3) {
          // v3: repeat every N, auto-paid bills, paid-for date, goal icons.
          await db.execute('ALTER TABLE bills ADD COLUMN repeat_every INTEGER NOT NULL DEFAULT 1');
          await db.execute('ALTER TABLE bills ADD COLUMN auto_pay INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE txns ADD COLUMN due_date INTEGER');
          await db.execute('ALTER TABLE goals ADD COLUMN icon TEXT');
          // Fold legacy presets into "every N" form.
          await db.rawUpdate('UPDATE bills SET repeat = ?, repeat_every = 2 WHERE repeat = ?',
              [Repeat.weekly.index, Repeat.biweekly.index]);
          await db.rawUpdate('UPDATE bills SET repeat = ?, repeat_every = 3 WHERE repeat = ?',
              [Repeat.monthly.index, Repeat.quarterly.index]);
        }
      },
      ),
    );
  }

  Future<void> _seed(Database db) async {
    const expense = [
      ['Rent', 'home', 0xFF475569],
      ['Electricity', 'bolt', 0xFFCA8A04],
      ['Gas', 'gas', 0xFFEA580C],
      ['Water', 'water', 0xFF0891B2],
      ['Internet', 'wifi', 0xFF2563EB],
      ['Mobile', 'phone', 0xFF7C3AED],
      ['Subscriptions', 'subscription', 0xFFDB2777],
      ['Groceries', 'grocery', 0xFF16A34A],
      ['Food & Dining', 'food', 0xFFEA580C],
      ['Fuel', 'fuel', 0xFFDC2626],
      ['Transport', 'car', 0xFF0F766E],
      ['Shopping', 'shopping', 0xFFDB2777],
      ['Health', 'health', 0xFFDC2626],
      ['Education', 'school', 0xFF2563EB],
      ['Credit Card', 'card', 0xFF7C3AED],
      ['Loan / EMI', 'loan', 0xFF475569],
      ['Insurance', 'insurance', 0xFF0891B2],
      ['Family', 'family', 0xFF16A34A],
      ['Entertainment', 'fun', 0xFFCA8A04],
      ['Other', 'other', 0xFF475569],
    ];
    const income = [
      ['Salary', 'salary', 0xFF16A34A],
      ['Business', 'business', 0xFF0F766E],
      ['Investments', 'invest', 0xFF2563EB],
      ['Gifts', 'gift', 0xFFDB2777],
      ['Other Income', 'other', 0xFF475569],
    ];
    final batch = db.batch();
    for (final c in expense) {
      batch.insert('categories', {
        'name': c[0],
        'type': TxType.expense.index,
        'icon': c[1],
        'color': c[2],
      });
    }
    for (final c in income) {
      batch.insert('categories', {
        'name': c[0],
        'type': TxType.income.index,
        'icon': c[1],
        'color': c[2],
      });
    }
    batch.insert('accounts', {
      'name': 'Cash',
      'kind': 'Cash',
      'opening_balance': 0,
      'color': 0xFF16A34A,
    });
    batch.insert('accounts', {
      'name': 'Bank',
      'kind': 'Bank',
      'opening_balance': 0,
      'color': 0xFF2563EB,
    });
    batch.insert('settings', {'key': 'currency', 'value': 'Rs'});
    await batch.commit(noResult: true);
  }

  // Generic helpers ---------------------------------------------------------

  Future<List<Map<String, Object?>>> all(String table, {String? orderBy}) async =>
      (await db).query(table, orderBy: orderBy);

  Future<int> insert(String table, Map<String, Object?> data) async {
    final m = Map<String, Object?>.from(data)..remove('id');
    return (await db).insert(table, m);
  }

  Future<void> update(String table, Map<String, Object?> data) async {
    await (await db)
        .update(table, data, where: 'id = ?', whereArgs: [data['id']]);
  }

  Future<void> delete(String table, int id) async {
    await (await db).delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getSetting(String key) async {
    final r = await (await db)
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await (await db).insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> wipe() async {
    final d = await db;
    for (final t in ['txns', 'bills', 'budgets', 'goal_entries', 'goals']) {
      await d.delete(t);
    }
  }
}
