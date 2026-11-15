import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import '../i18n.dart';
import '../features/currency.dart';
import '../features/logic.dart';

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
        Builder(builder: (context) {
          final st = context.watch<AppState>();
          final label = st.monthStart == 1
              ? Fmt.month(month)
              : '${Fmt.shortDate(st.periodStart(month))} – ${Fmt.shortDate(st.periodEnd(month).subtract(const Duration(days: 1)))}';
          return Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
        }),
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
  late DateTime _month = context.read<AppState>().currentMonth;
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
      appBar: AppBar(title: Text(tr('Transactions'))),
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

void openTxnForm(BuildContext context,
    {Txn? txn, TxType? type, Txn? prefill, bool pasteSms = false}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TxnForm(
              txn: txn, type: type, prefill: prefill, pasteSms: pasteSms)));
}

class TxnForm extends StatefulWidget {
  final Txn? txn;
  final TxType? type;

  /// Values for a new transaction (from Zakat, plans, subscriptions…).
  final Txn? prefill;

  /// Open the "paste bank SMS" box straight away.
  final bool pasteSms;
  const TxnForm(
      {super.key, this.txn, this.type, this.prefill, this.pasteSms = false});

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
  String _currency = ''; // '' = home currency
  final List<String> _newPhotos = []; // base64 JPEG, saved with the txn
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.txn ?? widget.prefill;
    _type = t?.type ?? widget.type ?? TxType.expense;
    _amount = TextEditingController(
        text: t == null || t.amount == 0
            ? ''
            : (t.amount == t.amount.roundToDouble()
                ? t.amount.toStringAsFixed(0)
                : t.amount.toString()));
    _note = TextEditingController(text: t?.note ?? '');
    _date = t?.date ?? DateTime.now();
    _categoryId = t?.categoryId;
    final s = context.read<AppState>();
    _accountId = t?.accountId != null
        ? s.account(t!.accountId)?.id
        : (s.accounts.isNotEmpty ? s.accounts.first.id : null);
    if (widget.pasteSms) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pasteSms());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  FxRate? _fx(AppState s) {
    for (final f in fxRates(s)) {
      if (f.code == _currency) return f;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_categoryId == null) {
      toast(context, 'Pick a category');
      return;
    }
    final s = context.read<AppState>();
    var amount = double.parse(_amount.text);
    var note = _note.text.trim();
    final fx = _fx(s);
    if (fx != null) {
      note = '${note.isEmpty ? '' : '$note '}(${fx.code} ${_amount.text} @ ${fx.rate})';
      amount = double.parse((amount * fx.rate).toStringAsFixed(2));
    }
    setState(() => _saving = true);
    final id = await s.saveTxnReturningId(Txn(
      id: widget.txn?.id,
      type: _type,
      amount: amount,
      categoryId: _categoryId,
      accountId: _accountId,
      date: _date,
      note: note,
      billId: widget.txn?.billId,
      dueDate: widget.txn?.dueDate,
    ));
    for (final p in _newPhotos) {
      await s.addAttachment(id, p);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pasteSms() async {
    final s = context.read<AppState>();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final c = TextEditingController(text: clip?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Paste bank SMS')),
        content: TextField(
          controller: c,
          autofocus: (clip?.text ?? '').isEmpty,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
              hintText:
                  'Paste a bank, card, JazzCash or Easypaisa alert here'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Read')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final p = parseBankSms(text);
    if (p.amount == null) {
      toast(context, 'Couldn\'t find an amount in that message');
      return;
    }
    setState(() {
      if (_type != p.type) {
        _type = p.type;
        _categoryId = null;
      }
      final cur = p.currency;
      final homeIsPkr = ['RS', 'PKR'].contains(s.currency.toUpperCase());
      if (cur != null &&
          !(cur == 'PKR' && homeIsPkr) &&
          cur != s.currency.toUpperCase() &&
          fxRates(s).any((f) => f.code == cur)) {
        _currency = cur;
      }
      _amount.text = p.amount == p.amount!.roundToDouble()
          ? p.amount!.toStringAsFixed(0)
          : p.amount!.toString();
      if (p.merchant != null) _note.text = p.merchant!;
      if (p.date != null) _date = p.date!;
      if (p.last4 != null) {
        for (final a in s.accounts) {
          if (a.name.contains(p.last4!)) _accountId = a.id;
        }
      }
    });
    toast(context,
        'Filled from SMS: ${p.type == TxType.income ? 'income' : 'expense'} ${p.currency ?? ''} ${p.amount}');
  }

  Future<void> _addPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
          source: src, maxWidth: 1200, maxHeight: 1600, imageQuality: 60);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => _newPhotos.add(base64Encode(bytes)));
    } catch (e) {
      if (mounted) toast(context, 'Could not add photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final fxList = fxRates(s);
    final fx = _fx(s);
    final saved = s.attachmentsFor(widget.txn?.id);
    final converted = fx == null
        ? null
        : (double.tryParse(_amount.text) ?? 0) * fx.rate;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.txn == null ? 'New transaction' : 'Edit transaction')),
        actions: [
          IconButton(
            tooltip: tr('Paste bank SMS'),
            icon: const Icon(Icons.sms_outlined),
            onPressed: _pasteSms,
          ),
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
            onPressed: _saving ? null : _save,
            child: Text(tr('Save')),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TxType>(
              segments: [
                ButtonSegment(
                    value: TxType.expense,
                    label: Text(tr('Expense')),
                    icon: const Icon(Icons.north_east_rounded)),
                ButtonSegment(
                    value: TxType.income,
                    label: Text(tr('Income')),
                    icon: const Icon(Icons.south_west_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyField(
                      controller: _amount,
                      autofocus: widget.txn == null && widget.prefill == null,
                      label: fx == null ? tr('Amount') : '${tr('Amount')} (${fx.code})'),
                ),
                if (fxList.isNotEmpty && widget.txn == null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'In'),
                      items: [
                        DropdownMenuItem(value: '', child: Text(s.currency)),
                        for (final f in fxList)
                          DropdownMenuItem(value: f.code, child: Text(f.code)),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? ''),
                    ),
                  ),
                ],
              ],
            ),
            if (converted != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text('= ${Fmt.money(converted)} at ${fx!.rate}',
                    style: TextStyle(
                        fontSize: 12.5, color: cs.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Description', hintText: 'e.g. Imtiaz groceries'),
            ),
            const SizedBox(height: 12),
            DateField(
                label: tr('Date'),
                value: _date,
                onChanged: (d) => setState(() => _date = DateTime(
                    d.year, d.month, d.day, _date.hour, _date.minute))),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _accountId,
              decoration: InputDecoration(labelText: tr('Account')),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                for (final a in s.accounts)
                  DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 20),
            Text(tr('Category'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            CategoryPicker(
              categories: s.categoriesOf(_type),
              selected: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Receipt / bill photo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  tooltip: 'Camera',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () => _addPhoto(ImageSource.camera),
                ),
                IconButton(
                  tooltip: 'Photos',
                  icon: const Icon(Icons.photo_library_outlined),
                  onPressed: () => _addPhoto(ImageSource.gallery),
                ),
              ],
            ),
            if (saved.isEmpty && _newPhotos.isEmpty)
              Text('Optional. Photos are stored in the app and included in your encrypted backup.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in saved) ReceiptThumb(attachmentId: a.id),
                for (var i = 0; i < _newPhotos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(_newPhotos[i]),
                            width: 84, height: 84, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _newPhotos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved receipt photo; tap to view full size or delete.
class ReceiptThumb extends StatelessWidget {
  final int attachmentId;
  const ReceiptThumb({super.key, required this.attachmentId});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return FutureBuilder<String?>(
      future: s.attachmentData(attachmentId),
      builder: (context, snap) {
        if (snap.data == null) {
          return const SizedBox(
              width: 84, height: 84, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final bytes = base64Decode(snap.data!);
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await s.deleteAttachment(attachmentId);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                body: InteractiveViewer(
                    child: Center(child: Image.memory(bytes))),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
