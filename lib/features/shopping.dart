import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

/// Grocery / shopping lists. Tick items in the shop, then turn the
/// ticked items into one expense.
class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  static Future<void> newList(BuildContext context, {String? name}) async {
    final s = context.read<AppState>();
    final c = TextEditingController(text: name ?? '');
    final n = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New list'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Monthly ration'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in const ['Monthly ration', 'Weekly sabzi', 'Pharmacy', 'Eid shopping', 'School things'])
                  ActionChip(label: Text(t), onPressed: () => Navigator.pop(ctx, t)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (n == null || n.isEmpty) return;
    final id = await s.putRow('lists', ShopList(name: n, created: DateTime.now()).toMap());
    if (n == 'Monthly ration') {
      for (final item in const ['Atta', 'Rice', 'Cooking oil', 'Sugar', 'Daal', 'Tea', 'Milk', 'Eggs']) {
        await s.putRow('list_items', ListItem(listId: id, name: item, created: DateTime.now()).toMap());
      }
    }
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ListDetail(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping lists')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lists-fab',
        onPressed: () => newList(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New list'),
      ),
      body: s.lists.isEmpty
          ? const EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No lists yet',
              subtitle: 'Make a ration or sabzi list, tick items in the shop, then save the total as an expense in one tap.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                for (final l in s.lists)
                  Builder(builder: (context) {
                    final items = s.listItems.where((i) => i.listId == l.id).toList();
                    final done = items.where((i) => i.done).length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => ListDetail(id: l.id!))),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primary.withOpacity(0.12),
                              child: Icon(Icons.shopping_basket_rounded, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                                  const SizedBox(height: 6),
                                  ProgressLine(
                                      value: items.isEmpty ? 0 : done / items.length, color: cs.primary, height: 5),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('$done/${items.length}',
                                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class ListDetail extends StatefulWidget {
  final int id;
  const ListDetail({super.key, required this.id});

  @override
  State<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<ListDetail> {
  final _add = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// "2 kg sugar 180" → qty 2, name "kg sugar"… keep it simple:
  /// leading number = qty, trailing number = price per unit.
  Future<void> _addItem(AppState s) async {
    var t = _add.text.trim();
    if (t.isEmpty) return;
    double qty = 1, price = 0;
    final lead = RegExp(r'^(\d+(?:\.\d+)?)\s*x?\s+').firstMatch(t);
    if (lead != null) {
      qty = double.parse(lead.group(1)!);
      t = t.substring(lead.end);
    }
    final tail = RegExp(r'\s+@?(\d+(?:\.\d+)?)$').firstMatch(t);
    if (tail != null) {
      price = double.parse(tail.group(1)!);
      t = t.substring(0, tail.start);
    }
    if (t.isEmpty) return;
    final name = t[0].toUpperCase() + t.substring(1);
    await s.putRow('list_items',
        ListItem(listId: widget.id, name: name, qty: qty, price: price, created: DateTime.now()).toMap());
    _add.clear();
    _focus.requestFocus();
  }

  Future<void> _editPrice(AppState s, ListItem i) async {
    final q = TextEditingController(text: i.qty == i.qty.roundToDouble() ? i.qty.toStringAsFixed(0) : '${i.qty}');
    final p = TextEditingController(text: i.price == 0 ? '' : i.price.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i.name),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: q,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: p,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Price each', prefixText: '${Fmt.symbol} '),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await s.putRow(
          'list_items',
          i.copyWith(qty: double.tryParse(q.text) ?? i.qty, price: double.tryParse(p.text) ?? 0).toMap());
    }
  }

  Future<void> _checkout(AppState s, ShopList l, List<ListItem> done) async {
    final total = done.fold<double>(0, (a, i) => a + i.total);
    final cat = s.recalledCategory(l.name) ??
        s.categories.where((c) => c.name.toLowerCase().contains('grocer')).map((c) => c.id).firstOrNull;
    final added = await openTxnForm(context,
        prefill: Txn(
          type: TxType.expense,
          amount: total,
          categoryId: cat,
          date: DateTime.now(),
          note: l.name,
        ));
    if (!added || !mounted) return;
    final clear = await confirm(context, 'Clear ticked items?',
        'Bought items will be removed so the list is ready for next time. Unticked items stay.',
        ok: 'Clear');
    if (clear) {
      for (final i in done) {
        await s.removeRow('list_items', i.id!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final l = s.lists.where((x) => x.id == widget.id).firstOrNull;
    if (l == null) return const Scaffold(body: SizedBox.shrink());
    final items = s.listItems.where((i) => i.listId == l.id).toList();
    final open = items.where((i) => !i.done).toList();
    final done = items.where((i) => i.done).toList();
    final doneTotal = done.fold<double>(0, (a, i) => a + i.total);
    final estimate = items.fold<double>(0, (a, i) => a + i.total);

    Widget tile(ListItem i) => Dismissible(
          key: ValueKey('li-${i.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            child: Icon(Icons.delete_rounded, color: cs.error),
          ),
          onDismissed: (_) => s.removeRow('list_items', i.id!),
          child: CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: i.done,
            onChanged: (v) => s.putRow('list_items', i.copyWith(done: v ?? false).toMap()),
            title: Text(
              i.name,
              style: TextStyle(
                decoration: i.done ? TextDecoration.lineThrough : null,
                color: i.done ? cs.onSurfaceVariant : null,
              ),
            ),
            subtitle: i.qty != 1 || i.price > 0
                ? Text([
                    if (i.qty != 1) '× ${i.qty == i.qty.roundToDouble() ? i.qty.toStringAsFixed(0) : i.qty}',
                    if (i.price > 0) Fmt.money(i.total),
                  ].join('  ·  '))
                : null,
            secondary: IconButton(
              tooltip: 'Qty & price',
              icon: Icon(i.price > 0 ? Icons.sell_rounded : Icons.sell_outlined, size: 20),
              onPressed: () => _editPrice(s, i),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.name),
        actions: [
          IconButton(
            tooltip: 'Share list',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(
                '🛒 ${l.name}\n${open.map((i) => '☐ ${i.qty != 1 ? '${i.qty.toStringAsFixed(i.qty == i.qty.roundToDouble() ? 0 : 1)} × ' : ''}${i.name}').join('\n')}'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'untick') {
                for (final i in done) {
                  await s.putRow('list_items', i.copyWith(done: false).toMap());
                }
              } else if (v == 'delete') {
                if (await confirm(context, 'Delete "${l.name}"?', 'The list and its items will be removed.')) {
                  await s.removeWhere('list_items', 'list_id = ?', [l.id]);
                  await s.removeRow('lists', l.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'untick', child: Text('Untick all')),
              PopupMenuItem(value: 'delete', child: Text('Delete list')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: done.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => _checkout(s, l, done),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text(doneTotal > 0
                      ? 'Save ${done.length} items as expense · ${Fmt.money(doneTotal)}'
                      : 'Save ${done.length} items as expense'),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _add,
              focusNode: _focus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addItem(s),
              decoration: InputDecoration(
                hintText: 'Add item  (e.g. "2 milk 220")',
                prefixIcon: const Icon(Icons.add_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.keyboard_return_rounded), onPressed: () => _addItem(s)),
              ),
            ),
          ),
          if (estimate > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Text('Estimated total ${Fmt.money(estimate)}',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            ),
          const SizedBox(height: 6),
          for (final i in open) tile(i),
          if (done.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 2),
              child: Text('In the basket (${done.length})',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            ),
            for (final i in done) tile(i),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Type an item and press enter. Add a number at the end for its price.',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
