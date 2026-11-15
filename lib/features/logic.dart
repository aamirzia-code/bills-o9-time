import 'package:intl/intl.dart';

import '../models.dart';

// ------------------------------------------------------------ Subscriptions

class SubscriptionGuess {
  final String name;
  final double amount;
  final DateTime last;
  final int count;
  final Repeat repeat;
  final int? categoryId;
  const SubscriptionGuess(this.name, this.amount, this.last, this.count,
      this.repeat, this.categoryId);
}

/// Finds expenses that repeat (same description, similar amount, regular
/// gap) but aren't set up as bills yet.
List<SubscriptionGuess> findSubscriptions(List<Txn> txns, List<Bill> bills) {
  final billNames = {for (final b in bills) b.name.trim().toLowerCase()};
  final groups = <String, List<Txn>>{};
  for (final t in txns) {
    if (t.type != TxType.expense || t.billId != null) continue;
    final key = t.note.trim().toLowerCase();
    if (key.length < 3 || billNames.contains(key)) continue;
    // Everyday spending repeats too; only look at subscription-like names.
    if (RegExp(r'grocer|food|dinner|lunch|fuel|petrol|cloth|shopping|pharmacy|ride|taxi|careem|uber|bykea|milk|bread')
        .hasMatch(key)) {
      continue;
    }
    groups.putIfAbsent(key, () => []).add(t);
  }
  final out = <SubscriptionGuess>[];
  for (final g in groups.values) {
    if (g.length < 3) continue;
    g.sort((a, b) => a.date.compareTo(b.date));
    final amounts = g.map((t) => t.amount).toList()..sort();
    final median = amounts[amounts.length ~/ 2];
    if (median <= 0) continue;
    final similar = g.where((t) => (t.amount - median).abs() <= median * 0.08).toList();
    if (similar.length < 3) continue;
    final gaps = <int>[
      for (var i = 1; i < similar.length; i++)
        similar[i].date.difference(similar[i - 1].date).inDays
    ]..sort();
    final gap = gaps[gaps.length ~/ 2];
    Repeat? rep;
    if (gap >= 25 && gap <= 35) rep = Repeat.monthly;
    if (gap >= 6 && gap <= 8) rep = Repeat.weekly;
    if (gap >= 350 && gap <= 380) rep = Repeat.yearly;
    if (rep == null) continue;
    final months = {for (final t in similar) '${t.date.year}-${t.date.month}'};
    if (rep == Repeat.monthly && months.length < 3) continue;
    out.add(SubscriptionGuess(similar.last.note.trim(), median, similar.last.date,
        similar.length, rep, similar.last.categoryId));
  }
  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}

// ------------------------------------------------------------ Calendar (.ics)

String _icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// iCalendar file with every active bill as a (repeating) event at
/// [hour]:00 plus alerts [Bill.remindDaysBefore] days before and on the day.
String buildIcs(List<Bill> bills,
    {required String Function(double) money, int hour = 9, DateTime? now}) {
  final stamp = DateFormat("yyyyMMdd'T'HHmmss'Z'").format((now ?? DateTime.now()).toUtc());
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Bills O9 Time//EN')
    ..writeln('CALSCALE:GREGORIAN')
    ..writeln('X-WR-CALNAME:Bills O9 Time');
  for (final bill in bills.where((x) => x.active)) {
    final d = bill.dueDate;
    final start = DateFormat("yyyyMMdd'T'HHmmss")
        .format(DateTime(d.year, d.month, d.day, hour));
    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:bill-${bill.id ?? bill.name.hashCode}@bills-o9-time')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:$start')
      ..writeln('DURATION:PT15M')
      ..writeln('SUMMARY:${_icsEscape('${bill.name} · ${money(bill.amount)}')}')
      ..writeln('DESCRIPTION:${_icsEscape([
            'Bill due: ${money(bill.amount)}',
            if (bill.refNo.isNotEmpty) 'Ref: ${bill.refNo}',
            'From Bills O9 Time'
          ].join('\n'))}');
    final rule = _rrule(bill);
    if (rule != null) b.writeln('RRULE:$rule');
    if (bill.remindDaysBefore > 0) {
      b
        ..writeln('BEGIN:VALARM')
        ..writeln('ACTION:DISPLAY')
        ..writeln('DESCRIPTION:${_icsEscape('${bill.name} due soon')}')
        ..writeln('TRIGGER:-P${bill.remindDaysBefore}D')
        ..writeln('END:VALARM');
    }
    b
      ..writeln('BEGIN:VALARM')
      ..writeln('ACTION:DISPLAY')
      ..writeln('DESCRIPTION:${_icsEscape('${bill.name} is due today')}')
      ..writeln('TRIGGER:PT0M')
      ..writeln('END:VALARM')
      ..writeln('END:VEVENT');
  }
  b.writeln('END:VCALENDAR');
  return b.toString().replaceAll('\n', '\r\n');
}

String? _rrule(Bill bill) {
  final (base, n) = normalizeRepeat(bill.repeat, bill.every);
  final interval = n > 1 ? ';INTERVAL=$n' : '';
  switch (base) {
    case Repeat.none:
      return null;
    case Repeat.daily:
      return 'FREQ=DAILY$interval';
    case Repeat.weekly:
    case Repeat.biweekly:
      return 'FREQ=WEEKLY$interval';
    case Repeat.monthly:
    case Repeat.quarterly:
      final day = bill.dueDay == kLastDay
          ? -1
          : (bill.dueDay > 0 ? bill.dueDay : bill.dueDate.day);
      // Days 29-31 fall back to the month's last day in short months.
      if (day > 28) return 'FREQ=MONTHLY$interval;BYMONTHDAY=$day,-1;BYSETPOS=1';
      return 'FREQ=MONTHLY$interval;BYMONTHDAY=$day';
    case Repeat.yearly:
      return 'FREQ=YEARLY$interval';
  }
}

// ------------------------------------------------------------ Bank SMS

class ParsedSms {
  final double? amount;
  final TxType type;
  final DateTime? date;
  final String? merchant;
  final String? last4;
  final String? currency;
  const ParsedSms(
      {this.amount,
      this.type = TxType.expense,
      this.date,
      this.merchant,
      this.last4,
      this.currency});
}

final _amountRe = RegExp(
    r'(PKR|Rs\.?|RS\.?|AED|SAR|QAR|OMR|KWD|BHD|USD|\$)\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
    caseSensitive: false);
final _amountAfterRe = RegExp(
    r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s?(PKR|AED|SAR|QAR|OMR|KWD|BHD|USD)\b',
    caseSensitive: false);
const _creditWords = [
  'credited', 'received', 'deposit', 'deposited', 'refund', 'salary',
  'cash in', 'transferred to your', 'has been added'
];
const _debitWords = [
  'debited', 'spent', 'paid', 'payment', 'purchase', 'withdrawn',
  'withdrawal', 'charged', 'sent', 'transferred', 'pos', 'cash out', 'bill'
];

/// Reads amount, debit/credit, date, merchant and card/account digits from a
/// bank or wallet alert (HBL, Meezan, UBL, JazzCash, Easypaisa, Emirates
/// NBD and similar formats).
ParsedSms parseBankSms(String text, {DateTime? now}) {
  final t = text.replaceAll('\n', ' ');
  final lower = t.toLowerCase();

  double? amount;
  String? currency;
  final m = _amountRe.firstMatch(t);
  final m2 = _amountAfterRe.firstMatch(t);
  if (m != null) {
    currency = m.group(1)!.toUpperCase().replaceAll('.', '');
    amount = double.tryParse(m.group(2)!.replaceAll(',', ''));
  } else if (m2 != null) {
    currency = m2.group(2)!.toUpperCase();
    amount = double.tryParse(m2.group(1)!.replaceAll(',', ''));
  }
  if (currency == 'RS') currency = 'PKR';

  int firstIndex(List<String> words) {
    var best = -1;
    for (final w in words) {
      final i = lower.indexOf(w);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  final ci = firstIndex(_creditWords);
  final di = firstIndex(_debitWords);
  final type = (ci >= 0 && (di < 0 || ci < di)) ? TxType.income : TxType.expense;

  String? last4;
  final acc = RegExp(r'(?:a/c|acct|account|card|ending|no\.?)\s*(?:no\.?|number)?\s*[:#]?\s*[*xX]*\s*(\d{3,4})\b',
          caseSensitive: false)
      .firstMatch(t);
  if (acc != null) last4 = acc.group(1);

  String? merchant;
  final mm = RegExp(
          r"\b(?:at|to|from)\s+([A-Za-z0-9&.'\- ]{2,40}?)(?=\s+(?:on|via|using|ref|dated|for|from|at|with)\b|[.,;]|\s*$)",
          caseSensitive: false)
      .firstMatch(t);
  if (mm != null) {
    final cand = mm.group(1)!.trim();
    if (!RegExp(r'^(your|a/c|account|card|ac)\b', caseSensitive: false)
        .hasMatch(cand)) {
      merchant = cand;
    }
  }

  DateTime? date;
  final ref = now ?? DateTime.now();
  final d1 = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b').firstMatch(t);
  final d2 = RegExp(r'\b(\d{1,2})[- ]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[- ,]*(\d{2,4})?\b',
          caseSensitive: false)
      .firstMatch(t);
  if (d1 != null) {
    var y = int.parse(d1.group(3)!);
    if (y < 100) y += 2000;
    final dd = int.parse(d1.group(1)!);
    final mo = int.parse(d1.group(2)!);
    if (mo >= 1 && mo <= 12 && dd >= 1 && dd <= 31) date = DateTime(y, mo, dd, 12);
  } else if (d2 != null) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final mo = months.indexOf(d2.group(2)!.toLowerCase().substring(0, 3)) + 1;
    var y = int.tryParse(d2.group(3) ?? '') ?? ref.year;
    if (y < 100) y += 2000;
    date = DateTime(y, mo, int.parse(d2.group(1)!), 12);
  }
  if (date != null && date.isAfter(ref.add(const Duration(days: 2)))) date = null;

  return ParsedSms(
      amount: amount,
      type: type,
      date: date,
      merchant: merchant,
      last4: last4,
      currency: currency);
}

// ------------------------------------------------------------ Zakat

/// Nisab weights (grams). 7.5 tola gold, 52.5 tola silver.
const nisabGoldGrams = 87.48;
const nisabSilverGrams = 612.36;
const gramsPerTola = 11.664;

class ZakatResult {
  final double assets;
  final double liabilities;
  final double net;
  final double nisab;
  final bool due;
  final double zakat;
  const ZakatResult(this.assets, this.liabilities, this.net, this.nisab, this.due, this.zakat);
}

ZakatResult computeZakat({
  required double cashAndBank,
  required double savings,
  required double goldGrams,
  required double silverGrams,
  required double goldPricePerGram,
  required double silverPricePerGram,
  required double otherAssets,
  required double receivables,
  required double liabilities,
  required bool silverNisab,
}) {
  final assets = cashAndBank +
      savings +
      goldGrams * goldPricePerGram +
      silverGrams * silverPricePerGram +
      otherAssets +
      receivables;
  final net = assets - liabilities;
  final nisab = silverNisab
      ? nisabSilverGrams * silverPricePerGram
      : nisabGoldGrams * goldPricePerGram;
  final due = nisab > 0 && net >= nisab;
  return ZakatResult(assets, liabilities, net, nisab, due, due ? net * 0.025 : 0);
}
