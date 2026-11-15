import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../utils.dart';
import '../widgets.dart';

/// Extra currencies with a manual rate: 1 [code] = [rate] in home currency.
class FxRate {
  final String code;
  final double rate;
  const FxRate(this.code, this.rate);
}

List<FxRate> fxRates(AppState s) {
  final raw = s.prefs['fx'];
  if (raw is! List) return [];
  return [
    for (final e in raw)
      if (e is Map && e['code'] is String && e['rate'] is num)
        FxRate(e['code'] as String, (e['rate'] as num).toDouble()),
  ];
}

Future<void> _saveFx(AppState s, List<FxRate> list) => s.setPref('fx', [
      for (final f in list) {'code': f.code, 'rate': f.rate}
    ]);

/// "≈ AED 1,234" for the first extra currency marked to show on Home.
String? altMoney(AppState s, double home) {
  final show = s.pref<String>('fxShow', '');
  if (show.isEmpty) return null;
  for (final f in fxRates(s)) {
    if (f.code == show && f.rate > 0) {
      final v = home / f.rate;
      if (Fmt.hidden) return '≈ ${f.code} ••••';
      return '≈ ${f.code} ${Fmt.money(v).replaceFirst('${Fmt.symbol} ', '')}';
    }
  }
  return null;
}

class CurrenciesScreen extends StatelessWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final list = fxRates(s);
    final show = s.pref<String>('fxShow', '');
    return Scaffold(
      appBar: AppBar(title: Text(tr('Currencies'))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fx-fab',
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          AppCard(
            child: Text(
              'Home currency: ${s.currency}. Add currencies you also use (e.g. AED salary, PKR bills at home). '
              'Enter expenses in any of them and they\'re converted with your rate. Rates are set by you, so update them now and then.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.currency_exchange_rounded,
              title: 'No extra currencies',
              subtitle: 'Tap + to add AED, SAR, USD or any other currency.',
            ),
          for (final f in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(f.code.length > 3 ? f.code.substring(0, 3) : f.code,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  title: Text('1 ${f.code} = ${Fmt.money(f.rate)}'),
                  subtitle: Text(show == f.code
                      ? 'Shown next to totals on Home'
                      : 'Tap to edit'),
                  trailing: IconButton(
                    tooltip: 'Show on Home',
                    icon: Icon(
                        show == f.code
                            ? Icons.visibility_rounded
                            : Icons.visibility_outlined,
                        color: show == f.code ? cs.primary : null),
                    onPressed: () =>
                        s.setPref('fxShow', show == f.code ? '' : f.code),
                  ),
                  onTap: () => _edit(context, f),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, FxRate? f) async {
    final s = context.read<AppState>();
    final code = TextEditingController(text: f?.code ?? '');
    final rate = TextEditingController(
        text: f == null ? '' : f.rate.toString());
    final key = GlobalKey<FormState>();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f == null ? 'Add currency' : 'Edit ${f.code}'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Code', hintText: 'AED, SAR, USD…'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a code' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: rate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '1 unit = ? ${s.currency}'),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter a rate'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          if (f != null)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: Text(tr('Delete'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, 'save');
              },
              child: Text(tr('Save'))),
        ],
      ),
    );
    if (r == null) return;
    final list = fxRates(s).where((x) => x.code != f?.code).toList();
    if (r == 'save') {
      final c = code.text.trim().toUpperCase();
      list.removeWhere((x) => x.code == c);
      list.add(FxRate(c, double.parse(rate.text)));
    }
    await _saveFx(s, list);
  }
}
