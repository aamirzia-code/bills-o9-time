import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_form.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

typedef NavigateFn = void Function(int tab, {int? billsTab});

const _red = Color(0xFFEF4444);

class HomeScreen extends StatelessWidget {
  final NavigateFn onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning!';
    if (h < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final name = s.userName.isEmpty ? 'there' : s.userName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.surfaceContainerHighest,
              child: Text(
                s.userName.isEmpty ? '🙂' : s.userName[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi $name',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                Text(_greeting(),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search transactions',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransactionsScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home-fab',
        onPressed: () => showAddSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _SpendingCard(onNavigate: onNavigate),
          const SizedBox(height: 12),
          _PlannerCard(onNavigate: onNavigate),
          const SizedBox(height: 12),
          const _ReportCard(),
          if (s.txns.isNotEmpty) ...[
            SectionTitle('Transactions',
                action: 'View all',
                onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TransactionsScreen()))),
            for (final t in s.txns.take(5)) TxnTile(t),
          ],
        ],
      ),
    );
  }
}

/// "+" sheet: add expense, income or bill.
Future<void> showAddSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget item(IconData icon, Color color, String title, String sub,
                VoidCallback go) =>
            ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub),
              onTap: () {
                Navigator.pop(ctx);
                go();
              },
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(Icons.receipt_long_rounded, kBlue, 'Bill',
                    'Recurring or one-time bill with reminders', () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BillForm()));
                }),
                item(Icons.north_east_rounded, _red, 'Expense',
                    'Something you spent',
                    () => openTxnForm(context, type: TxType.expense)),
                item(Icons.south_west_rounded, const Color(0xFF22C55E),
                    'Income', 'Salary, business or other income',
                    () => openTxnForm(context, type: TxType.income)),
              ],
            ),
          ),
        );
      },
    );

// ------------------------------------------------------------ Spending card

class _SpendingCard extends StatelessWidget {
  final NavigateFn onNavigate;
  const _SpendingCard({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final spent = s.expenseInMonth(month);

    // Cumulative spending per day so far.
    final perDay = List<double>.filled(daysInMonth + 1, 0);
    for (final t in s.txnsInMonth(month)) {
      if (t.type == TxType.expense) perDay[t.date.day] += t.amount;
    }
    final actual = <FlSpot>[const FlSpot(1, 0)];
    var run = 0.0;
    for (var d = 1; d <= now.day; d++) {
      run += perDay[d];
      actual.add(FlSpot(d.toDouble(), run));
    }

    // Projection = spent so far + bills still due this month, on their dates.
    final end = DateTime(now.year, now.month + 1, 0, 23, 59);
    final dues = s.upcomingDues(end)
        .where((d) => d.date.month == now.month && d.date.year == now.year)
        .toList();
    final projected = <FlSpot>[FlSpot(now.day.toDouble(), run)];
    var proj = run;
    final dueByDay = <int, double>{};
    for (final d in dues) {
      dueByDay[d.date.day] = (dueByDay[d.date.day] ?? 0) + d.bill.amount;
    }
    for (var d = now.day; d <= daysInMonth; d++) {
      if (d > now.day || (dueByDay[d] ?? 0) > 0) {
        proj += dueByDay[d] ?? 0;
        projected.add(FlSpot(d.toDouble(), proj));
      }
    }
    final maxY = math.max(proj, 1.0) * 1.15;

    return AppCard(
      onTap: () => onNavigate(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Spending in ${Fmt.month(month).split(' ').first}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 6),
          Text(Fmt.money(spent),
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Text(
            proj > spent
                ? 'Projected ${Fmt.money(proj)} with bills still due'
                : 'No more bills due this month',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (spent == 0 && dues.isEmpty)
            Column(
              children: [
                const SizedBox(height: 8),
                const Text('Your financial clarity starts here',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue),
                  ),
                  onPressed: () => showAddSheet(context),
                  child: const Text('+ Add First Transaction'),
                ),
              ],
            )
          else
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final d = v.toInt();
                          if (d != 1 && d != 10 && d != 20 && d != daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          return Text('$d',
                              style: TextStyle(
                                  fontSize: 10.5, color: cs.onSurfaceVariant));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: actual,
                      isStepLineChart: true,
                      color: _red,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                          show: true, color: _red.withOpacity(0.08)),
                    ),
                    if (projected.length > 1)
                      LineChartBarData(
                        spots: projected,
                        isStepLineChart: true,
                        color: _red.withOpacity(0.7),
                        barWidth: 2,
                        dashArray: [5, 4],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Planner card

class _PlannerCard extends StatelessWidget {
  final NavigateFn onNavigate;
  const _PlannerCard({required this.onNavigate});

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday % 7));
    final days = [for (var i = 0; i < 14; i++) weekStart.add(Duration(days: i))];
    final dues = s.upcomingDues(days.last.add(const Duration(hours: 23)));
    final overdue = s.overdueBills;

    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final nextWeek = dues
        .where((d) =>
            !d.date.isBefore(nextWeekStart) &&
            d.date.isBefore(nextWeekStart.add(const Duration(days: 7))))
        .toList();
    final thisWeek = dues.where((d) => d.date.isBefore(nextWeekStart)).toList();

    String names(Iterable<String> list) {
      final l = list.toList();
      if (l.length <= 3) return l.join(', ');
      return '${l.take(3).join(', ')} and ${l.length - 3} more.';
    }

    return AppCard(
      onTap: () => onNavigate(1, billsTab: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Planner',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final l in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(l,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < 2; w++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (final d in days.sublist(w * 7, w * 7 + 7))
                    Expanded(
                      child: Builder(builder: (_) {
                        final isToday = _same(d, today);
                        final hasDue = dues.any((x) => _same(x.date, d));
                        final hasOverdue =
                            overdue.any((b) => _same(b.dueDate, d));
                        return Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? kBlue
                                    : hasOverdue
                                        ? _red.withOpacity(0.18)
                                        : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${d.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: isToday
                                        ? Colors.white
                                        : d.isBefore(today)
                                            ? cs.onSurfaceVariant
                                            : cs.onSurface,
                                  )),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: hasDue
                                    ? const Color(0xFFF59E0B)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ),
          if (thisWeek.isNotEmpty || nextWeek.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thisWeek.isNotEmpty ? 'This week' : 'Next week',
                      style: const TextStyle(
                          color: kBlue, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(names((thisWeek.isNotEmpty ? thisWeek : nextWeek)
                      .map((d) => d.bill.name))),
                ],
              ),
            ),
          ],
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => onNavigate(1, billsTab: 1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.12),
                  border: Border.all(color: _red.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Missed to pay: ${names(overdue.map((b) => b.name))}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(Fmt.money(s.overdueTotal),
                        style: const TextStyle(
                            color: _red,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ],
                ),
              ),
            ),
          ],
          if (dues.isEmpty && overdue.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                s.activeBills.isEmpty
                    ? 'Add your bills to plan the next two weeks.'
                    : 'Nothing due in the next two weeks.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Report card

class _ReportCard extends StatefulWidget {
  const _ReportCard();

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    final lastName = Fmt.month(last).split(' ').first;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Monthly Report',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'See how you spent and saved in $lastName with a detailed PDF report.',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await Exporter.shareMonthlyPdf(
                                context.read<AppState>(), last);
                          } catch (e) {
                            if (context.mounted) toast(context, 'Export failed: $e');
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (h, c) in const [
                  (22.0, Color(0xFFF59E0B)),
                  (34.0, Color(0xFFEF4444)),
                  (46.0, kBlue),
                  (30.0, Color(0xFF8B5CF6)),
                ])
                  Expanded(
                    child: Container(
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
