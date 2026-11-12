import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_form.dart';
import 'bills_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final income = s.incomeInMonth(month);
    final spent = s.expenseInMonth(month);
    final overdue = s.overdueBills;
    final upcoming = s.billsDueWithin(14);
    final dueSoonTotal =
        [...overdue, ...upcoming].fold<double>(0, (x, b) => x + b.amount);
    final byCat = s.expenseByCategory(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final overall = s.overallBudget();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant)),
            const Text('Bills O9 Time'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reports',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // Hero balance card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total balance',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(Fmt.money(s.totalBalance),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: _HeroStat(Icons.south_west_rounded,
                            'Income this month', income)),
                    Container(width: 1, height: 36, color: Colors.white24),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _HeroStat(Icons.north_east_rounded,
                            'Spent this month', spent)),
                  ],
                ),
                if (overall != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overall.amount == 0
                          ? 0
                          : (spent / overall.amount).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation(spent > overall.amount
                          ? const Color(0xFFFCA5A5)
                          : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spent > overall.amount
                        ? 'Over budget by ${Fmt.money(spent - overall.amount)}'
                        : '${Fmt.money(overall.amount - spent)} left in budget',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Quick actions
          Row(
            children: [
              _Quick(Icons.remove_circle_outline_rounded, 'Expense',
                  () => openTxnForm(context, type: TxType.expense)),
              _Quick(Icons.add_circle_outline_rounded, 'Income',
                  () => openTxnForm(context, type: TxType.income)),
              _Quick(Icons.receipt_long_rounded, 'Bill', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BillForm()));
              }),
              _Quick(Icons.insights_rounded, 'Reports', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()));
              }),
            ],
          ),
          SectionTitle(
            overdue.isNotEmpty
                ? 'Bills · ${overdue.length} overdue'
                : 'Upcoming bills',
            action: 'See all',
            onAction: () => onNavigate(1),
          ),
          if (overdue.isEmpty && upcoming.isEmpty)
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.activeBills.isEmpty
                          ? 'Add your bills to get reminders before they\'re due.'
                          : 'Nothing due in the next 2 weeks. Nice!',
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('${Fmt.money(dueSoonTotal)} due in the next 14 days',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ),
            for (final b in [...overdue, ...upcoming].take(5)) BillTile(b),
          ],
          if (byCat.isNotEmpty) ...[
            SectionTitle('Spending · ${Fmt.month(month)}',
                action: 'Details',
                onAction: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()))),
            AppCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        sections: [
                          for (final e in byCat.take(6))
                            PieChartSectionData(
                              value: e.value,
                              color: Color(s.category(e.key)?.color ?? 0xFF94A3B8),
                              radius: 22,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in byCat.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: Color(s.category(e.key)?.color ??
                                          0xFF94A3B8),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      s.category(e.key)?.name ?? 'Other',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                                Text(
                                    '${(e.value / spent * 100).round()}%',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (s.txns.isNotEmpty) ...[
            SectionTitle('Recent activity',
                action: 'See all', onAction: () => onNavigate(2)),
            for (final t in s.txns.take(5)) TxnTile(t),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  const _HeroStat(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11.5)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(Fmt.money(value, compact: true),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          onTap: onTap,
          child: Column(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
