import 'package:flutter/material.dart';

/// The two HELIX palettes. Dark is the original mission-control / industrial
/// look (near-black bg, off-white fg, amber primary); light is a
/// high-contrast daylight variant for outdoor/jobsite readability — the
/// chrome inverts but the semantic status hues keep their meaning, only
/// darkened enough to stay legible on a white ground.
class _Palette {
  final Color background,
      foreground,
      card,
      popover,
      sidebar,
      border,
      muted,
      mutedFg,
      accent,
      primary,
      primaryFg,
      statusOk,
      statusWarn,
      statusSos,
      statusOffline;

  const _Palette({
    required this.background,
    required this.foreground,
    required this.card,
    required this.popover,
    required this.sidebar,
    required this.border,
    required this.muted,
    required this.mutedFg,
    required this.accent,
    required this.primary,
    required this.primaryFg,
    required this.statusOk,
    required this.statusWarn,
    required this.statusSos,
    required this.statusOffline,
  });
}

const _dark = _Palette(
  background: Color(0xFF121418),
  foreground: Color(0xFFFAFAFA),
  card: Color(0xFF191C21),
  popover: Color(0xFF15181D),
  sidebar: Color(0xFF0F1115),
  border: Color(0xFF2A2E36),
  muted: Color(0xFF1E2127),
  mutedFg: Color(0xFFA0A4AC),
  accent: Color(0xFF242830),
  primary: Color(0xFFFFB547), // amber
  primaryFg: Color(0xFF15181D),
  statusOk: Color(0xFF35D39A),
  statusWarn: Color(0xFFFFB547),
  statusSos: Color(0xFFF04438),
  statusOffline: Color(0xFF7A7F88),
);

/// Amber-on-white fails contrast (0xFFFFB547 is ~1.9:1 on white), so
/// `primary`/`statusWarn` darken to bronze here rather than reusing the dark
/// theme's value. Same reasoning for the emerald/red status hues: same
/// colour identity, enough luminance drop to read as text and small icons.
/// Every foreground token below clears WCAG AA (4.5:1) against `card`,
/// `background` and `sidebar` — see test/theme_test.dart, which pins it.
const _light = _Palette(
  background: Color(0xFFF4F6F8),
  foreground: Color(0xFF15181D),
  card: Color(0xFFFFFFFF),
  popover: Color(0xFFFFFFFF),
  sidebar: Color(0xFFEBEEF2),
  border: Color(0xFFD2D7DE),
  muted: Color(0xFFE7EAEF),
  mutedFg: Color(0xFF4C5462),
  accent: Color(0xFFE1E5EB),
  primary: Color(0xFF8A5300), // bronze — amber darkened for white grounds
  primaryFg: Color(0xFFFFFFFF),
  statusOk: Color(0xFF066945),
  statusWarn: Color(0xFF8A5300),
  statusSos: Color(0xFFC8231A),
  statusOffline: Color(0xFF5A6170),
);

/// Live palette tokens.
///
/// These are deliberately mutable statics rather than `const`: every widget
/// in the app reads `AppColors.x` directly at build time, so swapping the
/// values here plus a full rebuild (see `themeModeProvider` /
/// `HelixApp`) re-themes the whole tree without touching ~400 call sites.
/// The trade-off is that no `AppColors` reference can live inside a `const`
/// expression — the analyzer enforces that for us.
class AppColors {
  static Color background = _dark.background;
  static Color foreground = _dark.foreground;
  static Color card = _dark.card;
  static Color popover = _dark.popover;
  static Color sidebar = _dark.sidebar;
  static Color border = _dark.border;
  static Color muted = _dark.muted;
  static Color mutedFg = _dark.mutedFg;
  static Color accent = _dark.accent;

  static Color primary = _dark.primary;
  static Color primaryFg = _dark.primaryFg;

  static Color statusOk = _dark.statusOk;
  static Color statusWarn = _dark.statusWarn;
  static Color statusSos = _dark.statusSos;
  static Color statusOffline = _dark.statusOffline;

  /// True while the light palette is applied. Widgets that need to branch on
  /// more than a colour (e.g. FleetMap's tile inversion filter) read this.
  static bool isLight = false;

  /// Swap every token to the requested palette. Must be called before the
  /// rebuild that reads them — `HelixApp.build` does exactly that.
  static void apply({required bool light}) {
    final p = light ? _light : _dark;
    isLight = light;
    background = p.background;
    foreground = p.foreground;
    card = p.card;
    popover = p.popover;
    sidebar = p.sidebar;
    border = p.border;
    muted = p.muted;
    mutedFg = p.mutedFg;
    accent = p.accent;
    primary = p.primary;
    primaryFg = p.primaryFg;
    statusOk = p.statusOk;
    statusWarn = p.statusWarn;
    statusSos = p.statusSos;
    statusOffline = p.statusOffline;
  }
}

ThemeData buildAppTheme({bool light = false}) {
  final base = light
      ? ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.primaryFg,
          secondary: AppColors.accent,
          onSecondary: AppColors.foreground,
          surface: AppColors.card,
          onSurface: AppColors.foreground,
          error: AppColors.statusSos,
          onError: const Color(0xFFFFFFFF),
        )
      : ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.primaryFg,
          secondary: AppColors.accent,
          onSecondary: AppColors.foreground,
          surface: AppColors.card,
          onSurface: AppColors.foreground,
          error: AppColors.statusSos,
          onError: AppColors.foreground,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    fontFamily: 'Roboto',
    dividerColor: AppColors.border,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: AppColors.foreground),
      bodySmall: TextStyle(color: AppColors.mutedFg),
    ),
    iconTheme: IconThemeData(color: AppColors.mutedFg, size: 16),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.popover,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
      textStyle: TextStyle(color: AppColors.foreground, fontSize: 11),
    ),
  );
}
