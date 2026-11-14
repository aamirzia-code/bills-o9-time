import 'package:flutter/foundation.dart' show kIsWeb;
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
  late int _every;
  late bool _autoPay;
  late int _dueDay;
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
    final (rep, every) = normalizeRepeat(b?.repeat ?? Repeat.monthly, b?.every ?? 1);
    _repeat = rep;
    _every = every;
    _autoPay = b?.autoPay ?? false;
    _dueDay = (b != null && b.dueDay > 0) ? b.dueDay : _due.day;
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
      dueDay: repeatsByMonth(_repeat) ? _dueDay : 0,
      every: _repeat == Repeat.none ? 1 : _every,
      autoPay: _autoPay,
      remindDaysBefore: _remind,
      notes: _notes.text.trim(),
      active: true,
    ));
    if (mounted) Navigator.pop(context);
  }

  void _setDueDay(int day) {
    setState(() {
      _dueDay = day;
      _due = nextOccurrenceOfDay(day);
    });
  }

  void _setDate(DateTime d) {
    setState(() {
      _due = d;
      if (repeatsByMonth(_repeat)) {
        final isLast = DateTime(d.year, d.month + 1, 0).day == d.day;
        _dueDay = (isLast && _dueDay == kLastDay) ? kLastDay : d.day;
      }
    });
  }

  List<DateTime> _upcoming() {
    final list = <DateTime>[_due];
    if (_repeat == Repeat.none) return list;
    var d = _due;
    for (var i = 0; i < 3; i++) {
      d = nextDue(d, _repeat,
          dueDay: repeatsByMonth(_repeat) ? _dueDay : 0, every: _every);
      list.add(d);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final byMonth = repeatsByMonth(_repeat);
    final cs = Theme.of(context).colorScheme;
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
            DropdownButtonFormField<Repeat>(
              value: _repeat,
              decoration: const InputDecoration(labelText: 'Repeats'),
              items: [
                for (final r in kRepeatChoices)
                  DropdownMenuItem(value: r, child: Text(repeatLabel(r))),
              ],
              onChanged: (v) => setState(() {
                _repeat = v ?? _repeat;
                if (repeatsByMonth(_repeat) && _dueDay != kLastDay) {
                  _dueDay = _due.day;
                }
              }),
            ),
            if (_repeat != Repeat.none) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Repeat every'),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      onPressed: _every > 1
                          ? () => setState(() => _every--)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        scheduleLabel(_repeat, 0, every: _every)
                            .replaceFirst('Every ', ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      onPressed: _every < 36
                          ? () => setState(() => _every++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
            if (byMonth) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _dueDay,
                menuMaxHeight: 360,
                decoration: InputDecoration(
                  labelText: _repeat == Repeat.monthly && _every == 1
                      ? 'Due every month on'
                      : 'Due on day of the month',
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(
                        value: d, child: Text('The ${ordinal(d)}')),
                  const DropdownMenuItem(
                      value: kLastDay, child: Text('Last day of the month')),
                ],
                onChanged: (v) {
                  if (v != null) _setDueDay(v);
                },
              ),
              if (_dueDay >= 29 && _dueDay != kLastDay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    'In shorter months it moves to the last day, then returns to the ${ordinal(_dueDay)}.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            DateField(
                label: widget.bill == null ? 'First due date' : 'Next due date',
                value: _due,
                onChanged: _setDate),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, d) in _upcoming().indexed)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: i == 0
                        ? Icon(Icons.event_rounded, size: 16, color: cs.primary)
                        : null,
                    label: Text(Fmt.shortDate(d),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                i == 0 ? FontWeight.w700 : FontWeight.w500)),
                  ),
              ],
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
            Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                title: const Text('Auto Paid'),
                subtitle: const Text(
                    'Record the payment automatically on the due date (for auto-debit bills)'),
                value: _autoPay,
                onChanged: (v) => setState(() => _autoPay = v),
              ),
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
              kIsWeb
                  ? 'Reminder notifications work in the iPhone/Android app. On the web, due bills show on Home and the Bills tab. Next: ${Fmt.date(_due)}.'
                  : 'You\'ll get a notification at 9:00 AM ${_remind == 0 ? 'on the due date' : '$_remind day(s) before and on the due date'}. Next: ${Fmt.date(_due)}.',
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
