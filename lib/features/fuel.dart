import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

class FuelStats {
  final double kmPerLitre;
  final double costPerKm;
  final double monthCost;
  final double monthLitres;
  const FuelStats(this.kmPerLitre, this.costPerKm, this.monthCost, this.monthLitres);
}

/// Mileage from full-tank fill-ups: distance between the first and last
/// odometer readings divided by fuel bought after the first one.
FuelStats fuelStats(List<FuelLog> logs, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final withOdo = logs.where((l) => l.odometer > 0).toList()
    ..sort((a, b) => a.odometer.compareTo(b.odometer));
  double kpl = 0, cpk = 0;
  if (withOdo.length >= 2) {
    final dist = withOdo.last.odometer - withOdo.first.odometer;
    final fuel = withOdo.skip(1).fold<double>(0, (a, l) => a + l.litres);
    final cost = withOdo.skip(1).fold<double>(0, (a, l) => a + l.cost);
    if (dist > 0 && fuel > 0) {
      kpl = dist / fuel;
      cpk = cost / dist;
    }
  }
  final month = logs.where((l) => l.date.year == n.year && l.date.month == n.month);
  return FuelStats(
    kpl,
    cpk,
    month.fold(0, (a, l) => a + l.cost),
    month.fold(0, (a, l) => a + l.litres),
  );
}

class FuelScreen extends StatefulWidget {
  const FuelScreen({super.key});
  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  String? _vehicle;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final vehicles = {for (final l in s.fuelLogs) l.vehicle}.toList();
    final v = _vehicle ?? (vehicles.isEmpty ? null : vehicles.first);
    final logs = s.fuelLogs.where((l) => l.vehicle == v).toList();
    final st = fuelStats(logs);

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel log')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fuel-fab',
        onPressed: () => _add(context, s, v),
        icon: const Icon(Icons.local_gas_station_rounded),
        label: const Text('Fill-up'),
      ),
      body: s.fuelLogs.isEmpty
          ? const EmptyState(
              icon: Icons.local_gas_station_rounded,
              title: 'Track petrol & mileage',
              subtitle:
                  'Log each fill-up with the odometer reading. You\'ll see km per litre, cost per km and monthly fuel spend. Each fill-up is also saved as an expense.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                if (vehicles.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final x in vehicles)
                          ChoiceChip(
                            label: Text(x),
                            selected: x == v,
                            onSelected: (_) => setState(() => _vehicle = x),
                          ),
                      ],
                    ),
                  ),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          stat('Mileage', st.kmPerLitre > 0 ? '${st.kmPerLitre.toStringAsFixed(1)} km/l' : '—'),
                          stat('Cost per km', st.costPerKm > 0 ? Fmt.money(st.costPerKm) : '—'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          stat('This month', Fmt.money(st.monthCost)),
                          stat('Litres', st.monthLitres.toStringAsFixed(1)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (st.kmPerLitre == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Add the odometer reading on two or more fill-ups to see mileage.',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ),
                const SectionTitle('Fill-ups'),
                for (final l in logs)
                  Dismissible(
                    key: ValueKey('fuel-${l.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 18),
                      child: Icon(Icons.delete_rounded, color: cs.error),
                    ),
                    onDismissed: (_) => s.removeRow('fuel_logs', l.id!),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.local_gas_station_rounded),
                      title: Text('${l.litres.toStringAsFixed(1)} L @ ${Fmt.money(l.price)}'),
                      subtitle: Text([
                        Fmt.date(l.date),
                        if (l.odometer > 0) '${l.odometer.toStringAsFixed(0)} km',
                      ].join(' · ')),
                      trailing: Text(Fmt.money(l.cost), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _add(BuildContext context, AppState s, String? vehicle) async {
    final last = s.fuelLogs.firstOrNull;
    final veh = TextEditingController(text: vehicle ?? 'My car');
    final amount = TextEditingController();
    final price = TextEditingController(text: last == null ? '' : last.price.toStringAsFixed(last.price == last.price.roundToDouble() ? 0 : 2));
    final odo = TextEditingController();
    var date = DateTime.now();
    var addExpense = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final a = double.tryParse(amount.text) ?? 0;
          final p = double.tryParse(price.text) ?? 0;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Fill-up', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: veh,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        autofocus: true,
                        onChanged: (_) => set(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Paid', prefixText: '${Fmt.symbol} '),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: price,
                        onChanged: (_) => set(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Price / litre', prefixText: '${Fmt.symbol} '),
                      ),
                    ),
                  ],
                ),
                if (a > 0 && p > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('= ${(a / p).toStringAsFixed(2)} litres',
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: odo,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Odometer (km)', hintText: 'optional'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: DateField(label: 'Date', value: date, onChanged: (d) => set(() => date = d))),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also add as expense'),
                  value: addExpense,
                  onChanged: (v) => set(() => addExpense = v),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: a > 0 && p > 0 ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    final a = double.parse(amount.text);
    final p = double.parse(price.text);
    int? txnId;
    if (addExpense) {
      final cat = s.categories.where((c) => c.icon == 'fuel').map((c) => c.id).firstOrNull ??
          await s.ensureCategory('Fuel', 'fuel', 0xFFF97316);
      txnId = await s.saveTxnReturningId(Txn(
        type: TxType.expense,
        amount: a,
        categoryId: cat,
        accountId: s.accounts.isEmpty ? null : s.accounts.first.id,
        date: date,
        note: 'Petrol · ${veh.text.trim()}',
      ));
    }
    await s.putRow(
        'fuel_logs',
        FuelLog(
          vehicle: veh.text.trim().isEmpty ? 'My car' : veh.text.trim(),
          date: date,
          litres: double.parse((a / p).toStringAsFixed(2)),
          price: p,
          odometer: double.tryParse(odo.text) ?? 0,
          txnId: txnId,
        ).toMap());
    if (mounted) setState(() => _vehicle = veh.text.trim());
  }
}
