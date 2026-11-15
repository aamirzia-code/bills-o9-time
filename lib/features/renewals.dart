import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

class RenewalKind {
  final String id;
  final String label;
  final IconData icon;
  final int years;
  const RenewalKind(this.id, this.label, this.icon, this.years);
}

const kRenewalKinds = [
  RenewalKind('vehicle', 'Vehicle token / tax', Icons.directions_car_rounded, 1),
  RenewalKind('insurance', 'Insurance', Icons.shield_rounded, 1),
  RenewalKind('id', 'ID card / licence', Icons.badge_rounded, 10),
  RenewalKind('passport', 'Passport / visa', Icons.flight_takeoff_rounded, 5),
  RenewalKind('warranty', 'Warranty', Icons.verified_rounded, 0),
  RenewalKind('subscription', 'Membership / domain', Icons.subscriptions_rounded, 1),
  RenewalKind('health', 'Checkup / vaccine', Icons.medical_services_rounded, 1),
  RenewalKind('other', 'Other', Icons.event_repeat_rounded, 1),
];

RenewalKind renewalKind(String id) =>
    kRenewalKinds.firstWhere((k) => k.id == id, orElse: () => kRenewalKinds.last);

Color expiryColor(int days) => days < 0
    ? const Color(0xFFEF4444)
    : days <= 30
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);

String expiryLabel(int days) => days < 0
    ? 'Expired ${-days}d ago'
    : days == 0
        ? 'Expires today'
        : days < 60
            ? 'in $days days'
            : 'in ${(days / 30).round()} months';

/// Things that expire: vehicle token, insurance, CNIC, passport,
/// warranties… with reminders ahead of time.
class RenewalsScreen extends StatelessWidget {
  const RenewalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final soon = s.renewals.where((r) => r.daysLeft() <= r.remindDays).toList();
    final later = s.renewals.where((r) => r.daysLeft() > r.remindDays).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Renewals & warranties')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'renew-fab',
        onPressed: () => showRenewalSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: s.renewals.isEmpty
          ? const EmptyState(
              icon: Icons.event_repeat_rounded,
              title: 'Never miss an expiry',
              subtitle:
                  'Track car token, insurance, ID card, passport, licence and product warranties. You\'ll get an alert before each one runs out.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                if (soon.isNotEmpty) const SectionTitle('Needs attention'),
                for (final r in soon) _RenewalTile(r),
                if (later.isNotEmpty) const SectionTitle('Coming up'),
                for (final r in later) _RenewalTile(r),
                const SizedBox(height: 8),
                Text('Tip: keep a photo of the receipt for warranties in the expense\'s receipt section.',
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ],
            ),
    );
  }
}

class _RenewalTile extends StatelessWidget {
  final Renewal r;
  const _RenewalTile(this.r);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = r.daysLeft();
    final k = renewalKind(r.kind);
    final color = expiryColor(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => showRenewalSheet(context, r: r),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.14),
              child: Icon(k.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${Fmt.date(r.expiry)}${r.cost > 0 ? ' · ${Fmt.money(r.cost)}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(expiryLabel(d),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showRenewalSheet(BuildContext context, {Renewal? r}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RenewalForm(r: r),
  );
}

class _RenewalForm extends StatefulWidget {
  final Renewal? r;
  const _RenewalForm({this.r});
  @override
  State<_RenewalForm> createState() => _RenewalFormState();
}

class _RenewalFormState extends State<_RenewalForm> {
  late final _name = TextEditingController(text: widget.r?.name ?? '');
  late final _cost = TextEditingController(
      text: (widget.r?.cost ?? 0) > 0 ? widget.r!.cost.toStringAsFixed(0) : '');
  late final _notes = TextEditingController(text: widget.r?.notes ?? '');
  late String _kind = widget.r?.kind ?? 'vehicle';
  late DateTime _expiry = widget.r?.expiry ?? DateTime.now().add(const Duration(days: 365));
  late int _remind = widget.r?.remindDays ?? 14;
  late int _years = widget.r?.everyYears ?? 1;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Renewal _build() => Renewal(
        id: widget.r?.id,
        name: _name.text.trim().isEmpty ? renewalKind(_kind).label : _name.text.trim(),
        kind: _kind,
        expiry: _expiry,
        remindDays: _remind,
        cost: double.tryParse(_cost.text) ?? 0,
        everyYears: _years,
        notes: _notes.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final r = widget.r;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r == null ? 'Add renewal' : 'Edit renewal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in kRenewalKinds)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 17),
                    label: Text(k.label),
                    selected: _kind == k.id,
                    onSelected: (_) => setState(() {
                      _kind = k.id;
                      if (r == null) _years = k.years;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: _kind == 'warranty' ? 'Samsung fridge' : renewalKind(_kind).label),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DateField(
                      label: _kind == 'warranty' ? 'Warranty ends' : 'Expires on',
                      value: _expiry,
                      onChanged: (d) => setState(() => _expiry = d)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Renewal cost', prefixText: '${Fmt.symbol} '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _remind,
                    decoration: const InputDecoration(labelText: 'Remind me'),
                    items: [
                      for (final d in const [3, 7, 14, 30, 60])
                        DropdownMenuItem(value: d, child: Text('$d days before')),
                    ],
                    onChanged: (v) => setState(() => _remind = v ?? 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _years,
                    decoration: const InputDecoration(labelText: 'Repeats'),
                    items: [
                      for (final y in const [0, 1, 2, 3, 5, 10])
                        DropdownMenuItem(
                            value: y,
                            child: Text(y == 0 ? 'Once' : y == 1 ? 'Every year' : 'Every $y years')),
                    ],
                    onChanged: (v) => setState(() => _years = v ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (policy no., shop, serial…)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () async {
                await s.putRow('renewals', _build().toMap());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
            if (r != null) ...[
              const SizedBox(height: 8),
              if (r.everyYears > 0)
                OutlinedButton.icon(
                  onPressed: () async {
                    final renewed = r.renewed();
                    await s.putRow('renewals', renewed.toMap());
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (r.cost > 0) {
                      final cat = await s.ensureCategory(
                          r.kind == 'vehicle' ? 'Car' : r.kind == 'insurance' ? 'Insurance' : 'Fees & renewals',
                          r.kind == 'vehicle' ? 'car' : r.kind == 'insurance' ? 'insurance' : 'other',
                          0xFF64748B);
                      if (!context.mounted) return;
                      openTxnForm(context,
                          prefill: Txn(
                              type: TxType.expense,
                              amount: r.cost,
                              categoryId: cat,
                              date: DateTime.now(),
                              note: '${r.name} renewal'));
                    } else {
                      toast(context, 'Renewed until ${Fmt.date(renewed.expiry)}');
                    }
                  },
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text('Mark renewed'),
                ),
              TextButton.icon(
                onPressed: () async {
                  await s.removeRow('renewals', r.id!);
                  if (context.mounted) Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
