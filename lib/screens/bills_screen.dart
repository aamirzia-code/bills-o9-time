import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_form.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final active = s.activeBills;
    final overdue = active.where((b) => b.daysUntilDue(now) < 0).toList();
    final week = active.where((b) {
      final d = b.daysUntilDue(now);
      return d >= 0 && d <= 7;
    }).toList();
    final later = active.where((b) => b.daysUntilDue(now) > 7).toList();
    final paidOff = s.bills.where((b) => !b.active).toList();
    final monthlyTotal = active.fold<double>(0, (sum, b) {
      switch (b.repeat) {
        case Repeat.weekly:
          return sum + b.amount * 52 / 12;
        case Repeat.biweekly:
          return sum + b.amount * 26 / 12;
        case Repeat.monthly:
          return sum + b.amount;
        case Repeat.quarterly:
          return sum + b.amount / 3;
        case Repeat.yearly:
          return sum + b.amount / 12;
        case Repeat.none:
          return sum;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BillForm())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bill'),
      ),
      body: active.isEmpty && paidOff.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No bills yet',
              subtitle:
                  'Add rent, electricity, internet, card payments and subscriptions. We\'ll remind you before they\'re due.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                AppCard(
                  color: Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recurring bills / month',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(Fmt.money(monthlyTotal),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      _Pill('${active.length} active', Colors.white24),
                    ],
                  ),
                ),
                if (overdue.isNotEmpty) ...[
                  const SectionTitle('Overdue'),
                  for (final b in overdue) BillTile(b),
                ],
                if (week.isNotEmpty) ...[
                  const SectionTitle('Next 7 days'),
                  for (final b in week) BillTile(b),
                ],
                if (later.isNotEmpty) ...[
                  const SectionTitle('Later'),
                  for (final b in later) BillTile(b),
                ],
                if (paidOff.isNotEmpty) ...[
                  const SectionTitle('Completed one-time bills'),
                  for (final b in paidOff) BillTile(b),
                ],
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  const _Pill(this.text, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      );
}

class BillTile extends StatelessWidget {
  final Bill bill;
  const BillTile(this.bill, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cat = s.category(bill.categoryId);
    final days = bill.daysUntilDue(DateTime.now());
    final color = dueColor(context, days);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => BillDetail(billId: bill.id!))),
        child: Row(
          children: [
            CategoryAvatar(cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    bill.active
                        ? '${dueLabel(days)} · ${Fmt.shortDate(bill.dueDate)}'
                        : 'Paid · ${repeatLabel(bill.repeat)}',
                    style: TextStyle(
                        color: bill.active
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.money(bill.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                if (bill.active)
                  SizedBox(
                    height: 30,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      onPressed: () => showPaySheet(context, bill),
                      child: const Text('Mark paid'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPaySheet(BuildContext context, Bill bill) async {
  final s = context.read<AppState>();
  final amount = TextEditingController(text: _trim(bill.amount));
  var date = DateTime.now();
  int? accountId = s.account(bill.accountId)?.id ??
      (s.accounts.isNotEmpty ? s.accounts.first.id : null);
  final formKey = GlobalKey<FormState>();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pay ${bill.name}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              MoneyField(controller: amount),
              const SizedBox(height: 12),
              DateField(
                  label: 'Paid on',
                  value: date,
                  onChanged: (d) => setSt(() => date = d)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: const InputDecoration(labelText: 'Paid from'),
                items: [
                  for (final a in s.accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setSt(() => accountId = v),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirm payment'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await s.markBillPaid(bill,
                      amount: double.parse(amount.text),
                      date: date,
                      accountId: accountId);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    toast(
                        context,
                        bill.repeat == Repeat.none
                            ? '${bill.name} paid'
                            : '${bill.name} paid · next due ${Fmt.shortDate(nextDue(bill.dueDate, bill.repeat))}');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class BillDetail extends StatelessWidget {
  final int billId;
  const BillDetail({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Bill? bill;
    for (final b in s.bills) {
      if (b.id == billId) bill = b;
    }
    if (bill == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final b = bill;
    final cat = s.category(b.categoryId);
    final payments = s.paymentsFor(b);
    final days = b.daysUntilDue(DateTime.now());
    final totalPaid = payments.fold<double>(0, (x, t) => x + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(b.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BillForm(bill: b))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (await confirm(context, 'Delete bill?',
                  'Payment history stays in your transactions.')) {
                await s.deleteBill(b);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                CategoryAvatar(cat, size: 64),
                const SizedBox(height: 12),
                Text(Fmt.money(b.amount),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  b.active
                      ? '${dueLabel(days)} · ${Fmt.date(b.dueDate)}'
                      : 'Completed',
                  style: TextStyle(
                      color: dueColor(context, days),
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Chip(label: Text(repeatLabel(b.repeat))),
                    Chip(label: Text(cat?.name ?? 'Uncategorized')),
                    Chip(
                        label: Text(b.remindDaysBefore == 0
                            ? 'Remind on due date'
                            : 'Remind ${b.remindDaysBefore}d before')),
                  ],
                ),
                if (b.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(b.notes, textAlign: TextAlign.center),
                ],
                if (b.active) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => showPaySheet(context, b),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Mark paid'),
                        ),
                      ),
                      if (b.repeat != Repeat.none) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await s.skipBill(b);
                              if (context.mounted) {
                                toast(context, 'Skipped this cycle');
                              }
                            },
                            icon: const Icon(Icons.skip_next_rounded),
                            label: const Text('Skip'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          SectionTitle('Payment history · ${Fmt.money(totalPaid)}'),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No payments recorded yet.'),
            ),
          for (final t in payments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF16A34A)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(Fmt.date(t.date))),
                    Text(Fmt.money(t.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
