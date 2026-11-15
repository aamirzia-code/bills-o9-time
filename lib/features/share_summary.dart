import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../skins.dart';
import '../utils.dart';
import '../widgets.dart';

/// A branded image of the month's numbers, to send on WhatsApp etc.
class ShareSummaryScreen extends StatefulWidget {
  final DateTime month;
  const ShareSummaryScreen({super.key, required this.month});

  @override
  State<ShareSummaryScreen> createState() => _ShareSummaryScreenState();
}

class _ShareSummaryScreenState extends State<ShareSummaryScreen> {
  final _key = GlobalKey();
  bool _busy = false;
  bool _showAmounts = true;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final name =
          'bills-o9-${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}.png';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
        fileNameOverrides: [name],
        text: 'My ${Fmt.month(widget.month)} summary · Bills O9 Time',
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not create image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sk = context.skin;
    final m = widget.month;
    final spent = s.expenseInMonth(m);
    final income = s.incomeInMonth(m);
    final bills = s.billPayments.where((t) => s.inPeriod(t.date, m)).toList();
    final billsTotal = bills.fold<double>(0, (x, t) => x + t.amount);
    final byCat = s.expenseByCategory(m).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = byCat.take(4).toList();
    final wasHidden = Fmt.hidden;
    Fmt.hidden = !_showAmounts;

    String pct(double v) => spent == 0 ? '0%' : '${(v / spent * 100).round()}%';

    final card = RepaintBoundary(
      key: _key,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(sk.radius == 0 ? 0 : 24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(sk.accent, Colors.black, 0.15)!,
              Color.lerp(sk.accent, Colors.black, 0.6)!,
            ],
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Bills O9 Time',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(Fmt.month(m),
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Spent', style: TextStyle(color: Colors.white70)),
              Text(Fmt.money(spent),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _pill('Income', Fmt.money(income, compact: true)),
                  const SizedBox(width: 8),
                  _pill('Saved', Fmt.money(income - spent, compact: true)),
                  const SizedBox(width: 8),
                  _pill('Bills paid', '${bills.length} · ${Fmt.money(billsTotal, compact: true)}'),
                ],
              ),
              if (top.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Where it went',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final e in top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(s.category(e.key)?.name ?? 'Other')),
                            Text(pct(e.value),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: spent == 0 ? 0 : e.value / spent,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                                Color(s.category(e.key)?.color ?? 0xFFFFFFFF)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    Fmt.hidden = wasHidden;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Share summary'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: FittedBox(child: card)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Show amounts'),
            subtitle: const Text('Turn off to share percentages only'),
            value: _showAmounts,
            onChanged: (v) => setState(() => _showAmounts = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share image'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
}
