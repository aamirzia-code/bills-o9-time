import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// Committee / BC tracker: rotating savings where each member pays a share
/// every month and one member receives the whole pot in turn.
class CommitteesScreen extends StatelessWidget {
  const CommitteesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final active = s.committees.where((c) => !c.finished).toList();
    final done = s.committees.where((c) => c.finished).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Committees'))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'committee-fab',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CommitteeForm())),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (s.committees.isEmpty)
            const EmptyState(
              icon: Icons.groups_rounded,
              title: 'No committees yet',
              subtitle:
                  'Track a committee (BC): members, monthly share, payout order and who has paid each round.',
            ),
          for (final c in active) _CommitteeCard(c),
          if (done.isNotEmpty) ...[
            SectionTitle(tr('Completed')),
            for (final c in done) _CommitteeCard(c),
          ],
          if (s.committees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tip: mark each member as paid in the current round. Your own monthly share can also be added as a bill so it shows in reminders.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommitteeCard extends StatelessWidget {
  final Committee c;
  const _CommitteeCard(this.c);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = c.currentRound();
    final color = Color(c.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CommitteeDetail(id: c.id!))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.groups_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15.5)),
                      Text(
                          '${Fmt.money(c.share)}/month · ${c.rounds} members · pot ${Fmt.money(c.pot)}',
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProgressLine(value: c.rounds == 0 ? 0 : r / c.rounds, color: color),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(c.finished ? 'Completed' : 'Round $r of ${c.rounds}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  'Your turn: ${DateFormat('MMM yyyy').format(c.roundDate(c.myTurn))}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: r == c.myTurn ? _green : cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CommitteeDetail extends StatefulWidget {
  final int id;
  const CommitteeDetail({super.key, required this.id});

  @override
  State<CommitteeDetail> createState() => _CommitteeDetailState();
}

class _CommitteeDetailState extends State<CommitteeDetail> {
  int? _round;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    Committee? found;
    for (final x in s.committees) {
      if (x.id == widget.id) found = x;
    }
    if (found == null) return const Scaffold(body: SizedBox.shrink());
    final c = found;
    final round = (_round ?? c.currentRound()).clamp(1, c.rounds < 1 ? 1 : c.rounds);
    final receiver = c.rounds == 0 ? '' : c.members[round - 1];
    final paid = c.paidCount(round);

    Future<void> togglePaid(int m) async {
      final p = {...c.paid};
      final key = '$round:$m';
      p.contains(key) ? p.remove(key) : p.add(key);
      await s.saveCommittee(c.copyWith(paid: p));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => CommitteeForm(committee: c))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, 'Delete ${c.name}?',
                  'Its rounds and payment marks will be removed.')) {
                await s.deleteCommittee(c);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          AppCard(
            child: Row(
              children: [
                _stat(context, 'Share', Fmt.money(c.share)),
                _stat(context, 'Pot', Fmt.money(c.pot)),
                _stat(context, 'Your turn',
                    DateFormat('MMM yy').format(c.roundDate(c.myTurn))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: round > 1
                          ? () => setState(() => _round = round - 1)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Round $round · ${DateFormat('MMMM yyyy').format(c.roundDate(round))}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '$paid of ${c.rounds} paid · ${Fmt.money(paid * c.share)} collected',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: round < c.rounds
                          ? () => setState(() => _round = round + 1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: _green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${round == c.myTurn ? 'You' : receiver} receive${round == c.myTurn ? '' : 's'} the pot of ${Fmt.money(c.pot)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Checkbox(
                        value: c.payouts.contains(round),
                        onChanged: (v) async {
                          final p = {...c.payouts};
                          v == true ? p.add(round) : p.remove(round);
                          await s.saveCommittee(c.copyWith(payouts: p));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                for (var m = 0; m < c.rounds; m++)
                  CheckboxListTile(
                    dense: true,
                    value: c.isPaid(round, m),
                    onChanged: (_) => togglePaid(m),
                    title: Text(
                        '${m + 1}. ${c.members[m]}${m + 1 == c.myTurn ? ' (you)' : ''}'),
                    subtitle: Text(
                        'Receives ${DateFormat('MMM yyyy').format(c.roundDate(m + 1))}'),
                    secondary: Icon(
                      c.isPaid(round, m)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: c.isPaid(round, m) ? _green : cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          SectionTitle(tr('Schedule')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var r = 1; r <= c.rounds; r++)
                  ListTile(
                    dense: true,
                    onTap: () => setState(() => _round = r),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: r == round
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      child: Text('$r',
                          style: TextStyle(
                              fontSize: 12,
                              color: r == round ? Colors.white : cs.onSurface)),
                    ),
                    title: Text(c.members[r - 1] +
                        (r == c.myTurn ? ' (you)' : '')),
                    subtitle: Text(DateFormat('d MMM yyyy').format(c.roundDate(r))),
                    trailing: c.payouts.contains(r)
                        ? const Icon(Icons.task_alt_rounded, color: _green)
                        : Text('${c.paidCount(r)}/${c.rounds}',
                            style: TextStyle(
                                color: c.roundDate(r).isBefore(DateTime.now()) &&
                                        c.paidCount(r) < c.rounds
                                    ? _red
                                    : cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(child: Text(c.notes)),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}

class CommitteeForm extends StatefulWidget {
  final Committee? committee;
  const CommitteeForm({super.key, this.committee});

  @override
  State<CommitteeForm> createState() => _CommitteeFormState();
}

class _CommitteeFormState extends State<CommitteeForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _share;
  late List<String> _members;
  late final TextEditingController _notes;
  late DateTime _start;
  late int _myTurn;
  late int _color;

  @override
  void initState() {
    super.initState();
    final c = widget.committee;
    _name = TextEditingController(text: c?.name ?? '');
    _share = TextEditingController(
        text: c == null ? '' : c.share.toStringAsFixed(0));
    _members = [...?c?.members];
    if (_members.isEmpty) _members.add('Me');
    _notes = TextEditingController(text: c?.notes ?? '');
    final now = DateTime.now();
    _start = c?.start ?? DateTime(now.year, now.month, 1, 9);
    _myTurn = c?.myTurn ?? 1;
    _color = c?.color ?? kPalette[2];
  }

  @override
  void dispose() {
    _name.dispose();
    _share.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> get _memberList => _members;

  @override
  Widget build(BuildContext context) {
    final members = _memberList;
    final n = members.length;
    final turn = n == 0 ? 1 : _myTurn.clamp(1, n);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.committee == null ? 'New committee' : 'Edit committee')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: () async {
              if (!_key.currentState!.validate()) return;
              if (n < 2) {
                toast(context, 'Add at least 2 members');
                return;
              }
              final old = widget.committee;
              await context.read<AppState>().saveCommittee(Committee(
                    id: old?.id,
                    name: _name.text.trim(),
                    share: double.parse(_share.text),
                    start: DateTime(_start.year, _start.month, _start.day, 9),
                    members: members,
                    myTurn: turn,
                    paid: old?.paid ?? const {},
                    payouts: old?.payouts ?? const {},
                    color: _color,
                    notes: _notes.text.trim(),
                  ));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(tr('Save')),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Committee name', hintText: 'e.g. Office BC 2027'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            MoneyField(controller: _share, label: 'Monthly share per member'),
            const SizedBox(height: 12),
            DateField(
                label: 'First collection date',
                value: _start,
                onChanged: (d) => setState(() => _start = d)),
            const SizedBox(height: 12),
            Text('Members in payout order',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            NameListEditor(
              names: _members,
              hint: 'Add member',
              suggestions: [for (final p in context.watch<AppState>().people) p.name],
              onChanged: (v) => setState(() => _members = v),
            ),
            const SizedBox(height: 6),
            Text(
              n == 0
                  ? 'Add members — type a name and press return, or paste a list.'
                  : '$n members · $n rounds · pot ${Fmt.money((double.tryParse(_share.text) ?? 0) * n)} · ends ${DateFormat('MMM yyyy').format(DateTime(_start.year, _start.month + n - 1))}',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (n > 0)
              DropdownButtonFormField<int>(
                value: turn,
                decoration: const InputDecoration(labelText: 'My turn (payout round)'),
                items: [
                  for (var i = 1; i <= n; i++)
                    DropdownMenuItem(
                        value: i,
                        child: Text(
                            '$i · ${members[i - 1]} · ${DateFormat('MMM yyyy').format(DateTime(_start.year, _start.month + i - 1))}')),
                ],
                onChanged: (v) => setState(() => _myTurn = v ?? 1),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                for (final k in kPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = k),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(k),
                      child: _color == k
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
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
