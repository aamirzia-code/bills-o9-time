import 'dart:convert';
// Models for the everyday tools. All stored on the device only.

class Person {
  final int? id;
  final String name;
  final String phone;
  final int color;
  const Person({this.id, required this.name, this.phone = '', required this.color});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'phone': phone, 'color': color};
  factory Person.fromMap(Map<String, Object?> m) => Person(
        id: m['id'] as int,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        color: m['color'] as int,
      );
}

/// One line in the split / udhaar ledger.
/// [amount] > 0: they owe me. [amount] < 0: I owe them.
enum IouKind { split, loan, settle }

class Iou {
  final int? id;
  final int personId;
  final double amount;
  final String note;
  final DateTime date;
  final String group;
  final IouKind kind;
  const Iou({
    this.id,
    required this.personId,
    required this.amount,
    this.note = '',
    required this.date,
    this.group = '',
    this.kind = IouKind.split,
    this.splitId,
  });
  final int? splitId;

  Map<String, Object?> toMap() => {
        'id': id,
        'person_id': personId,
        'amount': amount,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'grp': group,
        'kind': kind.index,
        'split_id': splitId,
      };
  factory Iou.fromMap(Map<String, Object?> m) => Iou(
        splitId: m['split_id'] as int?,
        id: m['id'] as int,
        personId: m['person_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        note: (m['note'] as String?) ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        group: (m['grp'] as String?) ?? '',
        kind: IouKind.values[(m['kind'] as int?) ?? 0],
      );
}

class ShopList {
  final int? id;
  final String name;
  final DateTime created;
  const ShopList({this.id, required this.name, required this.created});
  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'created': created.millisecondsSinceEpoch};
  factory ShopList.fromMap(Map<String, Object?> m) => ShopList(
        id: m['id'] as int,
        name: m['name'] as String,
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      );
}

class ListItem {
  final int? id;
  final int listId;
  final String name;
  final double qty;
  final double price; // per unit, optional
  final bool done;
  final DateTime created;
  const ListItem({
    this.id,
    required this.listId,
    required this.name,
    this.qty = 1,
    this.price = 0,
    this.done = false,
    required this.created,
  });
  double get total => qty * price;
  ListItem copyWith({bool? done, double? price, double? qty}) => ListItem(
        id: id,
        listId: listId,
        name: name,
        qty: qty ?? this.qty,
        price: price ?? this.price,
        done: done ?? this.done,
        created: created,
      );
  Map<String, Object?> toMap() => {
        'id': id,
        'list_id': listId,
        'name': name,
        'qty': qty,
        'price': price,
        'done': done ? 1 : 0,
        'created': created.millisecondsSinceEpoch,
      };
  factory ListItem.fromMap(Map<String, Object?> m) => ListItem(
        id: m['id'] as int,
        listId: m['list_id'] as int,
        name: m['name'] as String,
        qty: (m['qty'] as num).toDouble(),
        price: (m['price'] as num).toDouble(),
        done: (m['done'] as int) == 1,
        created: DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      );
}

/// Anything that expires: car token, insurance, CNIC/passport/visa,
/// warranties, subscriptions, domain…
class Renewal {
  final int? id;
  final String name;
  final String kind;
  final DateTime expiry;
  final int remindDays;
  final double cost;
  final int everyYears; // 0 = doesn't repeat
  final String notes;
  const Renewal({
    this.id,
    required this.name,
    required this.kind,
    required this.expiry,
    this.remindDays = 14,
    this.cost = 0,
    this.everyYears = 1,
    this.notes = '',
  });

  int daysLeft([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(expiry.year, expiry.month, expiry.day)
        .difference(DateTime(n.year, n.month, n.day))
        .inDays;
  }

  Renewal renewed() => Renewal(
        id: id,
        name: name,
        kind: kind,
        expiry: DateTime(expiry.year + (everyYears < 1 ? 1 : everyYears),
            expiry.month, expiry.day),
        remindDays: remindDays,
        cost: cost,
        everyYears: everyYears,
        notes: notes,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'expiry': expiry.millisecondsSinceEpoch,
        'remind_days': remindDays,
        'cost': cost,
        'every_years': everyYears,
        'notes': notes,
      };
  factory Renewal.fromMap(Map<String, Object?> m) => Renewal(
        id: m['id'] as int,
        name: m['name'] as String,
        kind: m['kind'] as String,
        expiry: DateTime.fromMillisecondsSinceEpoch(m['expiry'] as int),
        remindDays: (m['remind_days'] as int?) ?? 14,
        cost: ((m['cost'] as num?) ?? 0).toDouble(),
        everyYears: (m['every_years'] as int?) ?? 1,
        notes: (m['notes'] as String?) ?? '',
      );
}

class MeterReading {
  final int? id;
  final String meter; // electricity | gas | water
  final DateTime date;
  final double reading;
  const MeterReading(
      {this.id, required this.meter, required this.date, required this.reading});
  Map<String, Object?> toMap() => {
        'id': id,
        'meter': meter,
        'date': date.millisecondsSinceEpoch,
        'reading': reading,
      };
  factory MeterReading.fromMap(Map<String, Object?> m) => MeterReading(
        id: m['id'] as int,
        meter: m['meter'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        reading: (m['reading'] as num).toDouble(),
      );
}

class FuelLog {
  final int? id;
  final String vehicle;
  final DateTime date;
  final double litres;
  final double price; // per litre
  final double odometer;
  final int? txnId;
  const FuelLog({
    this.id,
    required this.vehicle,
    required this.date,
    required this.litres,
    required this.price,
    this.odometer = 0,
    this.txnId,
  });
  double get cost => litres * price;
  Map<String, Object?> toMap() => {
        'id': id,
        'vehicle': vehicle,
        'date': date.millisecondsSinceEpoch,
        'litres': litres,
        'price': price,
        'odometer': odometer,
        'txn_id': txnId,
      };
  factory FuelLog.fromMap(Map<String, Object?> m) => FuelLog(
        id: m['id'] as int,
        vehicle: m['vehicle'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        litres: (m['litres'] as num).toDouble(),
        price: (m['price'] as num).toDouble(),
        odometer: ((m['odometer'] as num?) ?? 0).toDouble(),
        txnId: m['txn_id'] as int?,
      );
}


/// How a split bill is divided.
enum SplitMode { equal, exact, percent, shares }

/// One person's part of a split bill. [person] is -1 for me.
class SplitPart {
  final int person;
  final double value; // what was typed: amount, % or number of shares
  final double amount; // resulting share of the bill
  const SplitPart(this.person, this.value, this.amount);
  List<num> toJson() => [person, value, double.parse(amount.toStringAsFixed(2))];
  factory SplitPart.fromJson(List j) =>
      SplitPart((j[0] as num).toInt(), (j[1] as num).toDouble(), (j[2] as num).toDouble());
}

/// Works out each person's share. Rounding leftovers go to the payer's row
/// (or the first row) so parts always add up to the total.
List<SplitPart> computeParts(double total, SplitMode mode, List<int> people,
    Map<int, double> values, {int payer = -1}) {
  if (people.isEmpty) return const [];
  final raw = <int, double>{};
  switch (mode) {
    case SplitMode.equal:
      for (final p in people) {
        raw[p] = total / people.length;
      }
    case SplitMode.exact:
      for (final p in people) {
        raw[p] = values[p] ?? 0;
      }
    case SplitMode.percent:
      for (final p in people) {
        raw[p] = total * (values[p] ?? 0) / 100;
      }
    case SplitMode.shares:
      final sum = people.fold<double>(0, (a, p) => a + (values[p] ?? 1));
      for (final p in people) {
        raw[p] = sum == 0 ? 0 : total * (values[p] ?? 1) / sum;
      }
  }
  final rounded = {for (final e in raw.entries) e.key: (e.value * 100).round() / 100};
  if (mode == SplitMode.equal || mode == SplitMode.shares) {
    final diff = total - rounded.values.fold<double>(0, (a, b) => a + b);
    final k = rounded.containsKey(payer) ? payer : people.first;
    rounded[k] = ((rounded[k]! + diff) * 100).round() / 100;
  }
  return [
    for (final p in people)
      SplitPart(p, mode == SplitMode.shares ? (values[p] ?? 1) : (values[p] ?? 0), rounded[p]!)
  ];
}

class SplitBill {
  final int? id;
  final String title;
  final double total;
  final DateTime date;
  final int payer; // -1 = me, else person id
  final SplitMode mode;
  final String group;
  final List<SplitPart> parts;
  final Set<int> settled; // person ids who have paid back
  const SplitBill({
    this.id,
    required this.title,
    required this.total,
    required this.date,
    this.payer = -1,
    this.mode = SplitMode.equal,
    this.group = '',
    required this.parts,
    this.settled = const {},
  });

  double get assigned => parts.fold(0, (a, p) => a + p.amount);

  /// Parts still owed to the payer.
  Iterable<SplitPart> get owing =>
      parts.where((p) => p.person != payer && !settled.contains(p.person) && p.amount > 0);

  double get outstanding => owing.fold(0, (a, p) => a + p.amount);

  SplitBill copyWith({Set<int>? settled}) => SplitBill(
      id: id,
      title: title,
      total: total,
      date: date,
      payer: payer,
      mode: mode,
      group: group,
      parts: parts,
      settled: settled ?? this.settled);

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'total': total,
        'date': date.millisecondsSinceEpoch,
        'payer': payer,
        'mode': mode.index,
        'grp': group,
        'parts': jsonEncode([for (final p in parts) p.toJson()]),
        'settled': jsonEncode(settled.toList()),
      };

  factory SplitBill.fromMap(Map<String, Object?> m) => SplitBill(
        id: m['id'] as int,
        title: m['title'] as String,
        total: (m['total'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        payer: (m['payer'] as int?) ?? -1,
        mode: SplitMode.values[((m['mode'] as int?) ?? 0).clamp(0, SplitMode.values.length - 1)],
        group: (m['grp'] as String?) ?? '',
        parts: [
          for (final j in (jsonDecode(m['parts'] as String) as List)) SplitPart.fromJson(j as List)
        ],
        settled: {
          for (final x in (jsonDecode((m['settled'] as String?) ?? '[]') as List)) (x as num).toInt()
        },
      );
}
