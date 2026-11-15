import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Everyday spending per day (bill payments are planned, so left out).
Map<DateTime, double> dailySpend(List<Txn> txns, DateTime from, DateTime to) {
  final out = <DateTime, double>{};
  for (final t in txns) {
    if (t.type != TxType.expense || t.billId != null) continue;
    if (t.date.isBefore(from) || !t.date.isBefore(to)) continue;
    final k = _day(t.date);
    out[k] = (out[k] ?? 0) + t.amount;
  }
  return out;
}

/// Days in a row, up to and including [today], with no everyday spending.
/// Counting starts from the first day anything was recorded.
int noSpendStreak(List<Txn> txns, DateTime today) {
  final days = <DateTime>{};
  DateTime? first;
  for (final t in txns) {
    final d = _day(t.date);
    if (first == null || d.isBefore(first)) first = d;
    if (t.type == TxType.expense && t.billId == null) days.add(d);
  }
  if (first == null) return 0;
  var d = _day(today);
  var n = 0;
  while (!d.isBefore(first) && !days.contains(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// Calendar heatmap for one budget period, with the no-spend streak.
class SpendHeatmap extends StatelessWidget {
  final DateTime month;
  const SpendHeatmap({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final from = s.periodStart(month);
    final to = s.periodEnd(month);
    final data = dailySpend(s.txns, from, to);
    final max = data.values.fold<double>(0, (a, b) => b > a ? b : a);
    final today = _day(DateTime.now());
    final days = <DateTime>[
      for (var d = from; d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) d
    ];
    final elapsed = days.where((d) => !d.isAfter(today)).toList();
    final noSpend = elapsed.where((d) => (data[d] ?? 0) == 0).length;
    final streak = noSpendStreak(s.txns, today);
    final lead = from.weekday % 7; // Sunday-first grid
    const accent = Color(0xFFF97316);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Spending calendar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🔥 $streak-day no-spend streak',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$noSpend no-spend day${noSpend == 1 ? '' : 's'} so far · bills not counted',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (final d in days)
                Builder(builder: (context) {
                  final v = data[d] ?? 0;
                  final future = d.isAfter(today);
                  final t = max == 0 ? 0.0 : (v / max).clamp(0.0, 1.0);
                  final bg = future
                      ? Colors.transparent
                      : v == 0
                          ? const Color(0xFF22C55E).withOpacity(0.16)
                          : accent.withOpacity(0.18 + 0.72 * t);
                  return Tooltip(
                    message: '${Fmt.day(d)}: ${v == 0 ? 'no spending' : Fmt.money(v)}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: future || v == 0 ? null : () => _showDay(context, s, d),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: d == today ? Border.all(color: cs.primary, width: 2) : null,
                        ),
                        child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: future
                                ? cs.onSurfaceVariant.withOpacity(0.5)
                                : t > 0.55
                                    ? Colors.white
                                    : cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text('No spend', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              const SizedBox(width: 14),
              for (final o in const [0.25, 0.5, 0.9])
                Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                        color: accent.withOpacity(o), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text('More spent', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDay(BuildContext context, AppState s, DateTime d) {
    final list = s.txns
        .where((t) => t.type == TxType.expense && _day(t.date) == d)
        .toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(Fmt.day(d), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final t in list) TxnTile(t),
            ],
          ),
        ),
      ),
    );
  }
}
