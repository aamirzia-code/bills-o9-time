import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

class BillForm extends StatefulWidget {
  final Bill? bill;
  const BillForm({super.key, this.bill});

  @override
  State<BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<BillForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  late DateTime _due;
  late Repeat _repeat;
  late int _remind;
  int? _categoryId;
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _name = TextEditingController(text: b?.name ?? '');
    _amount = TextEditingController(
        text: b == null
            ? ''
            : (b.amount == b.amount.roundToDouble()
                ? b.amount.toStringAsFixed(0)
                : b.amount.toString()));
    _notes = TextEditingController(text: b?.notes ?? '');
    _due = b?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _repeat = b?.repeat ?? Repeat.monthly;
    _remind = b?.remindDaysBefore ?? 2;
    _categoryId = b?.categoryId;
    _accountId = context.read<AppState>().account(b?.accountId)?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = context.read<AppState>();
    await s.saveBill(Bill(
      id: widget.bill?.id,
      name: _name.text.trim(),
      amount: double.parse(_amount.text),
      categoryId: _categoryId,
      accountId: _accountId,
      dueDate: DateTime(_due.year, _due.month, _due.day, 9),
      repeat: _repeat,
      remindDaysBefore: _remind,
      notes: _notes.text.trim(),
      active: true,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cats = s.categoriesOf(TxType.expense);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.bill == null ? 'New bill' : 'Edit bill')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save bill'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Bill name', hintText: 'e.g. K-Electric, PTCL'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            MoneyField(controller: _amount),
            const SizedBox(height: 12),
            DateField(
                label: widget.bill == null ? 'First due date' : 'Next due date',
                value: _due,
                onChanged: (d) => setState(() => _due = d)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Repeat>(
              value: _repeat,
              decoration: const InputDecoration(labelText: 'Repeats'),
              items: [
                for (final r in Repeat.values)
                  DropdownMenuItem(value: r, child: Text(repeatLabel(r))),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? _repeat),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _remind,
              decoration: const InputDecoration(labelText: 'Reminder'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('On the due date only')),
                DropdownMenuItem(value: 1, child: Text('1 day before')),
                DropdownMenuItem(value: 2, child: Text('2 days before')),
                DropdownMenuItem(value: 3, child: Text('3 days before')),
                DropdownMenuItem(value: 5, child: Text('5 days before')),
                DropdownMenuItem(value: 7, child: Text('1 week before')),
              ],
              onChanged: (v) => setState(() => _remind = v ?? _remind),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _accountId,
              decoration: const InputDecoration(labelText: 'Pay from (optional)'),
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
              categories: cats,
              selected: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notes (account no., biller ID…)'),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll get a notification at 9:00 AM ${_remind == 0 ? 'on the due date' : '$_remind day(s) before and on the due date'}. Next: ${Fmt.date(_due)}.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
