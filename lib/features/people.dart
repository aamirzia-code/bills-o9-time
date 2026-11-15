import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

String _plain(double v) {
  final h = Fmt.hidden;
  Fmt.hidden = false;
  final out = Fmt.money(v);
  Fmt.hidden = h;
  return out;
}

/// Split & Udhaar: who owes you and whom you owe. Everything stays on this
/// phone; reminders go out as WhatsApp/SMS text, groups as a share link.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final owedToMe = s.people
        .map((p) => s.personBalance(p.id!))
        .where((b) => b > 0)
        .fold<double>(0, (a, b) => a + b);
    final iOwe = s.people
        .map((p) => s.personBalance(p.id!))
        .where((b) => b < 0)
        .fold<double>(0, (a, b) => a - b);
    final sorted = [...s.people]
      ..sort((a, b) => s.personBalance(b.id!).abs().compareTo(s.personBalance(a.id!).abs()));

    return Scaffold(
      appBar: AppBar(title: const Text('Split & Udhaar')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'people-fab',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SplitForm())),
        icon: const Icon(Icons.call_split_rounded),
        label: const Text('Split / lend'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Row(
            children: [
              Expanded(child: _total(context, 'Owed to you', owedToMe, _green)),
              const SizedBox(width: 10),
              Expanded(child: _total(context, 'You owe', iOwe, _red)),
            ],
          ),
          if (s.people.isEmpty)
            const EmptyState(
              icon: Icons.people_alt_rounded,
              title: 'Split bills, track udhaar',
              subtitle:
                  'Split a dinner or trip with friends, or note money you lent or borrowed. Send a friendly WhatsApp reminder in one tap.',
            ),
          if (s.people.isNotEmpty) const SectionTitle('People'),
          for (final p in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PersonDetail(id: p.id!))),
                child: Row(
                  children: [
                    _Avatar(p),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15.5)),
                    ),
                    _BalanceText(s.personBalance(p.id!)),
                  ],
                ),
              ),
            ),
          if (s.people.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Only you see this ledger. Use "Share" on a person to send them the details by WhatsApp or as a link.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _total(BuildContext context, String label, double v, Color color) =>
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(Fmt.money(v),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      );
}

class _Avatar extends StatelessWidget {
  final Person p;
  final double size;
  const _Avatar(this.p, {this.size = 42});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: Color(p.color).withOpacity(0.18),
        child: Text(
          p.name.isEmpty ? '?' : p.name.trim()[0].toUpperCase(),
          style: TextStyle(
              color: Color(p.color),
              fontWeight: FontWeight.w800,
              fontSize: size * 0.4),
        ),
      );
}

class _BalanceText extends StatelessWidget {
  final double b;
  const _BalanceText(this.b);
  @override
  Widget build(BuildContext context) {
    if (b.abs() < 0.5) {
      return Text('Settled',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(b > 0 ? 'owes you' : 'you owe',
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(Fmt.money(b.abs()),
            style: TextStyle(
                fontWeight: FontWeight.w800, color: b > 0 ? _green : _red)),
      ],
    );
  }
}

String reminderText(AppState s, Person p) {
  final b = s.personBalance(p.id!);
  final lines = s.ious
      .where((i) => i.personId == p.id && i.kind != IouKind.settle)
      .take(6)
      .map((i) =>
          '• ${DateFormat('d MMM').format(i.date)} ${i.note.isEmpty ? (i.group.isEmpty ? 'Expense' : i.group) : i.note}: ${_plain(i.amount.abs())}')
      .join('\n');
  final me = s.userName.isEmpty ? '' : '\n— ${s.userName}';
  if (b > 0) {
    return 'Hi ${p.name}! Quick reminder: ${_plain(b)} is pending from you.\n$lines\nThanks! 🙏$me';
  }
  if (b < 0) {
    return 'Hi ${p.name}, I owe you ${_plain(-b)}. Will settle soon.\n$lines$me';
  }
  return 'Hi ${p.name}, we\'re all settled. 👍$me';
}

/// Link that opens Bills O9 with this ledger mirrored for the other person.
String shareLink(AppState s, Person p) {
  final data = {
    'v': 1,
    'from': s.userName.isEmpty ? 'A friend' : s.userName,
    'cur': s.currency,
    'items': [
      for (final i in s.ious.where((i) => i.personId == p.id))
        [i.date.millisecondsSinceEpoch ~/ 1000, -i.amount, i.note, i.group, i.kind.index]
    ],
  };
  final enc = base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final b = Uri.base;
  final dir = b.path.substring(0, b.path.lastIndexOf('/') + 1);
  return '${b.origin}$dir?ledger=$enc';
}

class PersonDetail extends StatelessWidget {
  final int id;
  const PersonDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    Person? found;
    for (final x in s.people) {
      if (x.id == id) found = x;
    }
    if (found == null) return const Scaffold(body: SizedBox.shrink());
    final p = found;
    final b = s.personBalance(p.id!);
    final entries = s.ious.where((i) => i.personId == p.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final c = TextEditingController(text: p.name);
                final n = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Name'),
                    content: TextField(controller: c, autofocus: true),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, c.text.trim()),
                          child: const Text('Save')),
                    ],
                  ),
                );
                if (n != null && n.isNotEmpty) {
                  await s.putRow('people',
                      Person(id: p.id, name: n, phone: p.phone, color: p.color).toMap());
                }
              } else if (v == 'delete') {
                if (await confirm(context, 'Delete ${p.name}?',
                    'Their whole ledger will be removed.')) {
                  await s.removeWhere('ious', 'person_id = ?', [p.id]);
                  await s.removeRow('people', p.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete person')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          AppCard(
            child: Column(
              children: [
                _Avatar(p, size: 60),
                const SizedBox(height: 10),
                Text(
                    b.abs() < 0.5
                        ? 'All settled'
                        : b > 0
                            ? '${p.name} owes you'
                            : 'You owe ${p.name}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                Text(Fmt.money(b.abs()),
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: b.abs() < 0.5 ? null : (b > 0 ? _green : _red))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: b.abs() < 0.5
                            ? null
                            : () async {
                                if (await confirm(
                                    context,
                                    'Settle up?',
                                    b > 0
                                        ? 'Record that ${p.name} paid you ${_plain(b)}.'
                                        : 'Record that you paid ${p.name} ${_plain(-b)}.',
                                    ok: 'Settle')) {
                                  await s.putRow(
                                      'ious',
                                      Iou(
                                        personId: p.id!,
                                        amount: -b,
                                        note: 'Settled up',
                                        date: DateTime.now(),
                                        kind: IouKind.settle,
                                      ).toMap());
                                }
                              },
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Settle up'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(context, s, p),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SplitForm(personId: p.id))),
                  icon: const Icon(Icons.call_split_rounded),
                  label: const Text('Split'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SplitForm(personId: p.id, loan: true))),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Lend / borrow'),
                ),
              ),
            ],
          ),
          const SectionTitle('History'),
          if (entries.isEmpty)
            Text('Nothing yet.', style: TextStyle(color: cs.onSurfaceVariant)),
          for (final i in entries)
            Dismissible(
              key: ValueKey('iou-${i.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                child: const Icon(Icons.delete_rounded, color: _red),
              ),
              onDismissed: (_) => s.removeRow('ious', i.id!),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        i.kind == IouKind.settle
                            ? Icons.handshake_outlined
                            : i.kind == IouKind.loan
                                ? Icons.swap_horiz_rounded
                                : Icons.call_split_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.note.isEmpty ? 'Expense' : i.note,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                                [
                                  Fmt.date(i.date),
                                  if (i.group.isNotEmpty) i.group
                                ].join(' · '),
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text(
                        '${i.amount > 0 ? '+' : '−'}${Fmt.money(i.amount.abs())}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: i.amount > 0 ? _green : _red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, AppState s, Person p) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: _green),
              title: const Text('Send reminder message'),
              subtitle: const Text('WhatsApp, SMS or any app'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(reminderText(s, p));
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Share as link'),
              subtitle: const Text(
                  'If they use Bills O9, the link adds this ledger to their app'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(
                    '${reminderText(s, p)}\n\nOpen in Bills O9 Time: ${shareLink(s, p)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: reminderText(s, p)));
                Navigator.pop(ctx);
                toast(context, 'Copied');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Split an expense with people, or record money lent / borrowed.
class SplitForm extends StatefulWidget {
  final int? personId;
  final bool loan;
  const SplitForm({super.key, this.personId, this.loan = false});

  @override
  State<SplitForm> createState() => _SplitFormState();
}

enum _SplitMode { equal, exact, percent }

class _SplitFormState extends State<SplitForm> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _group = TextEditingController();
  final _newPerson = TextEditingController();
  late bool _loan = widget.loan;
  bool _iPaid = true; // split: I paid / they paid
  bool _iLent = true; // loan: I lent / I borrowed
  int? _payer; // person id when someone else paid
  bool _includeMe = true;
  bool _recordMyShare = true;
  _SplitMode _mode = _SplitMode.equal;
  final Set<int> _selected = {};
  final Map<int, TextEditingController> _custom = {};
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.personId != null) _selected.add(widget.personId!);
  }

  @override
  void dispose() {
    for (final c in [_amount, _note, _group, _newPerson, ..._custom.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(int id) =>
      _custom.putIfAbsent(id, () => TextEditingController());

  Future<void> _addPerson(AppState s) async {
    final name = _newPerson.text.trim();
    if (name.isEmpty) return;
    final id = await s.putRow(
        'people',
        Person(name: name, color: kPalette[s.people.length % kPalette.length])
            .toMap());
    _newPerson.clear();
    setState(() => _selected.add(id));
  }

  /// Share of each selected person (and me) of [total].
  Map<int, double>? _shares(double total) {
    final ids = _selected.toList();
    final n = ids.length + (_includeMe ? 1 : 0);
    if (n == 0) return null;
    switch (_mode) {
      case _SplitMode.equal:
        final each = total / n;
        return {for (final id in ids) id: each, if (_includeMe) -1: each};
      case _SplitMode.exact:
        final m = {for (final id in ids) id: double.tryParse(_ctl(id).text) ?? 0};
        final rest = total - m.values.fold(0.0, (a, b) => a + b);
        if (_includeMe) m[-1] = rest;
        return m;
      case _SplitMode.percent:
        final m = {
          for (final id in ids) id: total * (double.tryParse(_ctl(id).text) ?? 0) / 100
        };
        final rest = total - m.values.fold(0.0, (a, b) => a + b);
        if (_includeMe) m[-1] = rest;
        return m;
    }
  }

  Future<void> _save(AppState s) async {
    if (!_key.currentState!.validate()) return;
    if (_selected.isEmpty) {
      toast(context, 'Pick at least one person');
      return;
    }
    final total = double.parse(_amount.text);
    final note = _note.text.trim();
    final group = _group.text.trim();
    if (_loan) {
      for (final id in _selected) {
        await s.putRow(
            'ious',
            Iou(
              personId: id,
              amount: _iLent ? total : -total,
              note: note.isEmpty ? (_iLent ? 'Lent' : 'Borrowed') : note,
              date: _date,
              group: group,
              kind: IouKind.loan,
            ).toMap());
      }
    } else {
      final shares = _shares(total)!;
      if (shares.values.any((v) => v < -0.01)) {
        toast(context, 'Shares add up to more than the total');
        return;
      }
      if (_iPaid) {
        for (final id in _selected) {
          await s.putRow(
              'ious',
              Iou(personId: id, amount: shares[id]!, note: note, date: _date, group: group)
                  .toMap());
        }
      } else if (_payer != null && _includeMe) {
        await s.putRow(
            'ious',
            Iou(personId: _payer!, amount: -(shares[-1] ?? 0), note: note, date: _date, group: group)
                .toMap());
      }
      final mine = shares[-1] ?? 0;
      if (_recordMyShare && _includeMe && mine > 0) {
        final cid = s.recalledCategory(note) ??
            await s.ensureCategory('Shared expenses', 'family', 0xFF0891B2);
        await s.saveTxnReturningId(Txn(
          type: TxType.expense,
          amount: double.parse(mine.toStringAsFixed(2)),
          categoryId: cid,
          accountId: s.accounts.isEmpty ? null : s.accounts.first.id,
          date: _date,
          note: '${note.isEmpty ? 'Shared' : note} (my share)',
        ));
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final total = double.tryParse(_amount.text) ?? 0;
    final shares = _loan ? null : _shares(total);

    return Scaffold(
      appBar: AppBar(title: Text(_loan ? 'Lend or borrow' : 'Split an expense')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () => _save(s),
            child: const Text('Save'),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Split expense'), icon: Icon(Icons.call_split_rounded)),
                ButtonSegment(value: true, label: Text('Lend / borrow'), icon: Icon(Icons.swap_horiz_rounded)),
              ],
              selected: {_loan},
              onSelectionChanged: (v) => setState(() => _loan = v.first),
            ),
            const SizedBox(height: 16),
            MoneyField(
                controller: _amount,
                autofocus: true,
                label: _loan ? 'Amount' : 'Total bill',
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'What for?', hintText: 'Dinner, trip, rent…'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _group,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Group (optional)', hintText: 'Murree trip'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d))),
              ],
            ),
            const SectionTitle('People'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in s.people)
                  FilterChip(
                    avatar: _Avatar(p, size: 22),
                    label: Text(p.name),
                    selected: _selected.contains(p.id),
                    onSelected: (v) => setState(() =>
                        v ? _selected.add(p.id!) : _selected.remove(p.id)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPerson,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _addPerson(s),
                    decoration: const InputDecoration(
                        hintText: 'Add a person', prefixIcon: Icon(Icons.person_add_alt_rounded)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: () => _addPerson(s), icon: const Icon(Icons.add_rounded)),
              ],
            ),
            if (_loan) ...[
              const SectionTitle('Direction'),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('I lent')),
                  ButtonSegment(value: false, label: Text('I borrowed')),
                ],
                selected: {_iLent},
                onSelectionChanged: (v) => setState(() => _iLent = v.first),
              ),
            ] else ...[
              const SectionTitle('Who paid?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('I paid'),
                    selected: _iPaid,
                    onSelected: (_) => setState(() => _iPaid = true),
                  ),
                  for (final p in s.people.where((p) => _selected.contains(p.id)))
                    ChoiceChip(
                      label: Text('${p.name} paid'),
                      selected: !_iPaid && _payer == p.id,
                      onSelected: (_) => setState(() {
                        _iPaid = false;
                        _payer = p.id;
                      }),
                    ),
                ],
              ),
              const SectionTitle('How to split'),
              SegmentedButton<_SplitMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _SplitMode.equal, label: Text('Equally')),
                  ButtonSegment(value: _SplitMode.exact, label: Text('Amounts')),
                  ButtonSegment(value: _SplitMode.percent, label: Text('%')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include me'),
                value: _includeMe,
                onChanged: (v) => setState(() => _includeMe = v),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (final p in s.people.where((p) => _selected.contains(p.id)))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            _Avatar(p, size: 30),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p.name)),
                            if (_mode == _SplitMode.equal)
                              Text(Fmt.money(shares?[p.id] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w700))
                            else
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: _ctl(p.id!),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: _mode == _SplitMode.percent ? '%' : null,
                                    prefixText: _mode == _SplitMode.exact ? '${Fmt.symbol} ' : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_includeMe)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const CircleAvatar(radius: 15, child: Icon(Icons.person_rounded, size: 18)),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Me')),
                            Text(Fmt.money(shares?[-1] ?? 0),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: (shares?[-1] ?? 0) < -0.01 ? _red : null)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_includeMe)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add my share to my expenses'),
                  subtitle: const Text('So your budget stays accurate'),
                  value: _recordMyShare,
                  onChanged: (v) => setState(() => _recordMyShare = v),
                ),
              if (!_iPaid && !_includeMe)
                Text('When someone else paid and you\'re not included, nothing is owed by you.',
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opened from a shared ledger link (?ledger=…).
class LedgerImportScreen extends StatefulWidget {
  final String encoded;
  const LedgerImportScreen({super.key, required this.encoded});

  @override
  State<LedgerImportScreen> createState() => _LedgerImportScreenState();
}

class _LedgerImportScreenState extends State<LedgerImportScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      var e = widget.encoded;
      while (e.length % 4 != 0) {
        e += '=';
      }
      _data = (jsonDecode(utf8.decode(base64Url.decode(e))) as Map).cast<String, dynamic>();
    } catch (_) {
      _error = 'This link looks incomplete or damaged.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final items = (_data?['items'] as List?) ?? const [];
    final from = (_data?['from'] as String?) ?? 'A friend';
    final total = items.fold<double>(0, (a, i) => a + ((i as List)[1] as num).toDouble());
    return Scaffold(
      appBar: AppBar(title: const Text('Shared ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            EmptyState(icon: Icons.link_off_rounded, title: 'Can\'t open link', subtitle: _error!)
          else ...[
            AppCard(
              child: Column(
                children: [
                  Text('$from shared their ledger with you', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(
                    total.abs() < 0.5
                        ? 'All settled'
                        : total > 0
                            ? '$from owes you ${Fmt.money(total)}'
                            : 'You owe $from ${Fmt.money(-total)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  if ((_data?['cur'] as String?) != null && _data!['cur'] != s.currency)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Amounts are in ${_data!['cur']}',
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final raw in items)
              Builder(builder: (context) {
                final i = raw as List;
                final amt = (i[1] as num).toDouble();
                return ListTile(
                  dense: true,
                  title: Text((i[2] as String).isEmpty ? 'Expense' : i[2] as String),
                  subtitle: Text(Fmt.date(DateTime.fromMillisecondsSinceEpoch((i[0] as int) * 1000))),
                  trailing: Text('${amt > 0 ? '+' : '−'}${Fmt.money(amt.abs())}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: amt > 0 ? _green : _red)),
                );
              }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final existing = s.people.where((p) => p.name.toLowerCase() == from.toLowerCase());
                final pid = existing.isNotEmpty
                    ? existing.first.id!
                    : await s.putRow('people',
                        Person(name: from, color: kPalette[s.people.length % kPalette.length]).toMap());
                await s.removeWhere('ious', 'person_id = ?', [pid]);
                for (final raw in items) {
                  final i = raw as List;
                  await s.putRow(
                      'ious',
                      Iou(
                        personId: pid,
                        amount: (i[1] as num).toDouble(),
                        note: i[2] as String,
                        date: DateTime.fromMillisecondsSinceEpoch((i[0] as int) * 1000),
                        group: i[3] as String,
                        kind: IouKind.values[(i[4] as int).clamp(0, 2)],
                      ).toMap());
                }
                if (!context.mounted) return;
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => PersonDetail(id: pid)));
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Save to my Split & Udhaar'),
            ),
            const SizedBox(height: 8),
            Text('Saving replaces any earlier copy of $from\'s ledger. Nothing is uploaded anywhere.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
