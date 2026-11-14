import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

class MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthSwitcher({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(Fmt.month(month),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxType? _filter;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s
        .txnsInMonth(_month)
        .where((t) => _filter == null || t.type == _filter)
        .toList();
    final income = s.incomeInMonth(_month);
    final expense = s.expenseInMonth(_month);

    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(d, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'txn-fab',
        onPressed: () => openTxnForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          MonthSwitcher(
              month: _month, onChanged: (m) => setState(() => _month = m)),
          Row(
            children: [
              Expanded(
                  child: _Stat('Income', income, const Color(0xFF16A34A))),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat('Spent', expense, const Color(0xFFDC2626))),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat('Net', income - expense,
                      Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('All')),
              ButtonSegment(value: 1, label: Text('Expenses')),
              ButtonSegment(value: 2, label: Text('Income')),
            ],
            selected: {
              _filter == null ? 0 : (_filter == TxType.expense ? 1 : 2)
            },
            onSelectionChanged: (v) => setState(() {
              final i = v.first;
              _filter =
                  i == 0 ? null : (i == 1 ? TxType.expense : TxType.income);
            }),
          ),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.swap_vert_rounded,
              title: 'Nothing recorded',
              subtitle: 'Tap + to add an expense or income for this month.',
            ),
          for (final e in groups.entries) ...[
            SectionTitle(Fmt.day(e.key)),
            for (final t in e.value) TxnTile(t),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Fmt.money(value, compact: true),
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: color, fontSize: 15)),
            ),
          ],
        ),
      );
}

class TxnTile extends StatelessWidget {
  final Txn t;
  const TxnTile(this.t, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cat = s.category(t.categoryId);
    final acc = s.account(t.accountId);
    final isIncome = t.type == TxType.income;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('txn-${t.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) =>
            confirm(context, 'Delete transaction?', 'This can\'t be undone.'),
        onDismissed: (_) => s.deleteTxn(t),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          onTap: () => openTxnForm(context, txn: t),
          child: Row(
            children: [
              CategoryAvatar(cat, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.note.isNotEmpty ? t.note : (cat?.name ?? 'Other'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (t.note.isNotEmpty && cat != null) cat.name,
                        if (acc != null) acc.name,
                        if (t.billId != null) 'Bill',
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '−'} ${Fmt.money(t.amount)}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isIncome ? const Color(0xFF16A34A) : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void openTxnForm(BuildContext context, {Txn? txn, TxType? type}) {
  Navigator.push(context,
      MaterialPageRoute(builder: (_) => TxnForm(txn: txn, type: type)));
}

class TxnForm extends StatefulWidget {
  final Txn? txn;
  final TxType? type;
  const TxnForm({super.key, this.txn, this.type});

  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  final _form = GlobalKey<FormState>();
  late TxType _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  int? _categoryId;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    _type = t?.type ?? widget.type ?? TxType.expense;
    _amount = TextEditingController(
        text: t == null
            ? ''
            : (t.amount == t.amount.roundToDouble()
                ? t.amount.toStringAsFixed(0)
                : t.amount.toString()));
    _note = TextEditingController(text: t?.note ?? '');
    _date = t?.date ?? DateTime.now();
    _categoryId = t?.categoryId;
    final s = context.read<AppState>();
    _accountId = t != null
        ? s.account(t.accountId)?.id
        : (s.accounts.isNotEmpty ? s.accounts.first.id : null);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null) {
      toast(context, 'Pick a category');
      return;
    }
    await context.read<AppState>().saveTxn(Txn(
          id: widget.txn?.id,
          type: _type,
          amount: double.parse(_amount.text),
          categoryId: _categoryId,
          accountId: _accountId,
          date: _date,
          note: _note.text.trim(),
          billId: widget.txn?.billId,
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.txn == null ? 'New transaction' : 'Edit transaction'),
        actions: [
          if (widget.txn != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await confirm(
                    context, 'Delete transaction?', 'This can\'t be undone.')) {
                  await s.deleteTxn(widget.txn!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxType>(
              segments: const [
                ButtonSegment(
                    value: TxType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(
                    value: TxType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            MoneyField(controller: _amount, autofocus: widget.txn == null),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Description', hintText: 'e.g. Imtiaz groceries'),
            ),
            const SizedBox(height: 12),
            DateField(
                label: 'Date',
                value: _date,
                onChanged: (d) => setState(() => _date = DateTime(
                    d.year, d.month, d.day, _date.hour, _date.minute))),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (final a in s.accounts)
                  DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 20),
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            CategoryPicker(
              categories: s.categoriesOf(_type),
              selected: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
          ],
        ),
      ),
    );
  }
}
