import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';
import 'transactions_screen.dart';

const _kinds = ['Cash', 'Bank', 'Card', 'Wallet'];

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  int _months = 6;
  bool _trends = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = [
      for (var i = _months - 1; i >= 0; i--) DateTime(now.year, now.month - i)
    ];
    final worth = [for (final m in months) s.balanceAt(m)];
    final minY = worth.reduce((a, b) => a < b ? a : b);
    final maxY = worth.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.2).clamp(1.0, double.infinity);
    final change = worth.length > 1 ? worth.last - worth.first : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showAccountSheet(context, null),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              Text('Net worth',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const Spacer(),
              PopupMenuButton<int>(
                initialValue: _months,
                onSelected: (v) => setState(() => _months = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 3, child: Text('3 Months')),
                  PopupMenuItem(value: 6, child: Text('6 Months')),
                  PopupMenuItem(value: 12, child: Text('12 Months')),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_months Months',
                          style: const TextStyle(fontSize: 12.5)),
                      const Icon(Icons.expand_more_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(Fmt.money(s.totalBalance),
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ),
          if (change != 0)
            Text(
              '${change > 0 ? '+' : '−'}${Fmt.money(change.abs())} in $_months months',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: change > 0
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444)),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minY - pad,
                maxY: maxY + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        if (_months == 12 && i.isOdd) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('MMM').format(months[i]),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: cs.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final sp in spots)
                        LineTooltipItem(
                          Fmt.money(sp.y, compact: true),
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < worth.length; i++)
                        FlSpot(i.toDouble(), worth[i]),
                    ],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF2DD4BF),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2DD4BF).withOpacity(0.35),
                          const Color(0xFF2DD4BF).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Accounts')),
                ButtonSegment(value: true, label: Text('Trends')),
              ],
              selected: {_trends},
              onSelectionChanged: (v) => setState(() => _trends = v.first),
            ),
          ),
          const SizedBox(height: 8),
          if (!_trends) ..._accountList(context, s) else ..._trendList(context, s, months),
        ],
      ),
    );
  }

  List<Widget> _accountList(BuildContext context, AppState s) {
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];
    if (s.accounts.isEmpty) {
      out.add(const EmptyState(
        icon: Icons.account_balance_rounded,
        title: 'No accounts',
        subtitle: 'Add cash, bank, card or wallet accounts to track balances.',
      ));
    }
    final kinds = [
      ..._kinds,
      ...s.accounts.map((a) => a.kind).where((k) => !_kinds.contains(k)).toSet()
    ];
    for (final k in kinds) {
      final list = s.accounts.where((a) => a.kind == k).toList();
      if (list.isEmpty) continue;
      final total = list.fold<double>(0, (x, a) => x + s.accountBalance(a));
      out.add(GroupHeader(k, total: total));
      for (final a in list) {
        final bal = s.accountBalance(a);
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            onTap: () => showAccountSheet(context, a),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(a.color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(accountIcon(a.kind), color: Color(a.color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${a.kind} account',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  '${bal < 0 ? '-' : ''}${Fmt.money(bal.abs())}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: bal < 0 ? const Color(0xFFEF4444) : null),
                ),
              ],
            ),
          ),
        ));
      }
    }
    out.add(Padding(
      padding: const EdgeInsets.only(top: 4),
      child: OutlinedButton.icon(
        onPressed: () => showAccountSheet(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
    ));
    return out;
  }

  List<Widget> _trendList(
      BuildContext context, AppState s, List<DateTime> months) {
    final cs = Theme.of(context).colorScheme;
    return [
      for (final m in months.reversed)
        Builder(builder: (context) {
          final inc = s.incomeInMonth(m);
          final exp = s.expenseInMonth(m);
          final net = inc - exp;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionsScreen())),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.month(m),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            'In ${Fmt.money(inc, compact: true)} · Out ${Fmt.money(exp, compact: true)}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(
                    '${net >= 0 ? '+' : '−'}${Fmt.money(net.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: net >= 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
    ];
  }
}

IconData accountIcon(String kind) {
  switch (kind) {
    case 'Bank':
      return Icons.account_balance_rounded;
    case 'Card':
      return Icons.credit_card_rounded;
    case 'Wallet':
      return Icons.account_balance_wallet_rounded;
    default:
      return Icons.payments_rounded;
  }
}


Future<void> showAccountSheet(BuildContext context, Account? a) async {
  final s = context.read<AppState>();
  final name = TextEditingController(text: a?.name ?? '');
  final opening = TextEditingController(
      text: a == null ? '0' : a.openingBalance.toStringAsFixed(0));
  var kind = a?.kind ?? 'Bank';
  var color = a?.color ?? kPalette[1];
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(a == null ? 'New account' : 'Edit account',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'e.g. Meezan, JazzCash'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
                DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
              ],
              onChanged: (v) => setSt(() => kind = v ?? kind),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: opening,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                  labelText: 'Opening balance',
                  prefixText: '${Fmt.symbol} '),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in kPalette)
                  GestureDetector(
                    onTap: () => setSt(() => color = c),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(c),
                      child: color == c
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (a != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await s.deleteAccount(a);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                if (a != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      await s.saveAccount(Account(
                        id: a?.id,
                        name: name.text.trim(),
                        kind: kind,
                        openingBalance: double.tryParse(opening.text) ?? 0,
                        color: color,
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
