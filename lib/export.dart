import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'models.dart';
import 'utils.dart';

class Exporter {
  static String _csvCell(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// Hands a generated file to the system share sheet (iOS/Android) or the
  /// browser's share/download flow (web).
  static Future<void> _share(
      String name, List<int> bytes, String mime, String subject) async {
    final file =
        XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: mime);
    await Share.shareXFiles([file],
        subject: subject, fileNameOverrides: [name]);
  }

  /// All transactions as CSV (a full backup of your activity).
  static Future<void> shareCsv(AppState s, {DateTime? month}) async {
    final rows = <String>[
      'Date,Type,Category,Account,Description,Amount,Bill',
    ];
    final list = month == null ? s.txns : s.txnsInMonth(month);
    for (final t in list) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type == TxType.income ? 'Income' : 'Expense',
        _csvCell(s.category(t.categoryId)?.name ?? ''),
        _csvCell(s.account(t.accountId)?.name ?? ''),
        _csvCell(t.note),
        t.amount.toStringAsFixed(2),
        t.billId == null ? '' : 'Yes',
      ].join(','));
    }
    final stamp = month == null
        ? 'all'
        : DateFormat('yyyy-MM').format(month);
    await _share(
        'bills-o9-transactions-$stamp.csv',
        [0xEF, 0xBB, 0xBF, ...utf8.encode(rows.join('\n'))],
        'text/csv',
        'Bills O9 Time transactions');
  }

  static Future<void> shareMonthlyPdf(AppState s, DateTime month) async {
    final brand = PdfColor.fromInt(0xFF0F766E);
    final income = s.incomeInMonth(month);
    final spent = s.expenseInMonth(month);
    final byCat = s.expenseByCategory(month).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final txns = s.txnsInMonth(month);
    final bills = s.activeBills;

    pw.Widget stat(String label, double v) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(right: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(Fmt.money(v),
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        );

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: brand, width: 2))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Bills O9 Time',
                style: pw.TextStyle(
                    color: brand, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Monthly report - ${Fmt.month(month)}',
                style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        pw.Row(children: [
          stat('Income', income),
          stat('Expenses', spent),
          stat('Net', income - spent),
        ]),
        pw.SizedBox(height: 20),
        pw.Text('Spending by category',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (byCat.isEmpty) pw.Text('No expenses recorded.'),
        if (byCat.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount', 'Share'],
            data: [
              for (final e in byCat)
                [
                  s.category(e.key)?.name ?? 'Other',
                  Fmt.money(e.value),
                  '${(e.value / spent * 100).toStringAsFixed(1)}%',
                ],
            ],
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: brand),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 20),
        pw.Text('Upcoming bills',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (bills.isEmpty) pw.Text('No active bills.'),
        if (bills.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Bill', 'Due', 'Repeats', 'Amount'],
            data: [
              for (final b in bills)
                [
                  b.name,
                  Fmt.date(b.dueDate),
                  repeatLabel(b.repeat),
                  Fmt.money(b.amount),
                ],
            ],
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: brand),
            cellAlignments: {3: pw.Alignment.centerRight},
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 20),
        pw.Text('Transactions',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (txns.isEmpty) pw.Text('No transactions this month.'),
        if (txns.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Category', 'Amount'],
            data: [
              for (final t in txns)
                [
                  Fmt.shortDate(t.date),
                  t.note,
                  s.category(t.categoryId)?.name ?? '',
                  '${t.type == TxType.income ? '+' : '-'}${Fmt.money(t.amount)}',
                ],
            ],
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: brand),
            cellAlignments: {3: pw.Alignment.centerRight},
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
      ],
    ));

    await _share(
        'bills-o9-report-${DateFormat('yyyy-MM').format(month)}.pdf',
        await doc.save(),
        'application/pdf',
        'Bills O9 Time report ${Fmt.month(month)}');
  }
}
