import 'package:flutter/material.dart';

/// Visual themes ("skins") selectable in Settings. Each is an original
/// look inspired by a classic design style; no third-party logos or artwork.
enum NavKind { pill, bar, taskbar, metro }

class Skin {
  final String id;
  final String name;
  final String tagline;
  final Brightness brightness;
  final Color accent;
  final Color bg;
  final Color card;
  final Color card2;
  final Color card3;
  final Color card4;
  final Color text;
  final Color muted;
  final Color outline;
  final double radius;
  final double buttonRadius;
  final Color? cardBorder;
  final bool cardShadow;
  final Color appBarBg;
  final Color appBarFg;
  final bool centerTitle;
  final FontWeight titleWeight;
  final double titleSize;
  final Color tabLabel;
  final Color tabUnselected;
  final Color tabIndicator;
  final NavKind nav;
  final Color navBg;
  final Color? navBg2; // gradient end
  final Color navFg;
  final Color navSel;
  final Color navSelBg;
  final Color fabBg;
  final Color fabFg;

  const Skin({
    required this.id,
    required this.name,
    required this.tagline,
    required this.brightness,
    required this.accent,
    required this.bg,
    required this.card,
    required this.card2,
    required this.card3,
    required this.card4,
    required this.text,
    required this.muted,
    required this.outline,
    this.radius = 16,
    this.buttonRadius = 24,
    this.cardBorder,
    this.cardShadow = false,
    required this.appBarBg,
    required this.appBarFg,
    this.centerTitle = true,
    this.titleWeight = FontWeight.w700,
    this.titleSize = 17,
    required this.tabLabel,
    required this.tabUnselected,
    required this.tabIndicator,
    required this.nav,
    required this.navBg,
    this.navBg2,
    required this.navFg,
    required this.navSel,
    required this.navSelBg,
    required this.fabBg,
    required this.fabFg,
  });

  bool get dark => brightness == Brightness.dark;
}

const kSkinAuto = 'auto';

const kSkins = <Skin>[
  Skin(
    id: 'midnight',
    name: 'Midnight',
    tagline: 'Default dark',
    brightness: Brightness.dark,
    accent: Color(0xFF2F80ED),
    bg: Color(0xFF000000),
    card: Color(0xFF161618),
    card2: Color(0xFF1C1C1F),
    card3: Color(0xFF242428),
    card4: Color(0xFF2C2C31),
    text: Color(0xFFF2F2F4),
    muted: Color(0xFF9A9AA2),
    outline: Color(0xFF2A2A2F),
    appBarBg: Color(0xFF000000),
    appBarFg: Color(0xFFF2F2F4),
    tabLabel: Color(0xFF2F80ED),
    tabUnselected: Color(0xFFF2F2F4),
    tabIndicator: Color(0xFF2F80ED),
    nav: NavKind.pill,
    navBg: Color(0xFF1E1E22),
    navFg: Color(0xFFF2F2F4),
    navSel: Color(0xFF2F80ED),
    navSelBg: Color(0xFF2A2A30),
    fabBg: Color(0xFF242428),
    fabFg: Color(0xFF34D399),
  ),
  Skin(
    id: 'daylight',
    name: 'Daylight',
    tagline: 'Clean light',
    brightness: Brightness.light,
    accent: Color(0xFF2F80ED),
    bg: Color(0xFFF2F3F7),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFF7F8FA),
    card3: Color(0xFFEDEFF3),
    card4: Color(0xFFE4E7EC),
    text: Color(0xFF111318),
    muted: Color(0xFF5F6470),
    outline: Color(0xFFE1E4EA),
    appBarBg: Color(0xFFF2F3F7),
    appBarFg: Color(0xFF111318),
    tabLabel: Color(0xFF2F80ED),
    tabUnselected: Color(0xFF111318),
    tabIndicator: Color(0xFF2F80ED),
    nav: NavKind.pill,
    navBg: Color(0xFFFFFFFF),
    navFg: Color(0xFF111318),
    navSel: Color(0xFF2F80ED),
    navSelBg: Color(0xFFEAF2FE),
    fabBg: Color(0xFFEDEFF3),
    fabFg: Color(0xFF2F80ED),
  ),
  Skin(
    id: 'cupertino',
    name: 'Cupertino',
    tagline: 'iOS-inspired',
    brightness: Brightness.light,
    accent: Color(0xFF007AFF),
    bg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFF2F2F7),
    card3: Color(0xFFE5E5EA),
    card4: Color(0xFFD1D1D6),
    text: Color(0xFF000000),
    muted: Color(0xFF8E8E93),
    outline: Color(0xFFD8D8DC),
    radius: 12,
    buttonRadius: 12,
    appBarBg: Color(0xFFF2F2F7),
    appBarFg: Color(0xFF000000),
    titleWeight: FontWeight.w600,
    tabLabel: Color(0xFF007AFF),
    tabUnselected: Color(0xFF8E8E93),
    tabIndicator: Color(0xFF007AFF),
    nav: NavKind.bar,
    navBg: Color(0xFFF9F9F9),
    navFg: Color(0xFF8E8E93),
    navSel: Color(0xFF007AFF),
    navSelBg: Color(0x00000000),
    fabBg: Color(0xFF007AFF),
    fabFg: Color(0xFFFFFFFF),
  ),
  Skin(
    id: 'cupertino_dark',
    name: 'Cupertino Dark',
    tagline: 'iOS-inspired dark',
    brightness: Brightness.dark,
    accent: Color(0xFF0A84FF),
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    card2: Color(0xFF2C2C2E),
    card3: Color(0xFF3A3A3C),
    card4: Color(0xFF48484A),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E93),
    outline: Color(0xFF38383A),
    radius: 12,
    buttonRadius: 12,
    appBarBg: Color(0xFF000000),
    appBarFg: Color(0xFFFFFFFF),
    titleWeight: FontWeight.w600,
    tabLabel: Color(0xFF0A84FF),
    tabUnselected: Color(0xFF8E8E93),
    tabIndicator: Color(0xFF0A84FF),
    nav: NavKind.bar,
    navBg: Color(0xFF161618),
    navFg: Color(0xFF8E8E93),
    navSel: Color(0xFF0A84FF),
    navSelBg: Color(0x00000000),
    fabBg: Color(0xFF0A84FF),
    fabFg: Color(0xFFFFFFFF),
  ),
  Skin(
    id: 'luna',
    name: 'Luna',
    tagline: 'Classic desktop, XP-era inspired',
    brightness: Brightness.light,
    accent: Color(0xFF245EDC),
    bg: Color(0xFFECE9D8),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFF7F6EE),
    card3: Color(0xFFE3E0CF),
    card4: Color(0xFFD6D2BD),
    text: Color(0xFF000000),
    muted: Color(0xFF5A5A5A),
    outline: Color(0xFFB9B5A1),
    radius: 6,
    buttonRadius: 4,
    cardBorder: Color(0xFF7F9DB9),
    cardShadow: true,
    appBarBg: Color(0xFF0054E3),
    appBarFg: Color(0xFFFFFFFF),
    centerTitle: false,
    titleWeight: FontWeight.w800,
    tabLabel: Color(0xFFFFFFFF),
    tabUnselected: Color(0xCCFFFFFF),
    tabIndicator: Color(0xFFF7A93B),
    nav: NavKind.taskbar,
    navBg: Color(0xFF3A81F3),
    navBg2: Color(0xFF1941A5),
    navFg: Color(0xFFFFFFFF),
    navSel: Color(0xFFFFFFFF),
    navSelBg: Color(0xFF1C3F94),
    fabBg: Color(0xFF3C9D3C),
    fabFg: Color(0xFFFFFFFF),
  ),
  Skin(
    id: 'metro',
    name: 'Metro',
    tagline: 'Flat tiles, Lumia-era inspired',
    brightness: Brightness.dark,
    accent: Color(0xFF1BA1E2),
    bg: Color(0xFF000000),
    card: Color(0xFF1F1F1F),
    card2: Color(0xFF262626),
    card3: Color(0xFF333333),
    card4: Color(0xFF404040),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFA0A0A0),
    outline: Color(0xFF333333),
    radius: 0,
    buttonRadius: 0,
    appBarBg: Color(0xFF000000),
    appBarFg: Color(0xFFFFFFFF),
    centerTitle: false,
    titleWeight: FontWeight.w300,
    titleSize: 26,
    tabLabel: Color(0xFF1BA1E2),
    tabUnselected: Color(0xFFA0A0A0),
    tabIndicator: Color(0xFF1BA1E2),
    nav: NavKind.metro,
    navBg: Color(0xFF111111),
    navFg: Color(0xFFA0A0A0),
    navSel: Color(0xFF1BA1E2),
    navSelBg: Color(0x00000000),
    fabBg: Color(0xFF1BA1E2),
    fabFg: Color(0xFFFFFFFF),
  ),
  Skin(
    id: 'metro_light',
    name: 'Metro Light',
    tagline: 'Flat tiles, light',
    brightness: Brightness.light,
    accent: Color(0xFFD80073),
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFF2F2F2),
    card2: Color(0xFFEAEAEA),
    card3: Color(0xFFDDDDDD),
    card4: Color(0xFFCCCCCC),
    text: Color(0xFF000000),
    muted: Color(0xFF6B6B6B),
    outline: Color(0xFFDDDDDD),
    radius: 0,
    buttonRadius: 0,
    appBarBg: Color(0xFFFFFFFF),
    appBarFg: Color(0xFF000000),
    centerTitle: false,
    titleWeight: FontWeight.w300,
    titleSize: 26,
    tabLabel: Color(0xFFD80073),
    tabUnselected: Color(0xFF6B6B6B),
    tabIndicator: Color(0xFFD80073),
    nav: NavKind.metro,
    navBg: Color(0xFFF2F2F2),
    navFg: Color(0xFF6B6B6B),
    navSel: Color(0xFFD80073),
    navSelBg: Color(0x00000000),
    fabBg: Color(0xFFD80073),
    fabFg: Color(0xFFFFFFFF),
  ),
];

Skin skinById(String id) =>
    kSkins.firstWhere((s) => s.id == id, orElse: () => kSkins.first);

/// Lets widgets read skin details (corner radius, borders, nav style).
class AppSkin extends ThemeExtension<AppSkin> {
  final Skin skin;
  const AppSkin(this.skin);

  @override
  AppSkin copyWith({Skin? skin}) => AppSkin(skin ?? this.skin);

  @override
  AppSkin lerp(ThemeExtension<AppSkin>? other, double t) =>
      t < 0.5 ? this : (other as AppSkin? ?? this);
}

extension SkinX on BuildContext {
  Skin get skin =>
      Theme.of(this).extension<AppSkin>()?.skin ?? kSkins.first;
}

ThemeData buildSkinTheme(Skin s) {
  final base = ColorScheme.fromSeed(seedColor: s.accent, brightness: s.brightness);
  final scheme = base.copyWith(
    primary: s.accent,
    onPrimary: Colors.white,
    primaryContainer: Color.alphaBlend(s.accent.withOpacity(s.dark ? 0.25 : 0.14), s.card),
    onPrimaryContainer: s.dark ? Colors.white : s.accent,
    surface: s.bg,
    surfaceContainerLow: s.card,
    surfaceContainer: s.card2,
    surfaceContainerHigh: s.card3,
    surfaceContainerHighest: s.card4,
    onSurface: s.text,
    onSurfaceVariant: s.muted,
    outlineVariant: s.outline,
  );
  final btnShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.buttonRadius));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: s.bg,
    canvasColor: s.bg,
    dividerColor: s.outline,
    extensions: [AppSkin(s)],
    appBarTheme: AppBarTheme(
      backgroundColor: s.appBarBg,
      foregroundColor: s.appBarFg,
      iconTheme: IconThemeData(color: s.appBarFg),
      actionsIconTheme: IconThemeData(color: s.appBarFg),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: s.centerTitle,
      titleTextStyle: TextStyle(
        fontSize: s.titleSize,
        fontWeight: s.titleWeight,
        color: s.appBarFg,
        letterSpacing: s.nav == NavKind.metro ? -0.5 : 0,
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: s.tabLabel,
      unselectedLabelColor: s.tabUnselected,
      indicatorColor: s.tabIndicator,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: s.nav == NavKind.taskbar ? Colors.transparent : s.outline,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(s.radius == 0 ? 0 : 14),
        borderSide: s.cardBorder == null
            ? BorderSide.none
            : BorderSide(color: s.cardBorder!),
      ),
      enabledBorder: s.cardBorder == null
          ? null
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: s.cardBorder!),
            ),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: btnShape)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: btnShape)),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: btnShape)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.buttonRadius)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.card2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(s.radius == 0 ? 0 : 20)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: s.card2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.radius == 0 ? 0 : 20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s.card2,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.card3,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.radius == 0 ? 0 : 10)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.fabBg,
      foregroundColor: s.fabFg,
      shape: s.nav == NavKind.metro
          ? const RoundedRectangleBorder()
          : s.nav == NavKind.taskbar
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              : const StadiumBorder(),
    ),
  );
}

/// Miniature preview of a skin, used in the theme picker.
class SkinPreview extends StatelessWidget {
  final Skin s;
  const SkinPreview(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = s.radius.clamp(0.0, 8.0);
    return Container(
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 18,
            color: s.appBarBg,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: s.centerTitle ? Alignment.center : Alignment.centerLeft,
            child: Container(width: 30, height: 4, color: s.appBarFg.withOpacity(0.8)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: s.card,
                          borderRadius: BorderRadius.circular(r),
                          border: s.cardBorder == null
                              ? null
                              : Border.all(color: s.cardBorder!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: i == 0 ? s.accent : s.muted,
                                borderRadius:
                                    BorderRadius.circular(s.radius == 0 ? 0 : 5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                  height: 3, color: s.text.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            height: 14,
            margin: s.nav == NavKind.pill
                ? const EdgeInsets.fromLTRB(8, 0, 8, 5)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: s.navBg2 == null ? s.navBg : null,
              gradient: s.navBg2 == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [s.navBg, s.navBg2!]),
              borderRadius: s.nav == NavKind.pill
                  ? BorderRadius.circular(7)
                  : BorderRadius.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == 0 ? s.navSel : s.navFg.withOpacity(0.6),
                      shape: s.nav == NavKind.metro
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
