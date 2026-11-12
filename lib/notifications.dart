import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'utils.dart';

class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bill_reminders',
      'Bill reminders',
      channelDescription: 'Reminders before and on bill due dates',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      // Reminders are scheduled as absolute instants (UTC), so the device's
      // own time zone is applied automatically when the local time is built.
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> cancelBill(int billId) async {
    if (!_ready) return;
    await _plugin.cancel(billId * 10);
    await _plugin.cancel(billId * 10 + 1);
  }

  Future<void> scheduleBill(Bill b) async {
    if (!_ready || b.id == null) return;
    await cancelBill(b.id!);
    if (!b.active) return;
    final due = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day, 9);
    final now = DateTime.now();
    final amount = Fmt.money(b.amount);

    if (b.remindDaysBefore > 0) {
      final early = due.subtract(Duration(days: b.remindDaysBefore));
      if (early.isAfter(now)) {
        await _schedule(b.id! * 10, '${b.name} due soon',
            '$amount is due on ${Fmt.date(b.dueDate)}', early);
      }
    }
    if (due.isAfter(now)) {
      await _schedule(b.id! * 10 + 1, '${b.name} is due today',
          'Pay $amount today to avoid late fees', due);
    }
  }

  Future<void> _schedule(int id, String title, String body, DateTime at) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.UTC),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule failed: $e');
    }
  }

  Future<void> rescheduleAll(List<Bill> bills) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final b in bills) {
      await scheduleBill(b);
    }
  }
}
