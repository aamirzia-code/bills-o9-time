import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_form.dart';

const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);
const _amber = Color(0xFFF5B000);

String _dayDiffText(int days) {
  if (days < 0) return days == -1 ? '1 Day past' : '${-days} Days past';
  if (days == 0) return 'Today';
  return days == 1 ? '1 Day' : '$days Days';
}

String _whenText(DateTime d, DateTime now) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return Fmt.shortDate(d);
}

int _daysFromToday(DateTime d) {
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

String _monthGroupLabel(DateTime d) {
  final now = DateTime.now();
  final diff = (d.year - now.year) * 12 + d.month - now.month;
  if (diff == 0) return 'This month';
  if (diff == 1) return 'Next month';
  if (diff == -1) return 'Last month';
  return d.year == now.year
      ? DateFormat('MMMM').format(d)
      : DateFormat('MMM yyyy').format(d);
}

bool _matches(String q, String name) =>
    q.isEmpty || name.toLowerCase().contains(q.toLowerCase());

class BillsScreen extends StatefulWidget {
  final int initialTab;
  const BillsScreen({super.key, this.initialTab = 0});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 5, vsync: this, initialIndex: widget.initialTab.clamp(0, 4));
  String _q = '';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final hasOverdue = s.overdueBills.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'UPCOMING'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OVERDUE'),
                  if (hasOverdue)
                    Container(
                      margin: const EdgeInsets.only(left: 4, bottom: 8),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _red, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
            const Tab(text: 'CALENDAR'),
            const Tab(text: 'RECURRING'),
            const Tab(text: 'PAID'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'bills-fab',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BillForm())),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _UpcomingView(
              q: _q,
              onSearch: (v) => setState(() => _q = v),
              onOverdue: () => _tabs.animateTo(1)),
          _OverdueView(q: _q, onSearch: (v) => setState(() => _q = v)),
          const _CalendarView(),
          _RecurringView(q: _q, onSearch: (v) => setState(() => _q = v)),
          _PaidView(q: _q, onSearch: (v) => setState(() => _q = v)),
        ],
      ),
    );
  }
}

Widget _listWithSearch(
    {required ValueChanged<String> onSearch, required List<Widget> children}) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    children: [SearchField(onChanged: onSearch), ...children],
  );
}

// ---------------------------------------------------------------- Upcoming

class _UpcomingView extends StatelessWidget {
  final String q;
  final ValueChanged<String> onSearch;
  final VoidCallback onOverdue;
  const _UpcomingView(
      {required this.q, required this.onSearch, required this.onOverdue});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final until = DateTime(now.year, now.month + 4, 0, 23, 59);
    final dues =
        s.upcomingDues(until).where((d) => _matches(q, d.bill.name)).toList();
    final overdue = s.overdueBills;

    final groups = <DateTime, List<BillDue>>{};
    for (final d in dues) {
      groups.putIfAbsent(DateTime(d.date.year, d.date.month), () => []).add(d);
    }

    return _listWithSearch(onSearch: onSearch, children: [
      if (overdue.isNotEmpty && q.isEmpty) ...[
        const SizedBox(height: 12),
        _OverdueBanner(overdue, onTap: onOverdue),
      ],
      if (dues.isEmpty)
        const EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No upcoming bills',
          subtitle:
              'Add rent, electricity, internet, card payments and subscriptions. You\'ll be reminded before they\'re due.',
        ),
      for (final g in groups.entries) ...[
        GroupHeader(_monthGroupLabel(g.key),
            total: g.value.fold<double>(0, (x, d) => x + d.bill.amount)),
        for (final d in g.value) BillDueTile(d),
      ],
    ]);
  }
}

class _OverdueBanner extends StatelessWidget {
  final List<Bill> bills;
  final VoidCallback onTap;
  const _OverdueBanner(this.bills, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = bills.fold<double>(0, (x, b) => x + b.amount);
    final names = bills.take(3).map((b) => b.name).join(', ');
    final more = bills.length > 3 ? ' and ${bills.length - 3} more.' : '';
    return Material(
      color: _red.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: _red.withOpacity(0.6)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Overdue',
                      style: TextStyle(
                          color: _red, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(Fmt.money(total),
                      style: const TextStyle(
                          color: _red, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Text('$names$more', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bill on a given due date.
class BillDueTile extends StatelessWidget {
  final BillDue due;
  final bool showChange;
  const BillDueTile(this.due, {super.key, this.showChange = true});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final b = due.bill;
    final cat = s.category(b.categoryId);
    final days = _daysFromToday(due.date);
    final cs = Theme.of(context).colorScheme;
    final change = showChange && due.isCurrent ? s.amountChange(b) : null;
    final dateColor = days < 0
        ? _red
        : (days <= 2 ? _amber : cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => BillDetail(billId: b.id!))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryAvatar(cat, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_whenText(due.date, DateTime.now()),
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: cs.onSurfaceVariant),
                      Text(_dayDiffText(days),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: dateColor)),
                    ],
                  ),
                  if (change != null) ChangeBadge(change),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(b.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (b.autoPay)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.bolt_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                      ),
                    if (b.recurring)
                      const Icon(Icons.sync_rounded, size: 18, color: kBlue),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kept for screens that show a bill at its current due date.
class BillTile extends StatelessWidget {
  final Bill bill;
  const BillTile(this.bill, {super.key});

  @override
  Widget build(BuildContext context) =>
      BillDueTile(BillDue(bill, bill.dueDate));
}

// ---------------------------------------------------------------- Overdue

class _OverdueView extends StatelessWidget {
  final String q;
  final ValueChanged<String> onSearch;
  const _OverdueView({required this.q, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.overdueBills.where((b) => _matches(q, b.name)).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final groups = <DateTime, List<Bill>>{};
    for (final b in list) {
      groups
          .putIfAbsent(DateTime(b.dueDate.year, b.dueDate.month), () => [])
          .add(b);
    }
    return _listWithSearch(onSearch: onSearch, children: [
      if (list.isEmpty)
        const EmptyState(
          icon: Icons.verified_rounded,
          title: 'Nothing overdue',
          subtitle: 'All caught up. Bills you miss will show here.',
        ),
      for (final g in groups.entries) ...[
        GroupHeader(_monthGroupLabel(g.key),
            total: g.value.fold<double>(0, (x, b) => x + b.amount)),
        for (final b in g.value) BillDueTile(BillDue(b, b.dueDate)),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- Calendar

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

enum _Mark { paid, overdue, upcoming }

class _CalItem {
  final Bill? bill;
  final String name;
  final double amount;
  final DateTime date;
  final _Mark mark;
  final int? categoryId;
  const _CalItem(
      this.bill, this.name, this.amount, this.date, this.mark, this.categoryId);
}

class _CalendarViewState extends State<_CalendarView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_CalItem> _items(AppState s) {
    final end = DateTime(_month.year, _month.month + 1, 0, 23, 59);
    final inMonth = (DateTime d) =>
        d.year == _month.year && d.month == _month.month;
    final items = <_CalItem>[];
    for (final t in s.billPayments) {
      if (!inMonth(t.date)) continue;
      Bill? bill;
      for (final b in s.bills) {
        if (b.id == t.billId) bill = b;
      }
      items.add(_CalItem(
          bill, t.note, t.amount, t.date, _Mark.paid, t.categoryId));
    }
    for (final b in s.overdueBills) {
      if (inMonth(b.dueDate)) {
        items.add(_CalItem(
            b, b.name, b.amount, b.dueDate, _Mark.overdue, b.categoryId));
      }
    }
    for (final d in s.upcomingDues(end)) {
      if (inMonth(d.date)) {
        items.add(_CalItem(d.bill, d.bill.name, d.bill.amount, d.date,
            _Mark.upcoming, d.bill.categoryId));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final items = _items(s);
    double total(_Mark m) =>
        items.where((i) => i.mark == m).fold(0.0, (x, i) => x + i.amount);

    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday % 7; // Sunday first
    final start = first.subtract(Duration(days: lead));
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((lead + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final dayItems = _selected == null
        ? <_CalItem>[]
        : items.where((i) => _sameDay(i.date, _selected!)).toList();

    Color markColor(_Mark m) => m == _Mark.paid
        ? _green
        : m == _Mark.overdue
            ? _red
            : _amber;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _selected = null;
                    }),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat(_month.year == today.year ? 'MMMM' : 'MMMM yyyy')
                          .format(_month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _selected = null;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final d in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
                    Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                color: kBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                children: [
                  for (var i = 0; i < cells; i++)
                    Builder(builder: (context) {
                      final day = DateTime(start.year, start.month, start.day + i);
                      final inMonth = day.month == _month.month;
                      final isToday = _sameDay(day, today);
                      final isSel = _selected != null && _sameDay(day, _selected!);
                      final marks = items
                          .where((it) => _sameDay(it.date, day))
                          .map((it) => it.mark)
                          .toSet();
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: inMonth
                            ? () => setState(() => _selected = day)
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? kBlue
                                    : isSel
                                        ? cs.surfaceContainerHighest
                                        : null,
                                shape: BoxShape.circle,
                              ),
                              child: Text('${day.day}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isToday || isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isToday
                                        ? Colors.white
                                        : inMonth
                                            ? cs.onSurface
                                            : cs.onSurfaceVariant
                                                .withOpacity(0.5),
                                  )),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 5,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final m in _Mark.values)
                                    if (inMonth && marks.contains(m))
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: BoxDecoration(
                                            color: markColor(m),
                                            shape: BoxShape.circle),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              for (final m in _Mark.values)
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(Fmt.money(total(m)),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              m == _Mark.paid
                                  ? 'Paid'
                                  : m == _Mark.overdue
                                      ? 'Overdue'
                                      : 'Upcoming',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 5),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: markColor(m), shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_selected != null) ...[
          GroupHeader(Fmt.day(_selected!),
              total: dayItems.isEmpty
                  ? null
                  : dayItems.fold<double>(0, (x, i) => x + i.amount)),
          if (dayItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Nothing due on this day.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final it in dayItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: it.bill?.id == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BillDetail(billId: it.bill!.id!))),
                child: Row(
                  children: [
                    CategoryAvatar(s.category(it.categoryId), size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            it.mark == _Mark.paid
                                ? 'Paid'
                                : it.mark == _Mark.overdue
                                    ? 'Overdue'
                                    : 'Upcoming',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: markColor(it.mark)),
                          ),
                        ],
                      ),
                    ),
                    Text(Fmt.money(it.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Recurring

class _RecurringView extends StatelessWidget {
  final String q;
  final ValueChanged<String> onSearch;
  const _RecurringView({required this.q, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final list = s.activeBills
        .where((b) => b.recurring && _matches(q, b.name))
        .toList();
    final monthly = list.fold<double>(0, (x, b) {
      final (base, n) = normalizeRepeat(b.repeat, b.every);
      switch (base) {
        case Repeat.daily:
          return x + b.amount * 30.44 / n;
        case Repeat.weekly:
        case Repeat.biweekly:
          return x + b.amount * 52 / 12 / n;
        case Repeat.monthly:
        case Repeat.quarterly:
          return x + b.amount / n;
        case Repeat.yearly:
          return x + b.amount / 12 / n;
        case Repeat.none:
          return x;
      }
    });
    return _listWithSearch(onSearch: onSearch, children: [
      if (list.isEmpty)
        const EmptyState(
          icon: Icons.sync_rounded,
          title: 'No recurring bills',
          subtitle: 'Bills that repeat every day, week, month or year show here.',
        )
      else
        GroupHeader('${list.length} recurring · per month', total: monthly),
      for (final b in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BillDetail(billId: b.id!))),
            child: Row(
              children: [
                CategoryAvatar(s.category(b.categoryId), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15.5)),
                      const SizedBox(height: 3),
                      Text(b.schedule,
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                      Text('Next Due ${Fmt.shortDate(b.dueDate)}',
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.money(b.amount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Icon(Icons.sync_rounded, size: 18, color: kBlue),
                  ],
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- Paid

class _PaidView extends StatelessWidget {
  final String q;
  final ValueChanged<String> onSearch;
  const _PaidView({required this.q, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final list = s.billPayments.where((t) => _matches(q, t.note)).toList();
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month), () => []).add(t);
    }
    return _listWithSearch(onSearch: onSearch, children: [
      if (list.isEmpty)
        const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No paid bills yet',
          subtitle: 'Bills you mark as paid are listed here by month.',
        ),
      for (final g in groups.entries) ...[
        GroupHeader(_monthGroupLabel(g.key),
            total: g.value.fold<double>(0, (x, t) => x + t.amount)),
        for (final t in g.value)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              onTap: s.bills.any((b) => b.id == t.billId)
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BillDetail(billId: t.billId!)))
                  : null,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CategoryAvatar(s.category(t.categoryId), size: 44),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: cs.surfaceContainerLow, width: 2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.note.isEmpty ? 'Bill' : t.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15.5)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(Fmt.shortDate(t.dueDate ?? t.date),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSurfaceVariant)),
                            Icon(Icons.chevron_right_rounded,
                                size: 14, color: cs.onSurfaceVariant),
                            Text('Paid ${Fmt.shortDate(t.date)}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(Fmt.money(t.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
          ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- Pay sheet

Future<void> showPaySheet(BuildContext context, Bill bill) async {
  final s = context.read<AppState>();
  final amount = TextEditingController(text: _trim(bill.amount));
  var date = DateTime.now();
  int? accountId = s.account(bill.accountId)?.id ??
      (s.accounts.isNotEmpty ? s.accounts.first.id : null);
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pay ${bill.name}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Due ${Fmt.date(bill.dueDate)}',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              MoneyField(controller: amount),
              const SizedBox(height: 12),
              DateField(
                  label: 'Paid on',
                  value: date,
                  onChanged: (d) => setSt(() => date = d)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: const InputDecoration(labelText: 'Paid from'),
                items: [
                  for (final a in s.accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSt(() => accountId = v),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirm payment'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await s.markBillPaid(bill,
                      amount: double.parse(amount.text),
                      date: date,
                      accountId: accountId);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    toast(
                        context,
                        bill.recurring
                            ? '${bill.name} paid · next due ${Fmt.shortDate(bill.followingDue)}'
                            : '${bill.name} paid');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

// ---------------------------------------------------------------- Details

class BillDetail extends StatelessWidget {
  final int billId;
  const BillDetail({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    Bill? bill;
    for (final b in s.bills) {
      if (b.id == billId) bill = b;
    }
    if (bill == null) return const Scaffold(body: SizedBox.shrink());
    final b = bill;
    final cat = s.category(b.categoryId);
    final acc = s.account(b.accountId);
    final payments = s.paymentsFor(b);
    final days = _daysFromToday(b.dueDate);
    final totalPaid = payments.fold<double>(0, (x, t) => x + t.amount);
    final change = s.amountChange(b);

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    Widget chip(IconData icon, String text, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color ?? cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(text,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color ?? cs.onSurface)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BillForm(bill: b))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, 'Delete bill?',
                  'Payment history stays in your transactions.')) {
                await s.deleteBill(b);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(child: CategoryAvatar(cat, size: 56)),
          const SizedBox(height: 12),
          Text(b.name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(Fmt.money(b.amount),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          if (change != null) Center(child: ChangeBadge(change)),
          const SizedBox(height: 12),
          if (b.active)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(Icons.event_rounded, 'By ${Fmt.date(b.dueDate)}'),
                chip(
                  Icons.schedule_rounded,
                  days < 0
                      ? '${-days} Days past'
                      : days == 0
                          ? 'Due today'
                          : '$days Days to pay',
                  color: days < 0 ? _red : (days <= 2 ? _amber : null),
                ),
              ],
            )
          else
            Center(child: chip(Icons.task_alt_rounded, 'Completed', color: _green)),
          if (b.active) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlue,
                side: const BorderSide(color: kBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => showPaySheet(context, b),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Mark Paid',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (b.recurring)
              TextButton(
                onPressed: () async {
                  await s.skipBill(b);
                  if (context.mounted) toast(context, 'Skipped this cycle');
                },
                child: const Text('Skip this one'),
              ),
          ],
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                row(Icons.category_outlined, 'Category',
                    cat?.name ?? 'Uncategorized'),
                Divider(height: 1, color: cs.outlineVariant),
                row(Icons.account_balance_wallet_outlined, 'Pay from',
                    acc?.name ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                row(
                    Icons.notifications_none_rounded,
                    'Reminder',
                    b.remindDaysBefore == 0
                        ? 'On the due date'
                        : 'Remind ${b.remindDaysBefore} day${b.remindDaysBefore == 1 ? '' : 's'} before'),
                Divider(height: 1, color: cs.outlineVariant),
                row(Icons.sync_rounded, 'Recurring', b.schedule),
                Divider(height: 1, color: cs.outlineVariant),
                row(Icons.bolt_rounded, 'Auto Paid', b.autoPay ? 'Yes' : 'No'),
              ],
            ),
          ),
          if (b.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(child: Text(b.notes)),
          ],
          GroupHeader('Payment history',
              total: payments.isEmpty ? null : totalPaid),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('No payments recorded yet.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final t in payments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: _green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t.dueDate == null
                          ? 'Paid ${Fmt.date(t.date)}'
                          : '${Fmt.shortDate(t.dueDate!)} › Paid ${Fmt.date(t.date)}'),
                    ),
                    Text(Fmt.money(t.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
