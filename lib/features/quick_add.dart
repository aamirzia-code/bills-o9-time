import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../screens/bill_form.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';
import 'fuel.dart';
import 'logic.dart';
import 'people.dart';
import 'shopping.dart';

const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);

/// A repeat-able expense the user makes often (same note, same amount).
class Favourite {
  final String note;
  final double amount;
  final int? categoryId;
  final int? accountId;
  final TxType type;
  final int count;
  const Favourite(this.note, this.amount, this.categoryId, this.accountId, this.type, this.count);
}

List<Favourite> frequentEntries(List<Txn> txns, {DateTime? now, int max = 6}) {
  final n = now ?? DateTime.now();
  final from = n.subtract(const Duration(days: 120));
  final groups = <String, List<Txn>>{};
  for (final t in txns) {
    if (t.date.isBefore(from) || t.billId != null || t.note.trim().isEmpty) continue;
    final key = '${t.type.index}|${t.note.trim().toLowerCase()}|${t.amount.round()}';
    groups.putIfAbsent(key, () => []).add(t);
  }
  final out = [
    for (final g in groups.values)
      if (g.length >= 2)
        Favourite(g.first.note.trim(), g.first.amount, g.first.categoryId, g.first.accountId,
            g.first.type, g.length),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return out.take(max).toList();
}

/// "+" sheet: type a line like "500 petrol cash", tap a favourite, or pick
/// what to add.
Future<void> showQuickAdd(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuickAddSheet(),
    );

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();
  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _text = TextEditingController();
  QuickEntry? _q;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse(AppState s) {
    final t = _text.text.trim();
    setState(() => _q = t.isEmpty
        ? null
        : parseQuickEntry(t,
            categories: s.categories, accounts: s.accounts, recall: s.recalledCategory));
  }

  Txn _txn(AppState s, QuickEntry q) => Txn(
        type: q.type,
        amount: q.amount!,
        categoryId: q.categoryId,
        accountId: q.accountId ?? (s.accounts.isEmpty ? null : s.accounts.first.id),
        date: q.date,
        note: q.note,
      );

  Future<void> _saved(NavigatorState nav, ScaffoldMessengerState m, AppState s, Txn t, int id) async {
    nav.pop();
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
            'Added ${t.note.isEmpty ? (s.category(t.categoryId)?.name ?? '') : t.note} · ${Fmt.money(t.amount)}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final x in s.txns) {
              if (x.id == id) {
                await s.deleteTxn(x);
                break;
              }
            }
          },
        ),
      ));
  }

  Future<void> _submit(AppState s) async {
    final q = _q;
    if (q == null || q.amount == null) {
      toast(context, 'Start with an amount, e.g. "500 petrol"');
      return;
    }
    final nav = Navigator.of(context);
    final m = ScaffoldMessenger.of(context);
    if (q.categoryId == null) {
      // Not sure where it goes: open the full form, pre-filled.
      nav.pop();
      openTxnForm(nav.context, prefill: _txn(s, q));
      return;
    }
    final t = _txn(s, q);
    final id = await s.saveTxnReturningId(t);
    await _saved(nav, m, s, t, id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final favs = frequentEntries(s.txns);
    final q = _q;
    final cat = s.category(q?.categoryId);

    Widget action(IconData icon, Color color, String label, VoidCallback go) => InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final nav = Navigator.of(context);
            nav.pop();
            go();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

    final rootCtx = Navigator.of(context).context;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _parse(s),
                onSubmitted: (_) => _submit(s),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Type: 500 petrol cash',
                  prefixIcon: const Icon(Icons.bolt_rounded),
                  suffixIcon: IconButton.filled(
                    onPressed: q?.amount == null ? null : () => _submit(s),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: q?.amount == null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Text(
                          'Amount + what + (optional) account or "yesterday". Works with 1.5k, 2 lac, "salary 150000"… Tap the mic on your keyboard to speak it.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CategoryAvatar(cat, size: 38),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q!.note.isEmpty ? (cat?.name ?? 'Pick a category') : q.note,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      [
                                        cat?.name ?? 'No category yet — opens full form',
                                        s.account(q.accountId)?.name ??
                                            (s.accounts.isEmpty ? null : s.accounts.first.name),
                                        Fmt.shortDate(q.date),
                                      ].whereType<String>().join(' · '),
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${q.type == TxType.income ? '+' : '−'}${Fmt.money(q.amount!)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: q.type == TxType.income ? _green : _red),
                              ),
                              IconButton(
                                tooltip: 'More details',
                                icon: const Icon(Icons.tune_rounded),
                                onPressed: () {
                                  Navigator.pop(context);
                                  openTxnForm(rootCtx, prefill: _txn(s, q));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (favs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('One-tap repeat', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in favs)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                        avatar: Icon(iconFor(s.category(f.categoryId)?.icon ?? 'other'), size: 17),
                        label: Text('${f.note} · ${Fmt.money(f.amount)}'),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final m = ScaffoldMessenger.of(context);
                          final t = Txn(
                              type: f.type,
                              amount: f.amount,
                              categoryId: f.categoryId,
                              accountId: f.accountId,
                              date: DateTime.now(),
                              note: f.note);
                          final id = await s.saveTxnReturningId(t);
                          await _saved(nav, m, s, t, id);
                        },
                      )),
                  ],
                )),
              ],
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  action(Icons.north_east_rounded, _red, tr('Expense'),
                      () => openTxnForm(rootCtx, type: TxType.expense)),
                  action(Icons.south_west_rounded, _green, tr('Income'),
                      () => openTxnForm(rootCtx, type: TxType.income)),
                  action(Icons.receipt_long_rounded, kBlue, 'Bill',
                      () => Navigator.push(rootCtx, MaterialPageRoute(builder: (_) => const BillForm()))),
                  action(Icons.sms_outlined, const Color(0xFF8B5CF6), 'Bank SMS',
                      () => openTxnForm(rootCtx, pasteSms: true)),
                  action(Icons.call_split_rounded, const Color(0xFF0891B2), 'Split',
                      () => Navigator.push(rootCtx, MaterialPageRoute(builder: (_) => const SplitForm()))),
                  action(Icons.swap_horiz_rounded, const Color(0xFFDB2777), 'Lend / borrow',
                      () => Navigator.push(rootCtx, MaterialPageRoute(builder: (_) => const SplitForm(loan: true)))),
                  action(Icons.local_gas_station_rounded, const Color(0xFFF97316), 'Fuel',
                      () => Navigator.push(rootCtx, MaterialPageRoute(builder: (_) => const FuelScreen()))),
                  action(Icons.checklist_rounded, const Color(0xFF16A34A), 'List',
                      () => Navigator.push(rootCtx, MaterialPageRoute(builder: (_) => const ListsScreen()))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
