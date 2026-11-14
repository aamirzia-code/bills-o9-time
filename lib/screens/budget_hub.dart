import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'transactions_screen.dart';

/// Budget tab: Budgets · Goals · Summary.
class BudgetHub extends StatelessWidget {
  const BudgetHub({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Budget'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'BUDGETS'),
              Tab(text: 'GOALS'),
              Tab(text: 'SUMMARY'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BudgetScreen(embedded: true),
            GoalsScreen(embedded: true),
            BudgetSummary(),
          ],
        ),
      ),
    );
  }
}

class BudgetSummary extends StatefulWidget {
  const BudgetSummary({super.key});

  @override
  State<BudgetSummary> createState() => _BudgetSummaryState();
}

class _BudgetSummaryState extends State<BudgetSummary> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _editIncome(AppState s, double suggested) async {
    final c = TextEditingController(
        text: (s.incomeBudget ?? suggested) == 0
            ? ''
            : (s.incomeBudget ?? suggested).toStringAsFixed(0));
    final key = GlobalKey<FormState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Monthly income budget',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('What you expect to earn each month. Used to plan how much to allocate.',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              MoneyField(controller: c, autofocus: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (s.incomeBudget != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await s.setIncomeBudget(null);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Use actual income'),
                      ),
                    ),
                  if (s.incomeBudget != null) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (!key.currentState!.validate()) return;
                        await s.setIncomeBudget(double.parse(c.text));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final actualIncome = s.incomeInMonth(_month);
    final available = s.incomeBudget ?? actualIncome;

    final overall = s.overallBudget();
    final catTotal = s.categoryBudgets.fold<double>(0, (x, b) => x + b.amount);
    final budgetsPlanned = overall?.amount ?? catTotal;
    final spent = s.expenseInMonth(_month);

    final savings = s.goals.where((g) => g.kind == GoalKind.saving).toList();
    final debts = s.goals.where((g) => g.kind == GoalKind.debt).toList();
    final savingMonthly = savings.fold<double>(
        0, (x, g) => x + g.monthlyNeed(s.goalProgress(g), _month));
    final debtMonthly = debts.fold<double>(
        0, (x, g) => x + g.monthlyNeed(s.goalProgress(g), _month));

    final allocated = budgetsPlanned + savingMonthly + debtMonthly;
    final remaining = available - allocated;
    final ratio = available <= 0 ? 0.0 : allocated / available;

    void openGoals() => DefaultTabController.of(context).animateTo(1);

    Widget allocRow(IconData icon, Color color, String label,
        {required Widget trailing}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(color: cs.onSurfaceVariant))),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      );
    }

    Widget planned(double amount, {String? sub}) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Planned ',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              TextSpan(
                  text: Fmt.money(amount),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
            if (sub != null)
              Text(sub,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        );

    Widget link(String text, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Text(text,
              style: const TextStyle(
                  color: kBlue, fontWeight: FontWeight.w600)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        MonthSwitcher(
            month: _month, onChanged: (m) => setState(() => _month = m)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Available to Budget',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(Fmt.money(available),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              InkWell(
                onTap: () => _editIncome(s, actualIncome),
                child: allocRow(
                  Icons.attach_money_rounded,
                  const Color(0xFF22C55E),
                  s.incomeBudget == null
                      ? 'Income (actual this month)'
                      : 'Income Budget',
                  trailing: Row(
                    children: [
                      Text(Fmt.money(available),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Allocation',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              allocRow(Icons.attach_money_rounded, kBlue, 'Budgets',
                  trailing: budgetsPlanned == 0
                      ? link('Set budget',
                          () => DefaultTabController.of(context).animateTo(0))
                      : planned(budgetsPlanned,
                          sub: 'Spent ${Fmt.money(spent)}')),
              allocRow(Icons.track_changes_rounded, const Color(0xFF22C55E),
                  'Saving Goals',
                  trailing: savings.isEmpty
                      ? link('Create Goal', () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GoalTemplatePicker()));
                        })
                      : planned(savingMonthly,
                          sub: '${savings.length} goal${savings.length == 1 ? '' : 's'}')),
              allocRow(Icons.credit_card_rounded, const Color(0xFFF97316),
                  'Debt Payoff',
                  trailing: debts.isEmpty
                      ? link('Manage Debt', openGoals)
                      : planned(debtMonthly,
                          sub: '${debts.length} debt${debts.length == 1 ? '' : 's'}')),
              Divider(height: 12, color: cs.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Total Allocated',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(Fmt.money(allocated),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        remaining >= 0
                            ? 'Remaining to allocate'
                            : 'Over-allocated by',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                  Text(Fmt.money(remaining.abs()),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: remaining < 0
                              ? const Color(0xFFEF4444)
                              : null)),
                ],
              ),
              const SizedBox(height: 12),
              ProgressLine(
                  value: ratio, color: const Color(0xFF22C55E), height: 12),
              const SizedBox(height: 8),
              Text(
                'Allocated ${Fmt.money(allocated)} of ${Fmt.money(available)}',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Goals and debts count what you need to set aside each month to reach their target date.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
