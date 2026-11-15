import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';

class _Tpl {
  final String name;
  final String icon;
  final int color;
  final double planned;
  const _Tpl(this.name, this.icon, this.color, this.planned);
}

class _PlanTemplate {
  final String title;
  final String subtitle;
  final DateTime start;
  final DateTime end;
  final List<_Tpl> items;
  const _PlanTemplate(this.title, this.subtitle, this.start, this.end, this.items);
}

// Approximate dates; they depend on moon sighting and can be edited.
final _templates = [
  _PlanTemplate(
    'Ramadan & Eid ul Fitr 2027',
    'About 8 Feb – 10 Mar 2027',
    DateTime(2027, 2, 8),
    DateTime(2027, 3, 12),
    const [
      _Tpl('Iftar & Sehri', 'food', 0xFFEA580C, 40000),
      _Tpl('Eid shopping', 'shopping', 0xFFDB2777, 35000),
      _Tpl('Eidi', 'gift', 0xFF16A34A, 15000),
      _Tpl('Zakat & Sadqa', 'gift', 0xFF0F766E, 0),
      _Tpl('Eid travel', 'travel', 0xFF2563EB, 0),
    ],
  ),
  _PlanTemplate(
    'Eid ul Adha 2027',
    'About 16 May 2027 (Qurbani)',
    DateTime(2027, 5, 1),
    DateTime(2027, 5, 20),
    const [
      _Tpl('Qurbani', 'family', 0xFF7C3AED, 120000),
      _Tpl('Eid shopping', 'shopping', 0xFFDB2777, 20000),
      _Tpl('Eidi', 'gift', 0xFF16A34A, 10000),
    ],
  ),
];

class SeasonsScreen extends StatelessWidget {
  const SeasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ramadan & Eid'))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'season-fab',
        onPressed: () => _newPlan(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (s.seasons.isEmpty)
            const EmptyState(
              icon: Icons.nightlight_round,
              title: 'Plan Ramadan & Eid',
              subtitle:
                  'Set amounts for iftar, Eid shopping, Eidi and Qurbani, then track spending against the plan.',
            ),
          for (final p in s.seasons) _SeasonCard(p),
        ],
      ),
    );
  }

  Future<void> _newPlan(BuildContext context) async {
    final s = context.read<AppState>();
    final pick = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _templates.length; i++)
              ListTile(
                leading: const Icon(Icons.nightlight_round),
                title: Text(_templates[i].title),
                subtitle: Text(_templates[i].subtitle),
                onTap: () => Navigator.pop(ctx, i),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_rounded),
              title: const Text('Custom plan'),
              subtitle: const Text('Wedding, travel, school admissions…'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (pick == null) return;
    final items = <SeasonItem>[];
    String name;
    DateTime start, end;
    if (pick >= 0) {
      final t = _templates[pick];
      for (final it in t.items) {
        final id = await s.ensureCategory(it.name, it.icon, it.color);
        items.add(SeasonItem(id, it.name, it.planned));
      }
      name = t.title;
      start = t.start;
      end = t.end;
    } else {
      name = 'My plan';
      start = DateTime.now();
      end = DateTime.now().add(const Duration(days: 30));
    }
    await s.saveSeason(SeasonPlan(name: name, start: start, end: end, items: items));
    if (!context.mounted) return;
    final created = s.seasons.firstWhere((p) => p.name == name);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => SeasonDetail(id: created.id!)));
  }
}

double _spent(AppState s, SeasonPlan p, int? categoryId) => s.txns
    .where((t) =>
        t.type == TxType.expense &&
        p.contains(t.date) &&
        categoryId != null &&
        t.categoryId == categoryId)
    .fold(0.0, (x, t) => x + t.amount);

class _SeasonCard extends StatelessWidget {
  final SeasonPlan p;
  const _SeasonCard(this.p);

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final spent = p.items.fold<double>(0, (x, i) => x + _spent(s, p, i.categoryId));
    final planned = p.planned;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SeasonDetail(id: p.id!))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.nightlight_round, color: Color(0xFFF5B000)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15.5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${Fmt.date(p.start)} – ${Fmt.date(p.end)}',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ProgressLine(
                value: planned == 0 ? 0 : spent / planned,
                color: const Color(0xFFF5B000)),
            const SizedBox(height: 8),
            Text('${Fmt.money(spent)} spent of ${Fmt.money(planned)} planned',
                style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class SeasonDetail extends StatelessWidget {
  final int id;
  const SeasonDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    SeasonPlan? found;
    for (final x in s.seasons) {
      if (x.id == id) found = x;
    }
    if (found == null) return const Scaffold(body: SizedBox.shrink());
    final p = found;
    final spentTotal =
        p.items.fold<double>(0, (x, i) => x + _spent(s, p, i.categoryId));

    Future<void> save(SeasonPlan np) => s.saveSeason(np);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final c = TextEditingController(text: p.name);
              final n = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Plan name'),
                  content: TextField(controller: c, autofocus: true),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: Text(tr('Save'))),
                  ],
                ),
              );
              if (n != null && n.isNotEmpty) {
                await save(SeasonPlan(
                    id: p.id, name: n, start: p.start, end: p.end, items: p.items));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, 'Delete ${p.name}?',
                  'Your transactions stay; only the plan is removed.')) {
                await s.deleteSeason(p);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'season-add',
        onPressed: () => _addItem(context, p),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DateField(
                        label: 'From',
                        value: p.start,
                        onChanged: (d) => save(SeasonPlan(
                            id: p.id, name: p.name, start: d, end: p.end, items: p.items)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DateField(
                        label: 'To',
                        value: p.end,
                        onChanged: (d) => save(SeasonPlan(
                            id: p.id, name: p.name, start: p.start, end: d, items: p.items)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text('${Fmt.money(spentTotal)} of ${Fmt.money(p.planned)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                    Text(
                      p.planned == 0
                          ? ''
                          : '${(spentTotal / p.planned * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressLine(
                    value: p.planned == 0 ? 0 : spentTotal / p.planned,
                    color: const Color(0xFFF5B000),
                    height: 10),
                const SizedBox(height: 8),
                Text('Dates are approximate (moon sighting) — adjust as needed.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.items.length; i++)
            Builder(builder: (context) {
              final it = p.items[i];
              final spent = _spent(s, p, it.categoryId);
              final cat = s.category(it.categoryId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CategoryAvatar(cat, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    '${Fmt.money(spent)} of ${Fmt.money(it.planned)}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add expense',
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: () => openTxnForm(context,
                                prefill: Txn(
                                    type: TxType.expense,
                                    amount: 0,
                                    categoryId: it.categoryId,
                                    date: DateTime.now(),
                                    note: it.name)),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              final items = [...p.items];
                              if (v == 'del') {
                                items.removeAt(i);
                              } else {
                                final amt = await _askAmount(context, it.planned);
                                if (amt == null) return;
                                items[i] = SeasonItem(it.categoryId, it.name, amt);
                              }
                              await save(SeasonPlan(
                                  id: p.id,
                                  name: p.name,
                                  start: p.start,
                                  end: p.end,
                                  items: items));
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Change planned amount')),
                              PopupMenuItem(value: 'del', child: Text('Remove')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressLine(
                          value: it.planned == 0 ? 0 : spent / it.planned,
                          color: Color(cat?.color ?? 0xFFF5B000)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<double?> _askAmount(BuildContext context, double current) async {
    final c = TextEditingController(
        text: current == 0 ? '' : current.toStringAsFixed(0));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planned amount'),
        content: Form(key: key, child: MoneyField(controller: c, autofocus: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(tr('Save'))),
        ],
      ),
    );
    return ok == true ? double.tryParse(c.text) : null;
  }

  Future<void> _addItem(BuildContext context, SeasonPlan p) async {
    final s = context.read<AppState>();
    final name = TextEditingController();
    final amt = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New item'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name (becomes a category)'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 10),
              MoneyField(controller: amt, label: 'Planned'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: Text(tr('Add'))),
        ],
      ),
    );
    if (ok != true) return;
    final cid = await s.ensureCategory(name.text.trim(), 'other', 0xFFF5B000);
    await s.saveSeason(SeasonPlan(
      id: p.id,
      name: p.name,
      start: p.start,
      end: p.end,
      items: [...p.items, SeasonItem(cid, name.text.trim(), double.parse(amt.text))],
    ));
  }
}
