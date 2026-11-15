import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../notifications.dart';
import '../utils.dart';
import '../widgets.dart';
import 'logic.dart';

/// Shares an .ics file with every active bill as a repeating calendar event.
Future<void> exportBillsToCalendar(BuildContext context) async {
  final s = context.read<AppState>();
  if (s.activeBills.isEmpty) {
    toast(context, 'Add a bill first');
    return;
  }
  final ics = buildIcs(s.activeBills,
      money: (v) {
        final hidden = Fmt.hidden;
        Fmt.hidden = false;
        final out = Fmt.money(v);
        Fmt.hidden = hidden;
        return out;
      },
      hour: s.pref<int>('remindHour', 9));
  final bytes = Uint8List.fromList(utf8.encode(ics));
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: 'bills-o9-calendar.ics', mimeType: 'text/calendar')],
    fileNameOverrides: ['bills-o9-calendar.ics'],
    subject: 'Bills O9 Time calendar',
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final hour = s.pref<int>('remindHour', 9);
    final def = s.pref<int>('defaultRemind', 2);

    Widget sw(String key, String title, String sub, {bool fallback = true}) =>
        SwitchListTile(
          title: Text(title),
          subtitle: Text(sub),
          value: s.pref<bool>(key, fallback),
          onChanged: (v) => s.setPref(key, v),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (kIsWeb)
            AppCard(
              color: kBlue.withOpacity(0.12),
              child: const Text(
                'In the web app, alerts show in the bell on Home. For alerts when the app is closed, add your bills to your phone\'s Calendar below. Each event carries its own reminders.',
              ),
            ),
          const SectionTitle('Bill reminders'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time_rounded),
                  title: const Text('Reminder time'),
                  trailing: Text(
                      TimeOfDay(hour: hour, minute: 0).format(context),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: 0));
                    if (t == null) return;
                    await s.setPref('remindHour', t.hour);
                    await Notifier.instance.rescheduleAll(s.activeBills);
                  },
                ),
                Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Default for new bills'),
                  trailing: DropdownButton<int>(
                    value: [0, 1, 2, 3, 5, 7].contains(def) ? def : 2,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('On due date')),
                      DropdownMenuItem(value: 1, child: Text('1 day before')),
                      DropdownMenuItem(value: 2, child: Text('2 days before')),
                      DropdownMenuItem(value: 3, child: Text('3 days before')),
                      DropdownMenuItem(value: 5, child: Text('5 days before')),
                      DropdownMenuItem(value: 7, child: Text('1 week before')),
                    ],
                    onChanged: (v) => s.setPref('defaultRemind', v ?? 2),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Alerts'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                sw('overdueNudge', 'Overdue bills',
                    'Keep reminding until a bill is paid'),
                Divider(height: 1, color: cs.outlineVariant),
                sw('budgetAlerts', 'Budget warnings',
                    'At 80% and when a budget is exceeded'),
                Divider(height: 1, color: cs.outlineVariant),
                sw('subscriptionTips', 'Subscription finder',
                    'Suggest repeating expenses to add as bills'),
              ],
            ),
          ),
          const SectionTitle('Calendar'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.event_available_rounded),
              title: const Text('Add bills to Calendar'),
              subtitle: const Text(
                  'Creates repeating events with alerts in iPhone or Google Calendar. Tap again after adding bills.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => exportBillsToCalendar(context),
            ),
          ),
        ],
      ),
    );
  }
}
