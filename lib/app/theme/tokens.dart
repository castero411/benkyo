import 'package:flutter/material.dart';

/// Design tokens from the Phase 0 design. Single source for the app's look;
/// future appearance presets are alternative sets of these values.
abstract final class Tokens {
  // Color
  static const ground = Color(0xFF141223);
  static const glass = Color(0xFF161424);
  static const Color text = Colors.white;
  static const textSecondary = Color(0xBFFFFFFF); // 75% white
  static const inkOnAccent = Color(0xFF1B1530);
  static const accent = Color(0xFFF2B36B);
  static const success = Color(0xFF8FD3C1);
  static const toast = Color(0xFFFAF8F5);
  static const p1 = Color(0xFFFF8A6B);
  static const p2 = Color(0xFFF2B36B);
  static const p3 = Color(0xFF7FB5FF);
  static const p4 = Color(0xFFB4B0C4);

  // Glass
  static const glassOpacity = 0.52;
  static const glassOpacityStrong = 0.72;
  static const glassBlur = 28.0;
  static const glassBorder = Color(0x1FFFFFFF); // 12% white

  // Radius
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r14 = 14.0;
  static const r22 = 22.0;
  static const r28 = 28.0;

  // Spacing (4-pt scale)
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  // Motion
  static const fast = Duration(milliseconds: 200);
  static const panel = Duration(milliseconds: 300);
  static const sceneFade = Duration(milliseconds: 600);
  static const Curve curve = Curves.easeOutCubic;

  /// [d], or zero when macOS "Reduce motion" is on.
  static Duration motion(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.accent,
    brightness: Brightness.dark,
    primary: Tokens.accent,
    onPrimary: Tokens.inkOnAccent,
    surface: Tokens.ground,
  );
  // No fontFamily: on macOS Flutter already uses the system font (SF Pro).
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.ground,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 112,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: -2,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12, color: Tokens.textSecondary),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: Tokens.toast,
      contentTextStyle: const TextStyle(
        color: Tokens.inkOnAccent,
        fontSize: 14,
      ),
      actionTextColor: Tokens.inkOnAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.r14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
