import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

class MeterKind {
  final String id, label, unit;
  final IconData icon;
  final Color color;
  final double limit; // default alert limit per cycle
  const MeterKind(this.id, this.label, this.unit, this.icon, this.color, this.limit);
}

const kMeters = [
  MeterKind('electricity', 'Electricity', 'units', Icons.bolt_rounded, Color(0xFFF59E0B), 200),
  MeterKind('gas', 'Gas', 'm³', Icons.local_fire_department_rounded, Color(0xFFEF4444), 0),
  MeterKind('water', 'Water', 'gal', Icons.water_drop_rounded, Color(0xFF0EA5E9), 0),
];

/// Usage in the current billing cycle for one meter.
class MeterCycle {
  final MeterKind kind;
  final DateTime start;
  final DateTime end;
  final double used;
  final double projected;
  final double limit;
  final double rate;
  final MeterReading? latest;
  const MeterCycle(this.kind, this.start, this.end, this.used, this.projected,
      this.limit, this.rate, this.latest);
  bool get overLimitRisk => limit > 0 && projected > limit;
  double get estimate => rate * projected;
}

Map<String, dynamic> meterPrefs(AppState s, String id) {
  final all = s.pref<Map>('meters', const {});
  final m = all[id];
  return m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
}

MeterCycle? meterCycle(AppState s, MeterKind k, {DateTime? now}) {
  final rs = s.readings.where((r) => r.meter == k.id).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (rs.isEmpty) return null;
  final p = meterPrefs(s, k.id);
  final day = ((p['readDay'] as num?) ?? 1).toInt().clamp(1, 28);
  final n = now ?? DateTime.now();
  var start = DateTime(n.year, n.month, day);
  if (start.isAfter(n)) start = DateTime(n.year, n.month - 1, day);
  final end = DateTime(start.year, start.month + 1, day);
  // Baseline: last reading on/before the cycle start, else the first one in it.
  MeterReading base = rs.first;
  for (final r in rs) {
    if (!r.date.isAfter(start)) base = r;
  }
  final latest = rs.last;
  final used = (latest.reading - base.reading).clamp(0, double.infinity).toDouble();
  final from = base.date.isAfter(start) ? base.date : start;
  final elapsed = latest.date.difference(from).inHours / 24;
  final total = end.difference(from).inHours / 24;
  final projected = elapsed < 1 ? used : used / elapsed * total;
  return MeterCycle(
    k,
    start,
    end,
    used,
    projected,
    ((p['limit'] as num?) ?? k.limit).toDouble(),
    ((p['rate'] as num?) ?? 0).toDouble(),
    latest,
  );
}

class MetersScreen extends StatelessWidget {
  const MetersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Meter readings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Note your meter every few days. You\'ll see units used this cycle, a month-end projection and an alert before you cross your limit (e.g. the 200-unit protected slab).',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final k in kMeters) _MeterCard(k),
        ],
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  final MeterKind k;
  const _MeterCard(this.k);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final c = meterCycle(s, k);
    final history = s.readings.where((r) => r.meter == k.id).take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    backgroundColor: k.color.withOpacity(0.15),
                    child: Icon(k.icon, color: k.color)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(k.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _settings(context, s),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _addReading(context, s),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Reading'),
                ),
              ],
            ),
            if (c == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('No readings yet. Add today\'s meter number to start.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(c.used.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${k.unit} used since ${Fmt.shortDate(c.start)}',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
              if (c.limit > 0) ...[
                const SizedBox(height: 8),
                ProgressLine(value: c.used / c.limit, color: c.overLimitRisk ? const Color(0xFFEF4444) : k.color),
                const SizedBox(height: 6),
              ],
              Text(
                [
                  'Projected ${c.projected.toStringAsFixed(0)} ${k.unit} by ${Fmt.shortDate(c.end)}',
                  if (c.limit > 0) 'limit ${c.limit.toStringAsFixed(0)}',
                  if (c.rate > 0) 'est. bill ${Fmt.money(c.estimate)}',
                ].join(' · '),
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
              if (c.overLimitRisk)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'At this pace you\'ll cross ${c.limit.toStringAsFixed(0)} ${k.unit}. Allow about ${((c.limit - c.used) / (c.end.difference(DateTime.now()).inHours / 24).clamp(1, 31)).clamp(0, double.infinity).toStringAsFixed(1)} ${k.unit}/day for the rest of the cycle.',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              for (final r in history)
                InkWell(
                  onLongPress: () async {
                    if (await confirm(context, 'Delete reading?', '${r.reading.toStringAsFixed(0)} on ${Fmt.date(r.date)}')) {
                      await s.removeRow('meter_readings', r.id!);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(Fmt.date(r.date), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        Text(r.reading.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addReading(BuildContext context, AppState s) async {
    final c = TextEditingController();
    var date = DateTime.now();
    final last = s.readings.where((r) => r.meter == k.id).firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('${k.label} reading'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Meter shows',
                  helperText: last == null ? null : 'Last: ${last.reading.toStringAsFixed(0)} on ${Fmt.shortDate(last.date)}',
                ),
              ),
              const SizedBox(height: 12),
              DateField(label: 'Date', value: date, onChanged: (d) => set(() => date = d)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final v = double.tryParse(c.text);
    if (ok == true && v != null) {
      await s.putRow('meter_readings', MeterReading(meter: k.id, date: date, reading: v).toMap());
    }
  }

  Future<void> _settings(BuildContext context, AppState s) async {
    final p = meterPrefs(s, k.id);
    final limit = TextEditingController(text: ((p['limit'] as num?) ?? k.limit).toStringAsFixed(0));
    final rate = TextEditingController(text: (p['rate'] as num?)?.toString() ?? '');
    var day = ((p['readDay'] as num?) ?? 1).toInt();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('${k.label} settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Alert limit per cycle (0 = off)', suffixText: k.unit),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Average rate per ${k.unit} (for estimate)', prefixText: '${Fmt.symbol} '),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: day.clamp(1, 28),
                decoration: const InputDecoration(labelText: 'Meter is read on day'),
                items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text(ordinal(d)))],
                onChanged: (v) => set(() => day = v ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final all = Map<String, dynamic>.from(s.pref<Map>('meters', const {}));
    all[k.id] = {
      'limit': double.tryParse(limit.text) ?? k.limit,
      'rate': double.tryParse(rate.text) ?? 0,
      'readDay': day,
    };
    await s.setPref('meters', all);
  }
}
