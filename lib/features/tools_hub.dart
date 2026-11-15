import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../screens/accounts_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/transactions_screen.dart';
import '../widgets.dart';
import 'alerts.dart';
import 'committees.dart';
import 'currency.dart';
import 'fuel.dart';
import 'meters.dart';
import 'notify_settings.dart';
import 'people.dart';
import 'renewals.dart';
import 'seasons.dart';
import 'shopping.dart';
import 'zakat.dart';

class ToolDef {
  final String id;
  final IconData icon;
  final Color color;
  final String label;
  final String hint;
  final WidgetBuilder page;
  const ToolDef(this.id, this.icon, this.color, this.label, this.hint, this.page);

  /// Fits a Home tile.
  String get short => const {
        'people': 'Split',
        'lists': 'Lists',
        'meters': 'Meters',
        'fuel': 'Fuel',
        'seasons': 'Ramadan',
        'currencies': 'FX rates',
        'reminders': 'Reminders',
      }[id] ??
      label;
}

final kToolGroups = <String, List<ToolDef>>{
  'Everyday': [
    ToolDef('people', Icons.people_alt_rounded, const Color(0xFF0891B2), 'Split & Udhaar',
        'Who owes whom', (_) => const PeopleScreen()),
    ToolDef('lists', Icons.checklist_rounded, const Color(0xFF16A34A), 'Shopping lists',
        'Ration, sabzi, pharmacy', (_) => const ListsScreen()),
    ToolDef('renewals', Icons.event_repeat_rounded, const Color(0xFFDB2777), 'Renewals',
        'Token, insurance, CNIC, warranty', (_) => const RenewalsScreen()),
    ToolDef('meters', Icons.bolt_rounded, const Color(0xFFF59E0B), 'Meter readings',
        'Stay under 200 units', (_) => const MetersScreen()),
    ToolDef('fuel', Icons.local_gas_station_rounded, const Color(0xFFF97316), 'Fuel log',
        'Mileage & cost per km', (_) => const FuelScreen()),
  ],
  'Plan & save': [
    ToolDef('committees', Icons.groups_rounded, const Color(0xFF7C3AED), 'Committees',
        'BC / ROSCA rounds', (_) => const CommitteesScreen()),
    ToolDef('goals', Icons.savings_rounded, const Color(0xFF22C55E), 'Goals',
        'Save for anything', (_) => const GoalsScreen()),
    ToolDef('seasons', Icons.nightlight_round, const Color(0xFFF5B000), 'Ramadan & Eid',
        'Seasonal budget', (_) => const SeasonsScreen()),
    ToolDef('zakat', Icons.volunteer_activism_rounded, const Color(0xFF16A34A), 'Zakat',
        'Calculate & record', (_) => const ZakatScreen()),
  ],
  'Money': [
    ToolDef('sms', Icons.sms_outlined, const Color(0xFF8B5CF6), 'Bank SMS',
        'Paste an alert', (_) => const TxnForm(pasteSms: true)),
    ToolDef('accounts', Icons.account_balance_wallet_rounded, const Color(0xFF2F80ED), 'Accounts',
        'Cash, bank, cards', (_) => const AccountsScreen()),
    ToolDef('currencies', Icons.currency_exchange_rounded, const Color(0xFF0F766E), 'Currencies',
        'Your exchange rates', (_) => const CurrenciesScreen()),
    ToolDef('insights', Icons.insights_rounded, const Color(0xFFEA580C), 'Insights',
        'Trends & heatmap', (_) => const ReportsScreen()),
    ToolDef('alerts', Icons.notifications_active_rounded, const Color(0xFFEF4444), 'Alerts',
        'Everything due', (_) => const AlertsScreen()),
    ToolDef('reminders', Icons.edit_notifications_rounded, const Color(0xFF64748B), 'Reminders',
        'Notifications & calendar', (_) => const NotificationSettingsScreen()),
  ],
};

ToolDef? toolById(String id) {
  for (final g in kToolGroups.values) {
    for (final t in g) {
      if (t.id == id) return t;
    }
  }
  return null;
}

const kDefaultPinned = ['people', 'lists', 'committees', 'zakat'];

List<ToolDef> pinnedTools(AppState s) {
  final ids = s.pref<List>('pinnedTools', kDefaultPinned).cast<String>();
  return ids.map(toolById).whereType<ToolDef>().toList();
}

/// Every feature in one place, grouped. Star a tool to pin it on Home.
class ToolsHub extends StatelessWidget {
  const ToolsHub({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final pinned = pinnedTools(s).map((t) => t.id).toList();
    final w = MediaQuery.sizeOf(context).width.clamp(0, 760);
    final cols = w > 600 ? 4 : (w > 360 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(title: Text(tr('All tools'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text('Star up to 4 to pin them on Home.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          for (final g in kToolGroups.entries) ...[
            SectionTitle(g.key),
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final t in g.value)
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: t.page)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: t.color.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(t.icon, color: t.color),
                            ),
                            const Spacer(),
                            InkResponse(
                              radius: 18,
                              onTap: () {
                                final next = [...pinned];
                                if (next.contains(t.id)) {
                                  next.remove(t.id);
                                } else {
                                  if (next.length >= 4) next.removeAt(0);
                                  next.add(t.id);
                                }
                                s.setPref('pinnedTools', next);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  pinned.contains(t.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 20,
                                  color: pinned.contains(t.id) ? const Color(0xFFF5B000) : cs.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(tr(t.label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(t.hint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.25)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
