import 'package:flutter/material.dart';

/// Mission-control / industrial safety palette mirroring the original
/// HELIX web app (near-black bg, off-white fg, amber primary, emerald OK,
/// red SOS).
class AppColors {
  static const background = Color(0xFF121418);
  static const foreground = Color(0xFFFAFAFA);
  static const card = Color(0xFF191C21);
  static const popover = Color(0xFF15181D);
  static const sidebar = Color(0xFF0F1115);
  static const border = Color(0xFF2A2E36);
  static const muted = Color(0xFF1E2127);
  static const mutedFg = Color(0xFFA0A4AC);
  static const accent = Color(0xFF242830);

  static const primary = Color(0xFFFFB547); // amber
  static const primaryFg = Color(0xFF15181D);

  static const statusOk = Color(0xFF35D39A);
  static const statusWarn = Color(0xFFFFB547);
  static const statusSos = Color(0xFFF04438);
  static const statusOffline = Color(0xFF7A7F88);
}

ThemeData buildAppTheme() {
  const base = ColorScheme.dark(
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
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    fontFamily: 'Roboto',
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.foreground),
      bodySmall: TextStyle(color: AppColors.mutedFg),
    ),
    iconTheme: const IconThemeData(color: AppColors.mutedFg, size: 16),
    tooltipTheme: const TooltipThemeData(
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
