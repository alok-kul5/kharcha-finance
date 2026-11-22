import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;

/// Colour tokens that change with light / dark mode. Read them with
/// `context.k`. Light is iOS-style grouped neutrals (grey page, white
/// surfaces, no borders); dark is a deep navy-black with raised greys.
@immutable
class KColors extends ThemeExtension<KColors> {
  const KColors({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.fill,
    required this.brandSoft,
    required this.positive,
    required this.caution,
    required this.negative,
  });

  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color fill;
  final Color brandSoft;
  final Color positive;
  final Color caution;
  final Color negative;

  static const light = KColors(
    page: Color(0xfff2f2f7),
    surface: Colors.white,
    surfaceRaised: Colors.white,
    ink: Color(0xff0b0b0f),
    secondaryLabel: Color(0xff4b4b51),
    tertiaryLabel: Color(0xff86868c),
    separator: Color(0xffe5e5ea),
    fill: Color(0xffececf1),
    brandSoft: Color(0xffeceefe),
    positive: Color(0xff248a3d),
    caution: Color(0xffc93400),
    negative: Color(0xffd70015),
  );

  static const dark = KColors(
    page: Color(0xff05070f),
    surface: Color(0xff12141d),
    surfaceRaised: Color(0xff1b1e2a),
    ink: Color(0xfff5f5f7),
    secondaryLabel: Color(0xffbcbcc4),
    tertiaryLabel: Color(0xff80808a),
    separator: Color(0xff262938),
    fill: Color(0xff222532),
    brandSoft: Color(0xff1d2350),
    positive: Color(0xff30d158),
    caution: Color(0xffff9f0a),
    negative: Color(0xffff6961),
  );

  @override
  KColors copyWith() => this;

  @override
  KColors lerp(KColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KColors(
      page: l(page, other.page),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      ink: l(ink, other.ink),
      secondaryLabel: l(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: l(tertiaryLabel, other.tertiaryLabel),
      separator: l(separator, other.separator),
      fill: l(fill, other.fill),
      brandSoft: l(brandSoft, other.brandSoft),
      positive: l(positive, other.positive),
      caution: l(caution, other.caution),
      negative: l(negative, other.negative),
    );
  }
}

extension KContext on BuildContext {
  KColors get k => Theme.of(this).extension<KColors>() ?? KColors.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Brand and hero colours: the same in both modes.
abstract final class Brand {
  static const blue = Color(0xff2f6bff);
  static const violet = Color(0xff7b3ff2);
  static const mid = Color(0xff3d5cf5);

  static const heroTop = Color(0xff050f33);
  static const heroMid = Color(0xff0b2a7a);
  static const heroBottom = Color(0xff2e6fdc);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, violet],
  );

  /// A coloured glow under brand-filled controls.
  static List<BoxShadow> glow([int alpha = 70]) => [
        BoxShadow(color: mid.withAlpha(alpha), blurRadius: 18, offset: const Offset(0, 8)),
      ];
}

abstract final class Radii {
  static const control = 12.0;
  static const card = 20.0;
  static const hero = 28.0;
  static const sheet = 28.0;
}

/// Motion tokens: calm and quick. Things arrive on [signature] and leave on
/// [exit]; Under reduced motion every
/// movement becomes a short fade.
abstract final class Motion {
  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 240);
  static const sheet = Duration(milliseconds: 320);
  static const page = Duration(milliseconds: 420);
  static const count = Duration(milliseconds: 650);
  static const reveal = Duration(milliseconds: 900);
  static const ambient = Duration(seconds: 14);
  static const reducedFade = Duration(milliseconds: 120);
  static const staggerRow = Duration(milliseconds: 30);
  static const staggerMax = 6;

  static const signature = Cubic(0.22, 1, 0.36, 1);
  static const exit = Cubic(0.3, 0, 1, 1);
  static const loop = Curves.easeInOutSine;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

  static Duration of(BuildContext context, Duration full) => reduced(context) ? reducedFade : full;
}

abstract final class KText {
  /// Display face: Gloock, a high-contrast serif for screen titles and big amounts.
  static const display = 'Gloock';

  static TextStyle largeTitle(BuildContext c) => TextStyle(
      fontFamily: display,
      fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: -0.6, height: 1.1, color: c.k.ink);

  static TextStyle title(BuildContext c) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.k.ink);

  static TextStyle headline(BuildContext c) =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.3, color: c.k.ink);

  static TextStyle body(BuildContext c) => TextStyle(fontSize: 15, height: 1.4, color: c.k.ink);

  /// Money: tabular figures so digits don't jiggle while counting.
  /// Big amounts (28 and up) use the serif display face.
  static TextStyle amount(BuildContext c, {double size = 17, Color? color}) => TextStyle(
        fontFamily: size >= 28 ? display : null,
        fontSize: size,
        fontWeight: size >= 28 ? FontWeight.w400 : FontWeight.w600,
        letterSpacing: size > 28 ? -1.6 : -0.2,
        height: 1.1,
        color: color ?? c.k.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle caption(BuildContext c) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.k.secondaryLabel);
}

ThemeData buildTheme(Brightness brightness) {
  final k = brightness == Brightness.dark ? KColors.dark : KColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: Brand.mid,
    onPrimary: Colors.white,
    primaryContainer: k.brandSoft,
    onPrimaryContainer: brightness == Brightness.dark ? const Color(0xffb9c4ff) : const Color(0xff2459e0),
    secondary: Brand.violet,
    onSecondary: Colors.white,
    error: k.negative,
    onError: Colors.white,
    surface: k.surface,
    onSurface: k.ink,
    onSurfaceVariant: k.secondaryLabel,
    surfaceContainerLowest: k.surface,
    surfaceContainerLow: k.page,
    surfaceContainer: k.surfaceRaised,
    surfaceContainerHigh: k.surfaceRaised,
    surfaceContainerHighest: k.surfaceRaised,
    outline: k.separator,
    outlineVariant: k.separator,
    surfaceTint: Colors.transparent,
  );
  final field = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none);
  return ThemeData(
    fontFamily: 'Onest',
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: k.page,
    canvasColor: k.page,
    dividerColor: k.separator,
    splashFactory: NoSplash.splashFactory,
    highlightColor: k.ink.withAlpha(10),
    extensions: [k],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    }),
    iconTheme: IconThemeData(size: 20, color: k.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark ? k.surfaceRaised : k.page,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(color: k.tertiaryLabel),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: const BorderSide(color: Brand.mid, width: 1.5)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: k.page,
      foregroundColor: k.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: k.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: k.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: k.tertiaryLabel,
      dragHandleSize: const Size(36, 5),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? k.surfaceRaised : const Color(0xff1c1c22),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      actionTextColor: const Color(0xff9dbcff),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: k.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: k.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Brand.mid,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: k.separator)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control))),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? const Color(0xff34c759) : k.separator),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.mid),
    listTileTheme: ListTileThemeData(
      iconColor: k.secondaryLabel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
    ),
  );
}

/// iOS-style scrolling everywhere: rubber-band overscroll, no glow.
class KScrollBehavior extends MaterialScrollBehavior {
  const KScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
