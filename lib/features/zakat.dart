import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../models.dart';
import '../screens/transactions_screen.dart';
import '../utils.dart';
import '../widgets.dart';
import 'logic.dart';

/// Zakat calculator. Inputs are saved (as a preference) so next year only
/// prices need updating. Bank/cash balances and savings goals are pulled in.
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  late Map<String, dynamic> z;
  final _c = <String, TextEditingController>{};

  static const _fields = [
    'goldPrice', // per tola
    'silverPrice', // per tola
    'goldTola',
    'silverTola',
    'otherAssets',
    'receivables',
    'liabilities',
  ];

  @override
  void initState() {
    super.initState();
    final raw = context.read<AppState>().prefs['zakat'];
    z = raw is Map ? Map<String, dynamic>.from(raw) : {};
    for (final f in _fields) {
      final v = (z[f] as num?)?.toDouble();
      _c[f] = TextEditingController(
          text: v == null || v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String f) => double.tryParse(_c[f]!.text.replaceAll(',', '')) ?? 0;

  Future<void> _save(AppState s) async {
    for (final f in _fields) {
      z[f] = _v(f);
    }
    await s.setPref('zakat', z);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final useAccounts = z['useAccounts'] as bool? ?? true;
    final useGoals = z['useGoals'] as bool? ?? true;
    final silver = z['silverNisab'] as bool? ?? true;
    final cash = useAccounts
        ? s.accounts.fold<double>(0, (x, a) {
            final b = s.accountBalance(a);
            return x + (b > 0 ? b : 0);
          })
        : 0.0;
    final savings = useGoals
        ? s.goals
            .where((g) => g.kind == GoalKind.saving)
            .fold<double>(0, (x, g) => x + s.goalProgress(g))
        : 0.0;
    final r = computeZakat(
      cashAndBank: cash,
      savings: savings,
      goldGrams: _v('goldTola') * gramsPerTola,
      silverGrams: _v('silverTola') * gramsPerTola,
      goldPricePerGram: _v('goldPrice') / gramsPerTola,
      silverPricePerGram: _v('silverPrice') / gramsPerTola,
      otherAssets: _v('otherAssets'),
      receivables: _v('receivables'),
      liabilities: _v('liabilities'),
      silverNisab: silver,
    );
    final zakatDate = DateTime.tryParse(s.pref<String>('zakatDate', ''));
    final missingPrice = silver ? _v('silverPrice') == 0 : _v('goldPrice') == 0;

    Widget field(String f, String label, {String? hint, String? suffix}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _c[f],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            onEditingComplete: () => _save(s),
            decoration: InputDecoration(
                labelText: label, hintText: hint, suffixText: suffix),
          ),
        );

    return PopScope(
      onPopInvokedWithResult: (_, __) => _save(s),
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Zakat calculator'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            AppCard(
              color: (r.due ? const Color(0xFF22C55E) : cs.surfaceContainerHigh)
                  .withOpacity(r.due ? 0.14 : 1),
              child: Column(
                children: [
                  Text(r.due ? 'Zakat due (2.5%)' : 'Below nisab — no Zakat due',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(Fmt.money(r.zakat),
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Net zakatable wealth ${Fmt.money(r.net)} · nisab ${missingPrice ? 'enter ${silver ? 'silver' : 'gold'} price' : Fmt.money(r.nisab)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                  ),
                  if (r.due) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        await _save(s);
                        final cat = await s.ensureCategory(
                            'Zakat & Sadqa', 'gift', 0xFF16A34A);
                        if (!context.mounted) return;
                        openTxnForm(context,
                            prefill: Txn(
                                type: TxType.expense,
                                amount: double.parse(r.zakat.toStringAsFixed(0)),
                                categoryId: cat,
                                date: DateTime.now(),
                                note: 'Zakat ${DateTime.now().year}'));
                      },
                      icon: const Icon(Icons.volunteer_activism_rounded),
                      label: const Text('Record Zakat payment'),
                    ),
                  ],
                ],
              ),
            ),
            const SectionTitle('Nisab'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Silver (52.5 tola)')),
                ButtonSegment(value: false, label: Text('Gold (7.5 tola)')),
              ],
              selected: {silver},
              onSelectionChanged: (v) {
                setState(() => z['silverNisab'] = v.first);
                _save(s);
              },
            ),
            const SizedBox(height: 12),
            field('silverPrice', 'Silver price per tola', suffix: Fmt.symbol),
            field('goldPrice', 'Gold price per tola', suffix: Fmt.symbol),
            Text('Use today\'s local market rate. Most scholars in Pakistan use the silver nisab; ask your scholar if unsure.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SectionTitle('Your wealth'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Cash & bank accounts'),
                    subtitle: Text(Fmt.money(cash)),
                    value: useAccounts,
                    onChanged: (v) {
                      setState(() => z['useAccounts'] = v);
                      _save(s);
                    },
                  ),
                  Divider(height: 1, color: cs.outlineVariant),
                  SwitchListTile(
                    title: const Text('Savings goals'),
                    subtitle: Text(Fmt.money(savings)),
                    value: useGoals,
                    onChanged: (v) {
                      setState(() => z['useGoals'] = v);
                      _save(s);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            field('goldTola', 'Gold owned', suffix: 'tola'),
            field('silverTola', 'Silver owned', suffix: 'tola'),
            field('otherAssets', 'Other assets (stock for trade, shares, cash elsewhere)',
                suffix: Fmt.symbol),
            field('receivables', 'Money owed to you (likely to be repaid)',
                suffix: Fmt.symbol),
            field('liabilities', 'Debts due now (deduct)', suffix: Fmt.symbol),
            const SectionTitle('Yearly reminder'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Zakat date'),
                subtitle: Text(zakatDate == null
                    ? 'Get an alert 2 weeks before each year'
                    : '${Fmt.date(zakatDate)} · alert 2 weeks before each year'),
                trailing: zakatDate == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => s.setPref('zakatDate', null)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: zakatDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) await s.setPref('zakatDate', d.toIso8601String());
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a guide based on common rules (2.5% of net zakatable wealth held for a lunar year above nisab). Personal situations differ — confirm with a scholar.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
