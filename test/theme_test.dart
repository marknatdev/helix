import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helix_command_center/theme/app_theme.dart';

/// WCAG relative luminance, used to sanity-check that the light palette's
/// text actually reads against its own grounds.
double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : (((v + 0.055) / 1.055) * ((v + 0.055) / 1.055));
  // Approximate gamma expansion is fine here — we only compare ratios
  // against a coarse threshold, not produce exact WCAG figures.
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => AppColors.apply(light: false));

  group('Dark palette is unchanged', () {
    // These are the exact values the app shipped with before the theme
    // switch existed. Making the tokens mutable is only safe if dark mode
    // still renders identically — this pins that.
    test('every token matches the original hard-coded value', () {
      AppColors.apply(light: false);
      expect(AppColors.background, const Color(0xFF121418));
      expect(AppColors.foreground, const Color(0xFFFAFAFA));
      expect(AppColors.card, const Color(0xFF191C21));
      expect(AppColors.popover, const Color(0xFF15181D));
      expect(AppColors.sidebar, const Color(0xFF0F1115));
      expect(AppColors.border, const Color(0xFF2A2E36));
      expect(AppColors.muted, const Color(0xFF1E2127));
      expect(AppColors.mutedFg, const Color(0xFFA0A4AC));
      expect(AppColors.accent, const Color(0xFF242830));
      expect(AppColors.primary, const Color(0xFFFFB547));
      expect(AppColors.primaryFg, const Color(0xFF15181D));
      expect(AppColors.statusOk, const Color(0xFF35D39A));
      expect(AppColors.statusWarn, const Color(0xFFFFB547));
      expect(AppColors.statusSos, const Color(0xFFF04438));
      expect(AppColors.statusOffline, const Color(0xFF7A7F88));
      expect(AppColors.isLight, isFalse);
    });

    test('survives a round trip through the light palette', () {
      AppColors.apply(light: false);
      final before = [
        AppColors.background,
        AppColors.foreground,
        AppColors.card,
        AppColors.border,
        AppColors.mutedFg,
        AppColors.primary,
      ];
      AppColors.apply(light: true);
      AppColors.apply(light: false);
      expect([
        AppColors.background,
        AppColors.foreground,
        AppColors.card,
        AppColors.border,
        AppColors.mutedFg,
        AppColors.primary,
      ], before);
    });
  });

  group('Light palette', () {
    test('apply() swaps every token and flips isLight', () {
      AppColors.apply(light: false);
      final dark = AppColors.background;
      AppColors.apply(light: true);
      expect(AppColors.isLight, isTrue);
      expect(AppColors.background, isNot(dark));
      // Light ground, dark ink — the inversion actually happened.
      expect(_luminance(AppColors.background),
          greaterThan(_luminance(AppColors.foreground)));
    });

    test('body and muted text stay readable on their grounds', () {
      AppColors.apply(light: true);
      // 4.5:1 is the WCAG AA threshold for normal-size text.
      expect(_contrast(AppColors.foreground, AppColors.background),
          greaterThan(4.5));
      expect(_contrast(AppColors.mutedFg, AppColors.background),
          greaterThan(4.5));
      expect(_contrast(AppColors.mutedFg, AppColors.card), greaterThan(4.5));
    });

    test('amber primary is darkened enough to read on white', () {
      AppColors.apply(light: true);
      // The dark theme's 0xFFFFB547 amber is ~1.9:1 on white — unusable as
      // text. The light palette must not reuse it.
      expect(AppColors.primary, isNot(const Color(0xFFFFB547)));
      expect(_contrast(AppColors.primary, AppColors.card), greaterThan(4.5));
      expect(_contrast(AppColors.statusWarn, AppColors.card), greaterThan(4.5));
    });

    test('status colours keep their identity and stay legible', () {
      AppColors.apply(light: true);
      for (final c in [
        AppColors.statusOk,
        AppColors.statusSos,
        AppColors.statusWarn,
      ]) {
        expect(_contrast(c, AppColors.card), greaterThan(4.5),
            reason: 'status colour $c unreadable on light card');
        expect(_contrast(c, AppColors.background), greaterThan(4.5),
            reason: 'status colour $c unreadable on light background');
      }
    });
  });

  group('buildAppTheme', () {
    test('brightness and scaffold colour follow the flag', () {
      AppColors.apply(light: false);
      final dark = buildAppTheme(light: false);
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF121418));

      AppColors.apply(light: true);
      final light = buildAppTheme(light: true);
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, AppColors.background);
      expect(light.colorScheme.brightness, Brightness.light);
    });

    test('defaults to dark when no flag is passed', () {
      AppColors.apply(light: false);
      expect(buildAppTheme().brightness, Brightness.dark);
    });
  });
}
