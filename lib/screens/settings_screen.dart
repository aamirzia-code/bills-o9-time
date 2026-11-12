import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionTitle('Preferences'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_rounded),
                  title: const Text('Currency'),
                  trailing: Text(s.currency,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => _pickCurrency(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Appearance'),
                  trailing: DropdownButton<ThemeMode>(
                    value: s.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Dark')),
                    ],
                    onChanged: (m) => s.setTheme(m ?? ThemeMode.system),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Accounts'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final a in s.accounts) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(a.color).withOpacity(0.15),
                      child: Icon(_accountIcon(a.kind), color: Color(a.color)),
                    ),
                    title: Text(a.name),
                    subtitle: Text(a.kind),
                    trailing: Text(Fmt.money(s.accountBalance(a)),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => _editAccount(context, a),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add account'),
                  onTap: () => _editAccount(context, null),
                ),
              ],
            ),
          ),
          const SectionTitle('Data'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_rounded),
                  title: const Text('Categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CategoriesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export all transactions (CSV)'),
                  onTap: () => Exporter.shareCsv(s),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626)),
                  title: const Text('Erase all data',
                      style: TextStyle(color: Color(0xFFDC2626))),
                  subtitle: const Text(
                      'Removes bills, transactions, budgets and goals'),
                  onTap: () async {
                    if (await confirm(context, 'Erase everything?',
                        'This permanently deletes all your bills, transactions, budgets and goals on this phone.',
                        ok: 'Erase')) {
                      await s.wipeData();
                      if (context.mounted) toast(context, 'All data erased');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.lock_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kIsWeb
                      ? 'Your data is stored only in this browser. Nothing is sent to any server. Export a CSV regularly as a backup.'
                      : 'Your data is stored only on this device. Nothing is sent to any server.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Bills O9 Time · v1.0.0',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  IconData _accountIcon(String kind) {
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

  Future<void> _pickCurrency(BuildContext context) async {
    final s = context.read<AppState>();
    const options = ['Rs', 'PKR', 'AED', 'SAR', 'QAR', '\$', '£', '€', '₹', '¥'];
    final custom = TextEditingController();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Currency symbol',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  ChoiceChip(
                    label: Text(o),
                    selected: s.currency == o,
                    onSelected: (_) async {
                      await s.setCurrency(o);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: custom,
              decoration: InputDecoration(
                labelText: 'Custom symbol',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () async {
                    if (custom.text.trim().isEmpty) return;
                    await s.setCurrency(custom.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAccount(BuildContext context, Account? a) async {
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
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(tabs: [Tab(text: 'Expense'), Tab(text: 'Income')]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            onPressed: () => _edit(
                ctx,
                null,
                DefaultTabController.of(ctx).index == 0
                    ? TxType.expense
                    : TxType.income),
            child: const Icon(Icons.add_rounded),
          ),
        ),
        body: TabBarView(
          children: [
            for (final t in TxType.values)
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  for (final c in s.categoriesOf(t))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => _edit(context, c, t),
                        child: Row(
                          children: [
                            CategoryAvatar(c, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, TxCategory? c, TxType type) async {
    final s = context.read<AppState>();
    final name = TextEditingController(text: c?.name ?? '');
    var icon = c?.icon ?? 'other';
    var color = c?.color ?? kPalette[0];
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in kIcons.entries)
                      GestureDetector(
                        onTap: () => setSt(() => icon = e.key),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: icon == e.key
                                ? Color(color)
                                : Color(color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(e.value,
                              color: icon == e.key
                                  ? Colors.white
                                  : Color(color)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in kPalette)
                      GestureDetector(
                        onTap: () => setSt(() => color = k),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(k),
                          child: color == k
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
                    if (c != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await s.deleteCategory(c);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Delete'),
                        ),
                      ),
                    if (c != null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () async {
                          if (name.text.trim().isEmpty) return;
                          await s.saveCategory(TxCategory(
                            id: c?.id,
                            name: name.text.trim(),
                            type: type,
                            icon: icon,
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
      ),
    );
  }
}
