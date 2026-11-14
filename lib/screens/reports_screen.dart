import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export.dart';
import '../utils.dart';
import '../widgets.dart';
import 'transactions_screen.dart';

const _green = Color(0xFF22C55E);
const _orange = Color(0xFFF97316);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) toast(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final spent = s.expenseInMonth(_month);
    final income = s.incomeInMonth(_month);
    final prev = s.expenseInMonth(DateTime(_month.year, _month.month - 1));
    final change = prev == 0 ? null : (spent - prev) / prev * 100;
    final savingsRate = income == 0 ? null : (income - spent) / income * 100;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final daysCount = isCurrent
        ? now.day
        : DateTime(_month.year, _month.month + 1, 0).day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
            onSelected: (v) {
              if (v == 'pdf') {
                _run(() => Exporter.shareMonthlyPdf(s, _month));
              } else if (v == 'csv') {
                _run(() => Exporter.shareCsv(s, month: _month));
              } else {
                _run(() => Exporter.shareCsv(s));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Monthly report (PDF)')),
              PopupMenuItem(value: 'csv', child: Text('This month (CSV)')),
              PopupMenuItem(value: 'all', child: Text('All transactions (CSV)')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          MonthSwitcher(
              month: _month, onChanged: (m) => setState(() => _month = m)),
          AppCard(
            padding: const EdgeInsets.all(14),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_rounded),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transactions',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('All your income & expenses',
                          style: TextStyle(fontSize: 12.5, color: kBlue)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Insight(
                  'vs last month',
                  change == null
                      ? '—'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                  change != null && change > 0
                      ? const Color(0xFFEF4444)
                      : _green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Insight(
                  'Savings rate',
                  savingsRate == null
                      ? '—'
                      : '${savingsRate.toStringAsFixed(0)}%',
                  kBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Insight('Daily avg',
                    Fmt.money(spent / daysCount, compact: true), cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Distribution(
            title: 'Spending Distribution',
            subtitle: 'By category',
            total: spent,
            data: s.expenseByCategory(_month),
            emptyText: 'No spending this month',
          ),
          const SizedBox(height: 12),
          _Distribution(
            title: 'Income Distribution',
            subtitle: 'By category',
            total: income,
            data: s.incomeByCategory(_month),
            emptyText: 'No income found',
          ),
          const SizedBox(height: 12),
          _SixMonths(month: _month),
        ],
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  final String title;
  final String subtitle;
  final double total;
  final Map<int?, double> data;
  final String emptyText;

  const _Distribution({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.data,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = entries.take(4).toList();
    final more = entries.length - shown.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_rounded, size: 20, color: kBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: kBlue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded,
                        size: 40, color: cs.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(emptyText,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                          sections: [
                            for (final e in entries)
                              PieChartSectionData(
                                value: e.value,
                                color: Color(
                                    s.category(e.key)?.color ?? 0xFF94A3B8),
                                radius: 14,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: cs.onSurfaceVariant)),
                          Text(Fmt.money(total, compact: true),
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in shown)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              CategoryAvatar(s.category(e.key), size: 26),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.category(e.key)?.name ?? 'Other',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(Fmt.money(e.value, compact: true),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '(${(e.value / total * 100).toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (more > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('+$more more',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SixMonths extends StatelessWidget {
  final DateTime month;
  const _SixMonths({required this.month});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i)
    ];
    final incomes = [for (final m in months) s.incomeInMonth(m)];
    final expenses = [for (final m in months) s.expenseInMonth(m)];
    final maxY =
        [...incomes, ...expenses, 1.0].reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Income vs expenses · 6 months',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
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
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(DateFormat('MMM').format(months[i]),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == 5
                                      ? FontWeight.w800
                                      : FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: incomes[i],
                          width: 10,
                          color: _green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: expenses[i],
                          width: 10,
                          color: _orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(_green, 'Income'),
              SizedBox(width: 16),
              _Legend(_orange, 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Insight(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17, color: color)),
            ),
          ],
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
