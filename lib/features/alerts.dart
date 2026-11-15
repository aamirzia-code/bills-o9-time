import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../screens/bill_form.dart';
import '../screens/bills_screen.dart';
import '../utils.dart';
import '../widgets.dart';
import 'committees.dart';
import 'logic.dart';
import 'zakat.dart';

enum AlertKind { overdue, due, budget, committee, zakat, subscription }

class AppAlert {
  final String id;
  final AlertKind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Bill? bill;
  final SubscriptionGuess? guess;
  final Committee? committee;
  const AppAlert({
    required this.id,
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.bill,
    this.guess,
    this.committee,
  });
}

const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF22C55E);

Map<String, String> _snoozed(AppState s) {
  final raw = s.prefs['snoozed'];
  if (raw is! Map) return {};
  return raw.map((k, v) => MapEntry('$k', '$v'));
}

bool _isSnoozed(Map<String, String> sn, String id) {
  final until = DateTime.tryParse(sn[id] ?? '');
  return until != null && until.isAfter(DateTime.now());
}

Future<void> snoozeAlert(AppState s, String id, Duration d) async {
  final sn = _snoozed(s)
    ..removeWhere((k, v) =>
        (DateTime.tryParse(v) ?? DateTime(2000)).isBefore(DateTime.now()));
  sn[id] = DateTime.now().add(d).toIso8601String();
  await s.setPref('snoozed', sn);
}

/// Everything that needs attention, newest-relevant first.
List<AppAlert> computeAlerts(AppState s) {
  final sn = _snoozed(s);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <AppAlert>[];

  if (s.pref<bool>('overdueNudge', true)) {
    for (final b in s.overdueBills) {
      final days = today
          .difference(DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day))
          .inDays;
      out.add(AppAlert(
        id: 'overdue-${b.id}-${b.dueDate.millisecondsSinceEpoch}',
        kind: AlertKind.overdue,
        icon: Icons.error_outline_rounded,
        color: _red,
        title: '${b.name} is overdue',
        subtitle:
            '${Fmt.money(b.amount)} · due ${Fmt.shortDate(b.dueDate)} ($days day${days == 1 ? '' : 's'} ago)',
        bill: b,
      ));
    }
  }

  for (final b in s.activeBills) {
    final days = b.daysUntilDue(now);
    if (days < 0) continue;
    final window = b.remindDaysBefore < 1 ? 1 : b.remindDaysBefore;
    if (days > window) continue;
    out.add(AppAlert(
      id: 'due-${b.id}-${b.dueDate.millisecondsSinceEpoch}',
      kind: AlertKind.due,
      icon: Icons.schedule_rounded,
      color: days == 0 ? _amber : kBlue,
      title: days == 0
          ? '${b.name} is due today'
          : '${b.name} is due ${days == 1 ? 'tomorrow' : 'in $days days'}',
      subtitle:
          '${Fmt.money(b.amount)}${b.refNo.isEmpty ? '' : ' · Ref ${b.refNo}'}',
      bill: b,
    ));
  }

  if (s.pref<bool>('budgetAlerts', true)) {
    final m = s.currentMonth;
    final overall = s.overallBudget();
    if (overall != null && overall.amount > 0) {
      final spent = s.expenseInMonth(m);
      final r = spent / overall.amount;
      if (r >= 0.8) {
        out.add(AppAlert(
          id: 'budget-all-${m.year}-${m.month}-${r >= 1 ? 'over' : '80'}',
          kind: AlertKind.budget,
          icon: Icons.pie_chart_rounded,
          color: r >= 1 ? _red : _amber,
          title: r >= 1
              ? 'Monthly budget exceeded'
              : '${(r * 100).round()}% of monthly budget used',
          subtitle:
              '${Fmt.money(spent)} of ${Fmt.money(overall.amount)} · ${s.daysLeftInPeriod} days left',
        ));
      }
    }
    for (final b in s.categoryBudgets) {
      if (b.amount <= 0) continue;
      final spent = s.expenseInMonth(m, categoryId: b.categoryId);
      final r = spent / b.amount;
      if (r < 0.8) continue;
      final name = s.category(b.categoryId)?.name ?? 'Category';
      out.add(AppAlert(
        id: 'budget-${b.id}-${m.year}-${m.month}-${r >= 1 ? 'over' : '80'}',
        kind: AlertKind.budget,
        icon: Icons.pie_chart_outline_rounded,
        color: r >= 1 ? _red : _amber,
        title: r >= 1 ? '$name budget exceeded' : '$name at ${(r * 100).round()}%',
        subtitle: '${Fmt.money(spent)} of ${Fmt.money(b.amount)}',
      ));
    }
  }

  for (final c in s.committees) {
    if (c.rounds == 0 || c.finished) continue;
    final r = c.currentRound(now);
    final due = c.roundDate(r);
    final daysTo = DateTime(due.year, due.month, due.day).difference(today).inDays;
    final paid = c.paidCount(r);
    if (daysTo <= 3 && paid < c.rounds) {
      out.add(AppAlert(
        id: 'committee-${c.id}-$r-$paid',
        kind: AlertKind.committee,
        icon: Icons.groups_rounded,
        color: daysTo < 0 ? _red : kBlue,
        title: '${c.name}: round $r collection',
        subtitle:
            '$paid of ${c.rounds} paid · ${Fmt.money(c.share)} each · ${daysTo < 0 ? 'was due ${Fmt.shortDate(due)}' : daysTo == 0 ? 'due today' : 'due ${Fmt.shortDate(due)}'}',
        committee: c,
      ));
    }
    if (r == c.myTurn && !c.payouts.contains(r)) {
      out.add(AppAlert(
        id: 'committee-mine-${c.id}-$r',
        kind: AlertKind.committee,
        icon: Icons.celebration_rounded,
        color: _green,
        title: 'Your turn: ${c.name} pays out this month',
        subtitle: 'Pot ${Fmt.money(c.pot)}',
        committee: c,
      ));
    }
  }

  final zd = DateTime.tryParse(s.pref<String>('zakatDate', ''));
  if (zd != null) {
    var next = DateTime(now.year, zd.month, zd.day);
    if (next.isBefore(today)) next = DateTime(now.year + 1, zd.month, zd.day);
    final d = next.difference(today).inDays;
    if (d <= 14) {
      out.add(AppAlert(
        id: 'zakat-${next.year}',
        kind: AlertKind.zakat,
        icon: Icons.volunteer_activism_rounded,
        color: _green,
        title: d == 0 ? 'Your Zakat date is today' : 'Zakat date in $d days',
        subtitle: 'Review your Zakat calculation for ${next.year}',
      ));
    }
  }

  if (s.pref<bool>('subscriptionTips', true)) {
    for (final g in findSubscriptions(s.txns, s.bills).take(3)) {
      out.add(AppAlert(
        id: 'sub-${g.name.toLowerCase()}',
        kind: AlertKind.subscription,
        icon: Icons.autorenew_rounded,
        color: const Color(0xFF8B5CF6),
        title: '${g.name} looks like a ${repeatLabel(g.repeat).toLowerCase()} bill',
        subtitle:
            '${Fmt.money(g.amount)} · ${g.count} payments · add it to get reminders',
        guess: g,
      ));
    }
  }

  return out.where((a) => !_isSnoozed(sn, a.id)).toList();
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final alerts = computeAlerts(s);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alerts.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All clear',
              subtitle:
                  'Due bills, overdue payments, budget warnings, committee rounds and Zakat reminders appear here.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final a in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: a.color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(a.icon, color: a.color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(a.subtitle,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => snoozeAlert(
                                    s,
                                    a.id,
                                    a.kind == AlertKind.subscription
                                        ? const Duration(days: 60)
                                        : const Duration(days: 1)),
                                child: Text(a.kind == AlertKind.subscription
                                    ? 'Dismiss'
                                    : 'Snooze 1 day'),
                              ),
                              if (a.bill != null)
                                TextButton(
                                  onPressed: () => showPaySheet(context, a.bill!),
                                  child: const Text('Pay'),
                                ),
                              if (a.guess != null)
                                TextButton(
                                  onPressed: () {
                                    final g = a.guess!;
                                    var next = g.last;
                                    while (!next.isAfter(DateTime.now())) {
                                      next = nextDue(next, g.repeat,
                                          dueDay: g.repeat == Repeat.monthly
                                              ? g.last.day
                                              : 0);
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BillForm(
                                          bill: Bill(
                                            name: g.name,
                                            amount: g.amount,
                                            categoryId: g.categoryId,
                                            dueDate: DateTime(next.year,
                                                next.month, next.day, 9),
                                            repeat: g.repeat,
                                            dueDay: g.repeat == Repeat.monthly
                                                ? g.last.day
                                                : 0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Add as bill'),
                                ),
                              if (a.committee != null)
                                TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CommitteeDetail(
                                              id: a.committee!.id!))),
                                  child: const Text('Open'),
                                ),
                              if (a.kind == AlertKind.zakat)
                                TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const ZakatScreen())),
                                  child: const Text('Open'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
