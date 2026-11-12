import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export.dart';
import '../utils.dart';
import '../widgets.dart';
import 'transactions_screen.dart';

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
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(_month.year, _month.month - i)
    ];
    final incomes = [for (final m in months) s.incomeInMonth(m)];
    final expenses = [for (final m in months) s.expenseInMonth(m)];
    final maxY = [...incomes, ...expenses, 1.0].reduce((a, b) => a > b ? a : b);
    final spent = s.expenseInMonth(_month);
    final income = s.incomeInMonth(_month);
    final byCat = s.expenseByCategory(_month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final prev = s.expenseInMonth(DateTime(_month.year, _month.month - 1));
    final change = prev == 0 ? null : (spent - prev) / prev * 100;
    final savingsRate = income == 0 ? null : (income - spent) / income * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          MonthSwitcher(
              month: _month, onChanged: (m) => setState(() => _month = m)),
          Row(
            children: [
              Expanded(
                child: _Insight(
                  'vs last month',
                  change == null
                      ? '—'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                  change != null && change > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Insight(
                  'Savings rate',
                  savingsRate == null
                      ? '—'
                      : '${savingsRate.toStringAsFixed(0)}%',
                  cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Insight(
                  'Daily avg',
                  Fmt.money(spent /
                      (_month.year == DateTime.now().year &&
                              _month.month == DateTime.now().month
                          ? DateTime.now().day
                          : DateTime(_month.year, _month.month + 1, 0).day),
                      compact: true),
                  cs.onSurface,
                ),
              ),
            ],
          ),
          const SectionTitle('Income vs expenses · 6 months'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
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
                                child: Text(
                                    DateFormat('MMM').format(months[i]),
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
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: expenses[i],
                                width: 10,
                                color: const Color(0xFFEA580C),
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
                    _Legend(Color(0xFF16A34A), 'Income'),
                    SizedBox(width: 16),
                    _Legend(Color(0xFFEA580C), 'Expenses'),
                  ],
                ),
              ],
            ),
          ),
          SectionTitle('Where it went · ${Fmt.money(spent)}'),
          if (byCat.isEmpty)
            const EmptyState(
              icon: Icons.insights_rounded,
              title: 'No spending this month',
              subtitle: 'Record expenses or mark bills paid to see insights.',
            ),
          for (final e in byCat)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CategoryAvatar(s.category(e.key), size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.category(e.key)?.name ?? 'Other',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(Fmt.money(e.value),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressLine(
                      value: spent == 0 ? 0 : e.value / spent,
                      color: Color(s.category(e.key)?.color ?? 0xFF94A3B8),
                      height: 6,
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
