import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export.dart';
import '../models.dart';
import '../skins.dart';
import '../utils.dart';
import '../widgets.dart';
import '../sync/cloud_providers.dart';
import '../sync/sync_service.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import '../features/committees.dart';
import '../features/currency.dart';
import '../features/lock.dart';
import '../features/notify_settings.dart';
import '../features/seasons.dart';
import '../features/zakat.dart';
import '../i18n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionTitle(tr('Backup & Sync')),
          Builder(builder: (context) {
            final sync = context.watch<SyncService>();
            final connected = sync.kind != CloudKind.none;
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  connected ? Icons.cloud_done_rounded : Icons.cloud_outlined,
                  color: connected && !sync.needsSignIn
                      ? const Color(0xFF22C55E)
                      : null,
                ),
                title: Text(connected
                    ? cloudName(sync.kind)
                    : 'Back up to Google Drive, Dropbox or a file'),
                subtitle: Text(connected
                    ? (sync.needsSignIn
                        ? 'Sign-in expired — tap to reconnect'
                        : sync.describeLastSync())
                    : 'Encrypted, one small file, synced daily'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
            );
          }),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: Text(tr('Notifications')),
                  subtitle: const Text('Reminder time, alerts, add to Calendar'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(tr('Privacy & lock')),
                  subtitle: const Text('PIN, Face ID / fingerprint, hide amounts'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                ),
              ],
            ),
          ),
          SectionTitle(tr('Tools')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (icon, title, sub, page) in [
                  (Icons.groups_rounded, tr('Committees'), 'Committee / BC tracker',
                      () => const CommitteesScreen() as Widget),
                  (Icons.volunteer_activism_rounded, tr('Zakat calculator'),
                      'Nisab, 2.5%, yearly reminder', () => const ZakatScreen() as Widget),
                  (Icons.nightlight_round, tr('Ramadan & Eid'),
                      'Seasonal budget planner', () => const SeasonsScreen() as Widget),
                  (Icons.currency_exchange_rounded, tr('Currencies'),
                      'AED, SAR, USD… with your rates', () => const CurrenciesScreen() as Widget),
                ]) ...[
                  ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(sub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => page())),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: const Text('Add bills to Calendar'),
                  subtitle: const Text('Reminders even when the app is closed'),
                  onTap: () => exportBillsToCalendar(context),
                ),
              ],
            ),
          ),
          SectionTitle(tr('Preferences')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Your name'),
                  trailing: Text(s.userName.isEmpty ? 'Add' : s.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    final c = TextEditingController(text: s.userName);
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Your name'),
                        content: TextField(
                          controller: c,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              hintText: 'Shown on the Home screen'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, c.text),
                              child: const Text('Save')),
                        ],
                      ),
                    );
                    if (v != null) await s.setUserName(v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.payments_rounded),
                  title: const Text('Currency'),
                  trailing: Text(s.currency,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => _pickCurrency(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          s.skinId == kSkinAuto
                              ? 'Auto'
                              : skinById(s.skinId).name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ThemePicker())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(tr('Language')),
                  trailing: DropdownButton<String>(
                    value: L.languages.containsKey(s.lang) ? s.lang : 'en',
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final e in L.languages.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => s.setPref('lang', v ?? 'en'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Month starts on'),
                  subtitle: const Text('Set to your payday for salary-to-salary budgets'),
                  trailing: DropdownButton<int>(
                    value: s.monthStart,
                    underline: const SizedBox.shrink(),
                    menuMaxHeight: 320,
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text(d == 1 ? '1st (calendar)' : ordinal(d))),
                    ],
                    onChanged: (v) => s.setPref('monthStart', v ?? 1),
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
                      child: Icon(accountIcon(a.kind), color: Color(a.color)),
                    ),
                    title: Text(a.name),
                    subtitle: Text(a.kind),
                    trailing: Text(Fmt.money(s.accountBalance(a)),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => showAccountSheet(context, a),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add account'),
                  onTap: () => showAccountSheet(context, null),
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


class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    Widget tile(String id, String name, String tagline, Widget preview) {
      final selected = s.skinId == id;
      return GestureDetector(
        onTap: () => s.setSkin(id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected ? cs.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: preview,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: cs.primary),
              ],
            ),
            Text(tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Theme'))),
      body: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
        children: [
          tile(
            kSkinAuto,
            'Auto',
            'Daylight or Midnight, follows phone',
            Row(
              children: [
                Expanded(child: SkinPreview(skinById('daylight'))),
                const SizedBox(width: 4),
                Expanded(child: SkinPreview(skinById('midnight'))),
              ],
            ),
          ),
          for (final k in kSkins) tile(k.id, k.name, k.tagline, SkinPreview(k)),
        ],
      ),
    );
  }
}
