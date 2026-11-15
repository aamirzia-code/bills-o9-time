import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'features/lock.dart';
import 'features/onboarding.dart';
import 'features/people.dart';
import 'features/split_bill.dart';
import 'sync/platform_stub.dart' if (dart.library.js_interop) 'sync/platform_web.dart';
import 'i18n.dart';
import 'notifications.dart';
import 'screens/accounts_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/budget_hub.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'skins.dart';
import 'sync/sync_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.instance.init();
  final state = AppState();
  await state.load();
  Notifier.instance.rescheduleAll(state.activeBills);
  final sync = SyncService(state);
  final lock = AppLock();
  await lock.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider.value(value: lock),
    ],
    child: const BillsApp(),
  ));
  sync.init();
}

class BillsApp extends StatelessWidget {
  const BillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final skinId = context.select<AppState, String>((s) => s.skinId);
    final lang = context.select<AppState, String>((s) => s.lang);
    final auto = skinId == kSkinAuto;
    final chosen = skinById(skinId);
    return MaterialApp(
      title: 'Bills O9 Time',
      debugShowCheckedModeBanner: false,
      theme: buildSkinTheme(auto ? skinById('daylight') : chosen),
      darkTheme: buildSkinTheme(auto ? skinById('midnight') : chosen),
      themeMode: auto
          ? ThemeMode.system
          : (chosen.dark ? ThemeMode.dark : ThemeMode.light),
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Responsive(child: LockGate(child: child!)),
      home: const Shell(),
    );
  }
}

/// On tablets and desktop browsers, keep the app phone-shaped and centred
/// instead of stretching cards across the whole screen.
class Responsive extends StatelessWidget {
  final Widget child;
  const Responsive({super.key, required this.child});

  static const maxWidth = 760.0;
  static String? _lastColor;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (kIsWeb) {
      final bg = Theme.of(context).scaffoldBackgroundColor;
      final hex = '#${(bg.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      if (hex != _lastColor) {
        _lastColor = hex;
        webSetThemeColor(hex);
      }
    }
    if (mq.size.width <= maxWidth + 40) return child;
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Color.alphaBlend(cs.onSurface.withOpacity(0.04), cs.surface),
      child: Center(
        child: Container(
          width: maxWidth,
          decoration: BoxDecoration(
            border: Border.symmetric(
                vertical: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30),
            ],
          ),
          child: ClipRect(
            child: MediaQuery(
              data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
              child: child,
            ),
          ),
        ),
      ),
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
    // A friend's shared Split & Udhaar link: ?ledger=…
    final split = kIsWeb ? Uri.base.queryParameters['split'] : null;
    if (split != null && split.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => SplitViewScreen(encoded: split)));
      });
    }
    final ledger = kIsWeb ? Uri.base.queryParameters['ledger'] : null;
    if (ledger != null && ledger.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LedgerImportScreen(encoded: ledger)));
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppLock>().onResumed();
      context.read<AppState>().runAutoPay();
      context.read<SyncService>().autoSync();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      context.read<AppLock>().onHidden();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (OnboardingScreen.needed(st) &&
        !(kIsWeb &&
            (Uri.base.queryParameters.containsKey('ledger') ||
                Uri.base.queryParameters.containsKey('split')))) {
      return const OnboardingScreen();
    }
    final overdue = st.overdueBills.length;
    context.select<AppState, String>((s) => s.lang); // rebuild labels
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
        items: [
          (Icons.home_outlined, Icons.home_rounded, tr('Home')),
          (Icons.receipt_long_outlined, Icons.receipt_long_rounded, tr('Bills')),
          (Icons.calculate_outlined, Icons.calculate_rounded, tr('Budget')),
          (Icons.account_balance_outlined, Icons.account_balance_rounded,
              tr('Accounts')),
          (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, tr('Insights')),
        ],
      ),
    );
  }
}

/// Bottom navigation, drawn in the selected skin's style.
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
    final sk = context.skin;
    final pill = sk.nav == NavKind.pill;

    Widget item(int i) {
      final sel = i == index;
      final color = sel ? sk.navSel : sk.navFg;
      final iconData = sel ? items[i].$2 : items[i].$1;
      final label = sk.nav == NavKind.metro
          ? items[i].$3.toLowerCase()
          : items[i].$3;
      BoxDecoration? deco;
      switch (sk.nav) {
        case NavKind.pill:
          deco = BoxDecoration(
            color: sel ? sk.navSelBg : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          );
        case NavKind.taskbar:
          deco = sel
              ? BoxDecoration(
                  color: sk.navSelBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 2,
                        offset: const Offset(0, 1)),
                  ],
                )
              : null;
        case NavKind.metro:
          deco = BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: sel ? sk.navSel : Colors.transparent, width: 3),
            ),
          );
        case NavKind.bar:
          deco = null;
      }
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: pill
                ? const EdgeInsets.symmetric(vertical: 6)
                : sk.nav == NavKind.taskbar
                    ? const EdgeInsets.symmetric(vertical: 7, horizontal: 2)
                    : EdgeInsets.zero,
            decoration: deco,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: (badges[i] ?? 0) > 0,
                  label: Text('${badges[i] ?? 0}'),
                  child: Icon(iconData, size: 22, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: sk.nav == NavKind.metro ? 11.5 : 10.5,
                    fontWeight: sk.nav == NavKind.metro
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = Row(children: [for (var i = 0; i < items.length; i++) item(i)]);

    if (pill) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: sk.navBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: sk.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(sk.dark ? 0.5 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: row,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: sk.navBg2 == null ? sk.navBg : null,
        gradient: sk.navBg2 == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [sk.navBg, sk.navBg2!],
              ),
        border: Border(
          top: BorderSide(
            color: sk.nav == NavKind.taskbar
                ? const Color(0xFF6FA4F7)
                : sk.outline,
            width: sk.nav == NavKind.taskbar ? 1.5 : 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(height: 58, child: row),
      ),
    );
  }
}
