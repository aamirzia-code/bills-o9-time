import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Icons are stored as string keys so release builds can tree-shake fonts.
const Map<String, IconData> kIcons = {
  'home': Icons.home_rounded,
  'bolt': Icons.bolt_rounded,
  'water': Icons.water_drop_rounded,
  'gas': Icons.local_fire_department_rounded,
  'wifi': Icons.wifi_rounded,
  'phone': Icons.smartphone_rounded,
  'tv': Icons.live_tv_rounded,
  'card': Icons.credit_card_rounded,
  'loan': Icons.account_balance_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'food': Icons.restaurant_rounded,
  'grocery': Icons.shopping_cart_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'health': Icons.medical_services_rounded,
  'school': Icons.school_rounded,
  'fun': Icons.celebration_rounded,
  'travel': Icons.flight_rounded,
  'gift': Icons.card_giftcard_rounded,
  'insurance': Icons.shield_rounded,
  'subscription': Icons.subscriptions_rounded,
  'family': Icons.family_restroom_rounded,
  'salary': Icons.payments_rounded,
  'business': Icons.work_rounded,
  'invest': Icons.trending_up_rounded,
  'savings': Icons.savings_rounded,
  'retire': Icons.chair_rounded,
  'emergency': Icons.health_and_safety_rounded,
  'debt': Icons.trending_down_rounded,
  'milk': Icons.local_drink_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'bike': Icons.two_wheeler_rounded,
  'cloud': Icons.cloud_rounded,
  'committee': Icons.groups_rounded,
  'other': Icons.category_rounded,
};

const kBlue = Color(0xFF2F80ED);

IconData iconFor(String key) => kIcons[key] ?? Icons.category_rounded;

const List<int> kPalette = [
  0xFF0F766E, // teal
  0xFF2563EB, // blue
  0xFF7C3AED, // violet
  0xFFDB2777, // pink
  0xFFEA580C, // orange
  0xFFCA8A04, // amber
  0xFF16A34A, // green
  0xFF0891B2, // cyan
  0xFFDC2626, // red
  0xFF475569, // slate
];

class Fmt {
  static String symbol = 'Rs';

  static String money(double v, {bool compact = false}) {
    if (compact && v.abs() >= 100000) {
      return '$symbol ${NumberFormat.compact().format(v)}';
    }
    final f = NumberFormat('#,##0.##');
    return '$symbol ${f.format(v)}';
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String shortDate(DateTime d) => DateFormat('d MMM').format(d);
  static String month(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String day(DateTime d) => DateFormat('EEE, d MMM').format(d);
}

String dueLabel(int days) {
  if (days < 0) return days == -1 ? 'Overdue 1 day' : 'Overdue ${-days} days';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}

Color dueColor(BuildContext context, int days) {
  if (days < 0) return const Color(0xFFDC2626);
  if (days <= 3) return const Color(0xFFEA580C);
  return Theme.of(context).colorScheme.primary;
}
