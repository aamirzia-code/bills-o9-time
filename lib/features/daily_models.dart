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
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'person_id': personId,
        'amount': amount,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'grp': group,
        'kind': kind.index,
      };
  factory Iou.fromMap(Map<String, Object?> m) => Iou(
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
