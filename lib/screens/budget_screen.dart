import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'transactions_screen.dart';

class BudgetScreen extends StatefulWidget {
  final bool embedded;
  const BudgetScreen({super.key, this.embedded = false});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final overall = s.overallBudget();
    final spent = s.expenseInMonth(_month);
    final catBudgets = s.categoryBudgets;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final daysLeft = isCurrent ? daysInMonth - now.day + 1 : 0;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget-fab',
        onPressed: () => showBudgetSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          MonthSwitcher(
              month: _month, onChanged: (m) => setState(() => _month = m)),
          AppCard(
            onTap: () => showBudgetSheet(context, budget: overall, overall: true),
            child: overall == null
                ? Row(
                    children: [
                      Icon(Icons.savings_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Set a total monthly spending limit',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly budget',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Fmt.money(spent),
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 6),
                            child: Text('of ${Fmt.money(overall.amount)}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProgressLine(
                          value: overall.amount == 0
                              ? 0
                              : spent / overall.amount,
                          color: Theme.of(context).colorScheme.primary,
                          height: 12),
                      const SizedBox(height: 10),
                      Text(
                        spent > overall.amount
                            ? 'Over budget by ${Fmt.money(spent - overall.amount)}'
                            : isCurrent && daysLeft > 0
                                ? '${Fmt.money(overall.amount - spent)} left · about ${Fmt.money((overall.amount - spent) / daysLeft)}/day for $daysLeft days'
                                : '${Fmt.money(overall.amount - spent)} left',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: spent > overall.amount
                                ? const Color(0xFFDC2626)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
          const SectionTitle('Categories'),
          if (catBudgets.isEmpty)
            const EmptyState(
              icon: Icons.pie_chart_rounded,
              title: 'No category budgets',
              subtitle:
                  'Set limits for groceries, dining, fuel and more to see how you\'re tracking.',
            ),
          for (final b in catBudgets) _CategoryBudgetTile(b, _month),
        ],
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  final Budget b;
  final DateTime month;
  const _CategoryBudgetTile(this.b, this.month);

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cat = s.category(b.categoryId);
    final spent = s.expenseInMonth(month, categoryId: b.categoryId);
    final ratio = b.amount == 0 ? 0.0 : spent / b.amount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => showBudgetSheet(context, budget: b),
        child: Column(
          children: [
            Row(
              children: [
                CategoryAvatar(cat, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(cat?.name ?? 'Deleted category',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${(ratio * 100).round()}%',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ratio > 1 ? const Color(0xFFDC2626) : null)),
              ],
            ),
            const SizedBox(height: 10),
            ProgressLine(value: ratio, color: Color(cat?.color ?? 0xFF475569)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${Fmt.money(spent)} spent',
                    style: const TextStyle(fontSize: 12.5)),
                const Spacer(),
                Text(
                  ratio > 1
                      ? '${Fmt.money(spent - b.amount)} over'
                      : '${Fmt.money(b.amount - spent)} left',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ratio > 1 ? const Color(0xFFDC2626) : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showBudgetSheet(BuildContext context,
    {Budget? budget, bool overall = false}) async {
  final s = context.read<AppState>();
  final amount = TextEditingController(
      text: budget == null ? '' : budget.amount.toStringAsFixed(0));
  int? categoryId = budget?.categoryId;
  final isOverall = overall || (budget != null && budget.categoryId == null);
  final formKey = GlobalKey<FormState>();
  final used = s.categoryBudgets.map((b) => b.categoryId).toSet();
  final available = s
      .categoriesOf(TxType.expense)
      .where((c) => !used.contains(c.id) || c.id == budget?.categoryId)
      .toList();

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(isOverall ? 'Monthly budget' : 'Category budget',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                MoneyField(controller: amount, label: 'Monthly limit'),
                if (!isOverall) ...[
                  const SizedBox(height: 16),
                  CategoryPicker(
                    categories: available,
                    selected: categoryId,
                    onSelected: (id) => setSt(() => categoryId = id),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (budget != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await s.deleteBudget(budget);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                    if (budget != null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (!isOverall && categoryId == null) return;
                          await s.saveBudget(Budget(
                            id: budget?.id,
                            categoryId: isOverall ? null : categoryId,
                            amount: double.parse(amount.text),
                          ));
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
      ),
    ),
  );
}
