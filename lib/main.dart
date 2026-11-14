import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'notifications.dart';
import 'screens/accounts_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/budget_hub.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';

const kAccent = Color(0xFF2F80ED);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.instance.init();
  final state = AppState();
  await state.load();
  Notifier.instance.rescheduleAll(state.activeBills);
  runApp(ChangeNotifierProvider.value(value: state, child: const BillsApp()));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: kAccent, brightness: b);
  final scheme = base.copyWith(
    primary: kAccent,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF13294B) : const Color(0xFFDCE9FD),
    onPrimaryContainer: dark ? const Color(0xFFBFD7FB) : const Color(0xFF0B3A7A),
    surface: dark ? const Color(0xFF000000) : const Color(0xFFF2F3F7),
    surfaceContainerLow: dark ? const Color(0xFF161618) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF1C1C1F) : const Color(0xFFF7F8FA),
    surfaceContainerHigh: dark ? const Color(0xFF242428) : const Color(0xFFEDEFF3),
    surfaceContainerHighest:
        dark ? const Color(0xFF2C2C31) : const Color(0xFFE4E7EC),
    onSurface: dark ? const Color(0xFFF2F2F4) : const Color(0xFF111318),
    onSurfaceVariant: dark ? const Color(0xFF9A9AA2) : const Color(0xFF5F6470),
    outlineVariant: dark ? const Color(0xFF2A2A2F) : const Color(0xFFE1E4EA),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: kAccent,
      unselectedLabelColor: scheme.onSurface,
      indicatorColor: kAccent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundColor: dark ? const Color(0xFF34D399) : kAccent,
      shape: const CircleBorder(),
    ),
  );
}

class BillsApp extends StatelessWidget {
  const BillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Bills O9 Time',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();

  static ShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;
  int _billsTab = 0;

  void goTo(int i, {int? billsTab}) => setState(() {
        _index = i;
        if (billsTab != null) _billsTab = billsTab;
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().runAutoPay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdue = context.watch<AppState>().overdueBills.length;
    final pages = [
      HomeScreen(onNavigate: (i, {int? billsTab}) => goTo(i, billsTab: billsTab)),
      BillsScreen(key: ValueKey('bills-$_billsTab'), initialTab: _billsTab),
      const BudgetHub(),
      const AccountsScreen(),
      const ReportsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: PillNavBar(
        index: _index,
        onTap: (i) => goTo(i),
        badges: {1: overdue},
        items: const [
          (Icons.home_outlined, Icons.home_rounded, 'Home'),
          (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bills'),
          (Icons.calculate_outlined, Icons.calculate_rounded, 'Budget'),
          (Icons.account_balance_outlined, Icons.account_balance_rounded,
              'Accounts'),
          (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Insights'),
        ],
      ),
    );
  }
}

/// Floating rounded bottom bar.
class PillNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  final Map<int, int> badges;

  const PillNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E1E22) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.5 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: i == index
                            ? (dark
                                ? const Color(0xFF2A2A30)
                                : const Color(0xFFEAF2FE))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: (badges[i] ?? 0) > 0,
                            label: Text('${badges[i] ?? 0}'),
                            child: Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              size: 22,
                              color: i == index ? kAccent : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$3,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: i == index ? kAccent : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
