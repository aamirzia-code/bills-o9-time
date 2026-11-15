import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'daily_models.dart';

const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _brand = Color(0xFF0F766E);

/// Money without the "hide amounts" mask — for things the user shares.
String plainMoney(double v) {
  final h = Fmt.hidden;
  Fmt.hidden = false;
  final out = Fmt.money(v);
  Fmt.hidden = h;
  return out;
}

const kSplitModeLabels = {
  SplitMode.equal: 'Split equally',
  SplitMode.exact: 'Split by amounts',
  SplitMode.percent: 'Split by %',
  SplitMode.shares: 'Split by shares',
};

// ---------------------------------------------------------------- view model

/// Everything needed to draw or send a split, whether it lives in this app
/// or arrived in a link from a friend.
class SplitSheet {
  final String title;
  final double total;
  final DateTime date;
  final String group;
  final String currency;
  final String payer;
  final SplitMode mode;
  final List<SplitRow> rows;
  const SplitSheet({
    required this.title,
    required this.total,
    required this.date,
    this.group = '',
    required this.currency,
    required this.payer,
    required this.mode,
    required this.rows,
  });

  double get pending => rows.where((r) => !r.isPayer && !r.paid).fold(0, (a, r) => a + r.amount);

  factory SplitSheet.of(AppState s, SplitBill b) {
    final me = s.userName.isEmpty ? 'Me' : s.userName;
    return SplitSheet(
      title: b.title,
      total: b.total,
      date: b.date,
      group: b.group,
      currency: s.currency,
      payer: s.personName(b.payer, me: me),
      mode: b.mode,
      rows: [
        for (final p in b.parts)
          SplitRow(
            person: p.person,
            name: s.personName(p.person, me: me),
            amount: p.amount,
            value: p.value,
            paid: b.settled.contains(p.person),
            isPayer: p.person == b.payer,
          ),
      ],
    );
  }

  // Compact link payload: {v,t,s,d,g,c,b,m,r:[[name,amount,paid,isPayer,value]]}
  String encode() {
    final j = {
      'v': 2,
      't': title,
      's': total,
      'd': date.millisecondsSinceEpoch ~/ 1000,
      if (group.isNotEmpty) 'g': group,
      'c': currency,
      'b': payer,
      'm': mode.index,
      'r': [
        for (final r in rows)
          [r.name, r.amount, r.paid ? 1 : 0, r.isPayer ? 1 : 0, r.value]
      ],
    };
    return base64Url.encode(utf8.encode(jsonEncode(j))).replaceAll('=', '');
  }

  static SplitSheet? decode(String e) {
    try {
      while (e.length % 4 != 0) {
        e += '=';
      }
      final j = (jsonDecode(utf8.decode(base64Url.decode(e))) as Map).cast<String, dynamic>();
      return SplitSheet(
        title: j['t'] as String,
        total: (j['s'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch((j['d'] as num).toInt() * 1000),
        group: (j['g'] as String?) ?? '',
        currency: (j['c'] as String?) ?? '',
        payer: (j['b'] as String?) ?? '',
        mode: SplitMode.values[((j['m'] as num?) ?? 0).toInt().clamp(0, SplitMode.values.length - 1)],
        rows: [
          for (final r in (j['r'] as List).cast<List>())
            SplitRow(
              person: -2,
              name: r[0] as String,
              amount: (r[1] as num).toDouble(),
              paid: r[2] == 1,
              isPayer: r[3] == 1,
              value: r.length > 4 ? (r[4] as num).toDouble() : 0,
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  String link() {
    final b = Uri.base;
    final dir = b.path.substring(0, b.path.lastIndexOf('/') + 1);
    return '${b.origin}$dir?split=${encode()}';
  }

  String detailFor(SplitRow r) => switch (mode) {
        SplitMode.percent => '${_num(r.value)}%',
        SplitMode.shares => '${_num(r.value)} share${r.value == 1 ? '' : 's'}',
        _ => '',
      };

  String message({bool withLink = true}) {
    final b = StringBuffer()
      ..writeln('🧾 *$title* — ${plainMoney(total)}')
      ..writeln('📅 ${DateFormat('d MMM yyyy').format(date)}${group.isEmpty ? '' : ' · $group'}')
      ..writeln('💳 Paid by $payer · ${kSplitModeLabels[mode]!.toLowerCase()}')
      ..writeln();
    for (final r in rows) {
      final d = detailFor(r);
      b.writeln('• ${r.name}: *${plainMoney(r.amount)}*${d.isEmpty ? '' : ' ($d)'}'
          '${r.isPayer ? ' — paid the bill' : r.paid ? ' ✅ paid' : ''}');
    }
    if (pending > 0.5) {
      b
        ..writeln()
        ..writeln('Please send your part to $payer 🙏');
    }
    if (withLink) {
      b
        ..writeln()
        ..writeln('View: ${link()}');
    }
    return b.toString().trim();
  }
}

class SplitRow {
  final int person; // -1 me, -2 unknown (from a link)
  final String name;
  final double amount;
  final double value;
  final bool paid;
  final bool isPayer;
  const SplitRow({
    required this.person,
    required this.name,
    required this.amount,
    this.value = 0,
    this.paid = false,
    this.isPayer = false,
  });
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ---------------------------------------------------------------- sharing

String pdfSafe(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x20B9) {
      b.write('Rs');
    } else if (r < 256 || r == 0x20AC) {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

Future<Uint8List> splitPdf(SplitSheet sh) async {
  final doc = pw.Document(title: sh.title);
  const brand = PdfColor.fromInt(0xFF0F766E);
  const muted = PdfColor.fromInt(0xFF64748B);
  String m(double v) => pdfSafe(plainMoney(v));
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: const pw.BoxDecoration(
              color: brand, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SPLIT BILL', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9, letterSpacing: 2)),
              pw.SizedBox(height: 6),
              pw.Text(pdfSafe(sh.title),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(m(sh.total),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
            pdfSafe([
              DateFormat('d MMM yyyy').format(sh.date),
              if (sh.group.isNotEmpty) sh.group,
              'Paid by ${sh.payer}',
              kSplitModeLabels[sh.mode]!,
            ].join('  |  ')),
            style: const pw.TextStyle(color: muted, fontSize: 9.5)),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Person', 'Basis', 'Share', 'Status'],
          data: [
            for (final r in sh.rows)
              [
                pdfSafe(r.name),
                sh.detailFor(r).isEmpty ? '-' : sh.detailFor(r),
                m(r.amount),
                r.isPayer ? 'Paid the bill' : (r.paid ? 'Paid' : 'Owes ${pdfSafe(sh.payer)}'),
              ],
          ],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: brand),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: {2: pw.Alignment.centerRight},
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          pw.Text('Still to pay', style: const pw.TextStyle(fontSize: 11)),
          pw.Spacer(),
          pw.Text(m(sh.pending), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Spacer(),
        pw.Text('Made with Bills O9 Time - your data stays on your phone',
            style: const pw.TextStyle(color: muted, fontSize: 8)),
      ],
    ),
  ));
  return doc.save();
}

String _fileBase(SplitSheet sh) {
  final t = sh.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return 'split-${t.isEmpty ? 'bill' : t}';
}

Future<void> shareSplitPdf(BuildContext context, SplitSheet sh) async {
  try {
    final bytes = await splitPdf(sh);
    final name = '${_fileBase(sh)}.pdf';
    await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
        fileNameOverrides: [name], text: sh.message(withLink: false));
  } catch (e) {
    if (context.mounted) toast(context, 'Could not create PDF: $e');
  }
}

Future<void> shareSplitImage(BuildContext context, GlobalKey key, SplitSheet sh) async {
  try {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final name = '${_fileBase(sh)}.png';
    await Share.shareXFiles(
        [XFile.fromData(data!.buffer.asUint8List(), name: name, mimeType: 'image/png')],
        fileNameOverrides: [name]);
  } catch (e) {
    if (context.mounted) toast(context, 'Could not create image: $e');
  }
}

/// Share buttons: WhatsApp text, PDF, image, link.
class SplitShareBar extends StatelessWidget {
  final SplitSheet sheet;
  final GlobalKey imageKey;
  const SplitShareBar({super.key, required this.sheet, required this.imageKey});

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, String label, Color c, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                    child: Icon(i, color: c),
                  ),
                  const SizedBox(height: 5),
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        b(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366), () => Share.share(sheet.message())),
        b(Icons.picture_as_pdf_rounded, 'PDF', _red, () => shareSplitPdf(context, sheet)),
        b(Icons.image_rounded, 'Image', const Color(0xFF8B5CF6), () => shareSplitImage(context, imageKey, sheet)),
        b(Icons.link_rounded, 'Copy link', const Color(0xFF2F80ED), () {
          Clipboard.setData(ClipboardData(text: sheet.link()));
          toast(context, 'Link copied — anyone can open it to see their part');
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------- invoice card

/// The receipt-style card. Fixed light colours so the shared image looks the
/// same in every theme.
class SplitInvoice extends StatelessWidget {
  final SplitSheet sheet;
  final void Function(SplitRow r)? onRowTap;
  final String? highlight;
  const SplitInvoice({super.key, required this.sheet, this.onRowTap, this.highlight});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);
    final sh = sheet;
    final paidCount = sh.rows.where((r) => r.paid || r.isPayer).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call_split_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text('SPLIT BILL',
                        style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(DateFormat('d MMM yyyy').format(sh.date),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(sh.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(plainMoney(sh.total),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'Paid by ${sh.payer}',
                    kSplitModeLabels[sh.mode]!.toLowerCase(),
                    if (sh.group.isNotEmpty) sh.group,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              children: [
                for (final r in sh.rows)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onRowTap == null || r.isPayer ? null : () => onRowTap!(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: highlight == r.name ? const Color(0xFFFEF3C7) : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: (r.isPayer ? _brand : const Color(0xFF94A3B8)).withOpacity(0.15),
                            child: Text(r.name.isEmpty ? '?' : r.name.trim()[0].toUpperCase(),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, color: r.isPayer ? _brand : const Color(0xFF475569))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(
                                  [
                                    if (sh.detailFor(r).isNotEmpty) sh.detailFor(r),
                                    r.isPayer ? 'paid the bill' : r.paid ? 'paid back' : 'owes ${sh.payer}',
                                  ].join(' · '),
                                  style: const TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(plainMoney(r.amount),
                                  style: TextStyle(
                                    color: r.paid ? muted : ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    decoration: r.paid ? TextDecoration.lineThrough : null,
                                  )),
                              if (!r.isPayer)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (r.paid ? _green : const Color(0xFFF59E0B)).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(r.paid ? 'PAID' : 'DUE',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: r.paid ? const Color(0xFF15803D) : const Color(0xFFB45309))),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Text('$paidCount of ${sh.rows.length} settled', style: const TextStyle(color: muted, fontSize: 12.5)),
                const Spacer(),
                Text(sh.pending > 0.5 ? 'To collect ${plainMoney(sh.pending)}' : 'All settled ✓',
                    style: TextStyle(
                        color: sh.pending > 0.5 ? ink : const Color(0xFF15803D),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('Bills O9 Time',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- form

/// Split a bill Splitwise-style, or note money lent / borrowed.
class SplitForm extends StatefulWidget {
  final int? personId;
  final bool loan;
  const SplitForm({super.key, this.personId, this.loan = false});

  @override
  State<SplitForm> createState() => _SplitFormState();
}

class _SplitFormState extends State<SplitForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _group = TextEditingController();
  final _newPerson = TextEditingController();
  late bool _loan = widget.loan;
  bool _iLent = true;
  int _payer = -1;
  bool _recordMyShare = true;
  SplitMode _mode = SplitMode.equal;
  final List<int> _who = [-1]; // -1 = me
  final Map<int, TextEditingController> _vals = {};
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.personId != null) _who.add(widget.personId!);
  }

  @override
  void dispose() {
    for (final c in [_amount, _note, _group, _newPerson, ..._vals.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(int id) => _vals.putIfAbsent(
      id, () => TextEditingController(text: _mode == SplitMode.shares ? '1' : ''));

  double get _total => double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;

  Map<int, double> get _values => {
        for (final id in _who)
          id: double.tryParse(_ctl(id).text) ?? (_mode == SplitMode.shares ? 1 : 0)
      };

  List<SplitPart> get _parts => computeParts(_total, _mode, _who, _values, payer: _payer);

  String? get _problem {
    if (_total <= 0) return 'Enter the total';
    if (_who.length < 2) return 'Add at least one more person';
    if (!_who.contains(_payer)) return 'Choose who paid';
    final sum = _parts.fold<double>(0, (a, p) => a + p.amount);
    if (_mode == SplitMode.exact && (sum - _total).abs() > 0.5) {
      final left = _total - sum;
      return left > 0 ? '${plainMoney(left)} left to assign' : '${plainMoney(-left)} over the total';
    }
    if (_mode == SplitMode.percent) {
      final pct = _values.values.fold<double>(0, (a, b) => a + b);
      if ((pct - 100).abs() > 0.01) return '${_num(pct)}% of 100% assigned';
    }
    return null;
  }

  Future<void> _addPerson(AppState s) async {
    final name = _newPerson.text.trim();
    if (name.isEmpty) return;
    final existing = s.people.where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    final id = existing?.id ??
        await s.putRow('people', Person(name: name, color: kPalette[s.people.length % kPalette.length]).toMap());
    _newPerson.clear();
    setState(() {
      if (!_who.contains(id)) _who.add(id);
    });
  }

  void _setMode(SplitMode m) {
    setState(() {
      _mode = m;
      for (final c in _vals.values) {
        c.text = m == SplitMode.shares ? '1' : '';
      }
      if (m == SplitMode.percent && _who.isNotEmpty) {
        final each = 100 / _who.length;
        for (final id in _who) {
          _ctl(id).text = _num(each);
        }
      }
    });
  }

  Future<void> _save(AppState s) async {
    if (_loan) {
      if (_total <= 0 || _who.where((w) => w != -1).isEmpty) {
        toast(context, 'Enter an amount and pick a person');
        return;
      }
      final note = _note.text.trim();
      for (final id in _who.where((w) => w != -1)) {
        await s.putRow(
            'ious',
            Iou(
              personId: id,
              amount: _iLent ? _total : -_total,
              note: note.isEmpty ? (_iLent ? 'Lent' : 'Borrowed') : note,
              date: _date,
              group: _group.text.trim(),
              kind: IouKind.loan,
            ).toMap());
      }
      if (mounted) Navigator.pop(context);
      return;
    }
    final p = _problem;
    if (p != null) {
      toast(context, p);
      return;
    }
    final title = _note.text.trim().isEmpty ? 'Shared bill' : _note.text.trim();
    final bill = SplitBill(
      title: title,
      total: _total,
      date: _date,
      payer: _payer,
      mode: _mode,
      group: _group.text.trim(),
      parts: _parts,
    );
    final id = await s.saveSplit(bill);
    final mine = bill.parts.where((x) => x.person == -1).firstOrNull?.amount ?? 0;
    if (_recordMyShare && mine > 0) {
      final cid = s.recalledCategory(title) ?? await s.ensureCategory('Shared expenses', 'family', 0xFF0891B2);
      await s.saveTxnReturningId(Txn(
        type: TxType.expense,
        amount: mine,
        categoryId: cid,
        accountId: s.accounts.isEmpty ? null : s.accounts.first.id,
        date: _date,
        note: '$title (my share)',
      ));
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SplitDetail(id: id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final me = s.userName.isEmpty ? 'You' : 'You (${s.userName})';
    String name(int id) => id == -1 ? 'You' : s.personName(id);
    final parts = _loan ? const <SplitPart>[] : _parts;
    final problem = _loan ? null : _problem;

    Widget avatar(int id, {double size = 30}) {
      if (id == -1) {
        return CircleAvatar(radius: size / 2, child: Icon(Icons.person_rounded, size: size * 0.6));
      }
      final p = s.people.where((x) => x.id == id).firstOrNull;
      final c = Color(p?.color ?? 0xFF64748B);
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: c.withOpacity(0.18),
        child: Text(name(id)[0].toUpperCase(),
            style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * 0.42)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_loan ? 'Lend or borrow' : 'Split a bill')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problem != null && _total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(problem, style: const TextStyle(color: _red, fontWeight: FontWeight.w600)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => _save(s),
                  icon: Icon(_loan ? Icons.check_rounded : Icons.receipt_long_rounded),
                  label: Text(_loan ? 'Save' : 'Save & share'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Split a bill'), icon: Icon(Icons.call_split_rounded)),
              ButtonSegment(value: true, label: Text('Lend / borrow'), icon: Icon(Icons.swap_horiz_rounded)),
            ],
            selected: {_loan},
            onSelectionChanged: (v) => setState(() => _loan = v.first),
          ),
          const SizedBox(height: 16),
          MoneyField(
              controller: _amount,
              autofocus: true,
              label: _loan ? 'Amount' : 'Total bill',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: _loan ? 'Note' : 'What for?', hintText: 'Dinner at Monal, trip, rent…'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _group,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Group (optional)', hintText: 'Murree trip'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d))),
            ],
          ),
          SectionTitle(_loan ? 'With' : 'Split between'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_loan)
                FilterChip(
                  avatar: avatar(-1, size: 22),
                  label: Text(me),
                  selected: _who.contains(-1),
                  onSelected: (v) => setState(() {
                    v ? _who.insert(0, -1) : _who.remove(-1);
                    if (!v && _payer == -1 && _who.isNotEmpty) _payer = _who.first;
                  }),
                ),
              for (final p in s.people)
                FilterChip(
                  avatar: avatar(p.id!, size: 22),
                  label: Text(p.name),
                  selected: _who.contains(p.id),
                  onSelected: (v) => setState(() {
                    v ? _who.add(p.id!) : _who.remove(p.id);
                    if (!_who.contains(_payer)) _payer = _who.contains(-1) ? -1 : (_who.firstOrNull ?? -1);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPerson,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addPerson(s),
                  decoration: const InputDecoration(
                      hintText: 'Add a friend by name', prefixIcon: Icon(Icons.person_add_alt_rounded)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: () => _addPerson(s), icon: const Icon(Icons.add_rounded)),
            ],
          ),
          if (_loan) ...[
            const SectionTitle('Direction'),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('I lent')),
                ButtonSegment(value: false, label: Text('I borrowed')),
              ],
              selected: {_iLent},
              onSelectionChanged: (v) => setState(() => _iLent = v.first),
            ),
          ] else ...[
            const SectionTitle('Paid by'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _who)
                  ChoiceChip(
                    avatar: avatar(id, size: 22),
                    label: Text(name(id)),
                    selected: _payer == id,
                    onSelected: (_) => setState(() => _payer = id),
                  ),
              ],
            ),
            const SectionTitle('How to split'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<SplitMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: SplitMode.equal, label: Text('Equally')),
                  ButtonSegment(value: SplitMode.exact, label: Text('Amounts')),
                  ButtonSegment(value: SplitMode.percent, label: Text('%')),
                  ButtonSegment(value: SplitMode.shares, label: Text('Shares')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => _setMode(v.first),
              ),
            ),
            if (_mode == SplitMode.shares)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('E.g. a couple = 2 shares, a single person = 1.',
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (final part in parts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          avatar(part.person),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name(part.person), style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (part.person == _payer)
                                  Text('paid', style: TextStyle(fontSize: 11.5, color: cs.primary)),
                              ],
                            ),
                          ),
                          if (_mode != SplitMode.equal) ...[
                            SizedBox(
                              width: 86,
                              child: TextField(
                                controller: _ctl(part.person),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  isDense: true,
                                  suffixText: _mode == SplitMode.percent
                                      ? '%'
                                      : _mode == SplitMode.shares
                                          ? '×'
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          SizedBox(
                            width: _mode == SplitMode.exact ? 0 : 92,
                            child: _mode == SplitMode.exact
                                ? null
                                : Text(Fmt.money(part.amount),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  if (parts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Pick people above', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            if (_who.contains(-1))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add my share to my expenses'),
                subtitle: const Text('Keeps your budget accurate'),
                value: _recordMyShare,
                onChanged: (v) => setState(() => _recordMyShare = v),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- detail

class SplitDetail extends StatefulWidget {
  final int id;
  const SplitDetail({super.key, required this.id});
  @override
  State<SplitDetail> createState() => _SplitDetailState();
}

class _SplitDetailState extends State<SplitDetail> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final b = s.splitById(widget.id);
    if (b == null) return const Scaffold(body: SizedBox.shrink());
    final sh = SplitSheet.of(s, b);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split bill'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete' &&
                  await confirm(context, 'Delete this split?', 'Its amounts are removed from everyone\'s balance.')) {
                await s.deleteSplit(b);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete split'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          RepaintBoundary(
            key: _key,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SplitInvoice(
                sheet: sh,
                onRowTap: (r) => s.setSplitSettled(b, r.person, !r.paid),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Tap a person to mark their part paid.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 18),
          Text('Send to the group', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          SplitShareBar(sheet: sh, imageKey: _key),
          const SizedBox(height: 8),
          Text(
            'The link carries the bill inside it — friends open it in any browser to see their part. Nothing is uploaded.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- link view

/// What a friend sees when they open a split link. Works on a fresh browser
/// with no data; optionally adds their part to their own ledger.
class SplitViewScreen extends StatefulWidget {
  final String encoded;
  const SplitViewScreen({super.key, required this.encoded});
  @override
  State<SplitViewScreen> createState() => _SplitViewScreenState();
}

class _SplitViewScreenState extends State<SplitViewScreen> {
  final _key = GlobalKey();
  late final SplitSheet? _sh = SplitSheet.decode(widget.encoded);
  String? _me;

  Future<void> _save(AppState s, SplitSheet sh) async {
    final row = sh.rows.firstWhere((r) => r.name == _me);
    if (row.isPayer || row.paid) {
      toast(context, 'Nothing for you to pay here');
      return;
    }
    final existing = s.people.where((p) => p.name.toLowerCase() == sh.payer.toLowerCase()).firstOrNull;
    final pid = existing?.id ??
        await s.putRow('people', Person(name: sh.payer, color: kPalette[s.people.length % kPalette.length]).toMap());
    await s.putRow('ious', Iou(personId: pid, amount: -row.amount, note: sh.title, date: sh.date, group: sh.group).toMap());
    if (mounted) toast(context, 'Added: you owe ${sh.payer} ${plainMoney(row.amount)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final sh = _sh;
    if (sh == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split bill')),
        body: const EmptyState(
            icon: Icons.link_off_rounded,
            title: 'Can\'t open this link',
            subtitle: 'It looks incomplete — ask for it to be sent again.'),
      );
    }
    final mine = _me == null ? null : sh.rows.where((r) => r.name == _me).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('${sh.payer} shared a bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          RepaintBoundary(
            key: _key,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SplitInvoice(sheet: sh, highlight: _me, onRowTap: (r) => setState(() => _me = r.name)),
            ),
          ),
          const SizedBox(height: 12),
          if (mine == null)
            Text('Tap your name to see your part.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant))
          else
            AppCard(
              child: Column(
                children: [
                  Text(mine.paid ? 'You\'ve paid your part' : 'Your part',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  Text(plainMoney(mine.amount),
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900, color: mine.paid ? _green : null)),
                  if (!mine.paid && !mine.isPayer) ...[
                    Text('to ${sh.payer}', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _save(s, sh),
                      icon: const Icon(Icons.bookmark_add_rounded),
                      label: const Text('Add to my Split & Udhaar'),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shareSplitPdf(context, sh),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shareSplitImage(context, _key, sh),
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Shared with Bills O9 Time. This bill lives only in the link — nothing is stored online.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- list tile

class SplitTile extends StatelessWidget {
  final SplitBill b;
  const SplitTile(this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final pending = b.outstanding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitDetail(id: b.id!))),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: _brand.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.receipt_long_rounded, color: _brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${Fmt.shortDate(b.date)} · ${b.parts.length} people · paid by ${s.personName(b.payer)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(b.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(pending > 0.5 ? '${Fmt.money(pending)} due' : 'settled',
                    style: TextStyle(fontSize: 11.5, color: pending > 0.5 ? const Color(0xFFD97706) : _green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
