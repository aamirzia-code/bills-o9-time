import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

class GoalsScreen extends StatelessWidget {
  final bool embedded;
  const GoalsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final savings = s.goals.where((g) => g.kind == GoalKind.saving).toList();
    final debts = s.goals.where((g) => g.kind == GoalKind.debt).toList();
    final totalDebt = debts.fold<double>(
        0, (x, g) => x + (g.target - s.goalProgress(g)).clamp(0.0, double.infinity));
    final totalSaved =
        savings.fold<double>(0, (x, g) => x + s.goalProgress(g));

    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Goals & Debts')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'goals-fab',
        tooltip: 'New goal',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GoalTemplatePicker())),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.savings_rounded,
                          color: Color(0xFF16A34A)),
                      const SizedBox(height: 8),
                      const Text('Total saved', style: TextStyle(fontSize: 12)),
                      FittedBox(
                        child: Text(Fmt.money(totalSaved),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.account_balance_rounded,
                          color: Color(0xFFDC2626)),
                      const SizedBox(height: 8),
                      const Text('Debt remaining',
                          style: TextStyle(fontSize: 12)),
                      FittedBox(
                        child: Text(Fmt.money(totalDebt),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('Savings goals'),
          if (savings.isEmpty)
            const _Hint('Save for a car, Umrah, emergency fund or vacation.'),
          for (final g in savings) GoalTile(g),
          const SectionTitle('Debt payoff'),
          if (debts.isEmpty)
            const _Hint('Track loans, credit cards or money you owe someone.'),
          for (final g in debts) GoalTile(g),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class GoalTile extends StatelessWidget {
  final Goal g;
  const GoalTile(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final done = s.goalProgress(g);
    final ratio = g.target == 0 ? 0.0 : done / g.target;
    final color = Color(g.color);
    final isDebt = g.kind == GoalKind.debt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GoalDetail(goalId: g.id!))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                      g.icon.isNotEmpty
                          ? iconFor(g.icon)
                          : isDebt
                              ? Icons.trending_down_rounded
                              : Icons.flag_rounded,
                      color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        g.deadline == null
                            ? (isDebt ? 'Debt' : 'Savings goal')
                            : 'Target ${Fmt.date(g.deadline!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text('${(ratio * 100).clamp(0, 999).round()}%',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            ProgressLine(value: ratio.clamp(0.0, 1.0), color: color),
            const SizedBox(height: 8),
            Text(
              isDebt
                  ? '${Fmt.money(done)} paid · ${Fmt.money((g.target - done).clamp(0.0, double.infinity))} left of ${Fmt.money(g.target)}'
                  : '${Fmt.money(done)} of ${Fmt.money(g.target)}',
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalDetail extends StatelessWidget {
  final int goalId;
  const GoalDetail({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Goal? goal;
    for (final x in s.goals) {
      if (x.id == goalId) goal = x;
    }
    if (goal == null) return const Scaffold(body: SizedBox.shrink());
    final g = goal;
    final done = s.goalProgress(g);
    final left = (g.target - done).clamp(0.0, double.infinity);
    final isDebt = g.kind == GoalKind.debt;
    final color = Color(g.color);
    String? perMonth;
    if (g.deadline != null && left > 0) {
      final now = DateTime.now();
      final months = (g.deadline!.year - now.year) * 12 +
          g.deadline!.month -
          now.month;
      if (months > 0) {
        perMonth = 'Put aside ${Fmt.money(left / months)}/month to hit your date';
      }
    }
    final monthlyInterest =
        isDebt && g.interestRate > 0 ? left * g.interestRate / 100 / 12 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GoalForm(goal: g))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, 'Delete ${g.name}?',
                  'All its entries will be removed.')) {
                await s.deleteGoal(g);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: left > 0
          ? FloatingActionButton.extended(
              onPressed: () => _addEntry(context, g),
              icon: const Icon(Icons.add_rounded),
              label: Text(isDebt ? 'Record payment' : 'Add money'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          AppCard(
            child: Column(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: g.target == 0 ? 0 : (done / g.target).clamp(0.0, 1.0),
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: color.withOpacity(0.14),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Center(
                        child: Text(
                          '${g.target == 0 ? 0 : (done / g.target * 100).clamp(0, 999).round()}%',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isDebt
                      ? '${Fmt.money(left)} still owed'
                      : '${Fmt.money(left)} to go',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('${Fmt.money(done)} of ${Fmt.money(g.target)}'),
                if (perMonth != null) ...[
                  const SizedBox(height: 8),
                  Text(perMonth,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ],
                if (monthlyInterest > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'At ${g.interestRate}% a year, interest is about ${Fmt.money(monthlyInterest)}/month',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
                if (left == 0) ...[
                  const SizedBox(height: 10),
                  Chip(
                    avatar: const Icon(Icons.celebration_rounded, size: 18),
                    label: Text(isDebt ? 'Debt free!' : 'Goal reached!'),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('History'),
          for (final e in s.entriesFor(g))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Fmt.money(e.amount),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              [Fmt.date(e.date), if (e.note.isNotEmpty) e.note]
                                  .join(' · '),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => s.deleteGoalEntry(e),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, Goal g) async {
    final s = context.read<AppState>();
    final amount = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    final key = GlobalKey<FormState>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoneyField(controller: amount, autofocus: true),
                const SizedBox(height: 12),
                DateField(
                    label: 'Date',
                    value: date,
                    onChanged: (d) => setSt(() => date = d)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!key.currentState!.validate()) return;
                    await s.addGoalEntry(GoalEntry(
                        goalId: g.id!,
                        amount: double.parse(amount.text),
                        date: date,
                        note: note.text.trim()));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoalForm extends StatefulWidget {
  final Goal? goal;
  final GoalTemplate? template;
  const GoalForm({super.key, this.goal, this.template});

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _key = GlobalKey<FormState>();
  late GoalKind _kind;
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _interest;
  DateTime? _deadline;
  late int _color;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    final t = widget.template;
    _kind = g?.kind ?? t?.kind ?? GoalKind.saving;
    _icon = g?.icon ?? t?.icon ?? '';
    _name = TextEditingController(
        text: g?.name ?? (t == null || t.icon == 'other' ? '' : t.title));
    _target =
        TextEditingController(text: g == null ? '' : g.target.toStringAsFixed(0));
    _interest = TextEditingController(
        text: g == null || g.interestRate == 0 ? '' : g.interestRate.toString());
    _deadline = g?.deadline;
    _color = g?.color ?? t?.color ?? kPalette[0];
  }

  late String _icon;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _interest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDebt = _kind == GoalKind.debt;
    return Scaffold(
      appBar: AppBar(title: Text(widget.goal == null ? 'New goal' : 'Edit')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () async {
              if (!_key.currentState!.validate()) return;
              await context.read<AppState>().saveGoal(Goal(
                    id: widget.goal?.id,
                    name: _name.text.trim(),
                    kind: _kind,
                    target: double.parse(_target.text),
                    interestRate: double.tryParse(_interest.text) ?? 0,
                    deadline: _deadline,
                    color: _color,
                    icon: _icon,
                  ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<GoalKind>(
              segments: const [
                ButtonSegment(
                    value: GoalKind.saving,
                    label: Text('Savings goal'),
                    icon: Icon(Icons.savings_rounded)),
                ButtonSegment(
                    value: GoalKind.debt,
                    label: Text('Debt'),
                    icon: Icon(Icons.account_balance_rounded)),
              ],
              selected: {_kind},
              onSelectionChanged: widget.goal == null
                  ? (v) => setState(() => _kind = v.first)
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: isDebt ? 'e.g. Car loan, HBL card' : 'e.g. New car'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            MoneyField(
                controller: _target,
                label: isDebt ? 'Total amount owed' : 'Target amount'),
            if (isDebt) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _interest,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Interest rate % per year (optional)'),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _deadline ??
                      DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _deadline = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: isDebt ? 'Pay off by (optional)' : 'Target date (optional)',
                  suffixIcon: _deadline == null
                      ? const Icon(Icons.calendar_month_rounded)
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _deadline = null),
                        ),
                ),
                child: Text(_deadline == null ? 'No date' : Fmt.date(_deadline!)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _color == c
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class GoalTemplate {
  final String title;
  final String icon;
  final GoalKind kind;
  final int color;
  const GoalTemplate(this.title, this.icon, this.kind, this.color);
}

const kGoalTemplates = [
  GoalTemplate('Buy a home', 'home', GoalKind.saving, 0xFFEA580C),
  GoalTemplate('Payoff debt', 'debt', GoalKind.debt, 0xFFDC2626),
  GoalTemplate('Buy a car', 'car', GoalKind.saving, 0xFF2563EB),
  GoalTemplate('Plan for retirement', 'retire', GoalKind.saving, 0xFF0891B2),
  GoalTemplate('Plan a vacation', 'travel', GoalKind.saving, 0xFF16A34A),
  GoalTemplate('Emergency fund', 'emergency', GoalKind.saving, 0xFF7C3AED),
  GoalTemplate('Education', 'school', GoalKind.saving, 0xFFCA8A04),
  GoalTemplate('Other', 'other', GoalKind.saving, 0xFF475569),
];

/// "What do you want to achieve?" grid shown before creating a goal.
class GoalTemplatePicker extends StatelessWidget {
  const GoalTemplatePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Goal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Setting a goal is the first step towards achieving it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          const Text('What do you want to achieve?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              for (final t in kGoalTemplates)
                AppCard(
                  onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GoalForm(template: t))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Color(t.color).withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconFor(t.icon),
                            size: 28, color: Color(t.color)),
                      ),
                      const SizedBox(height: 10),
                      Text(t.title,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
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
