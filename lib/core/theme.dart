import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Palette shared with the web version.
class C {
  static const bg = Color(0xFF0E1016);
  static const surface = Color(0xFF161923);
  static const surface2 = Color(0xFF1D2130);
  static const line = Color(0xFF2A2F40);
  static const fg = Color(0xFFE9EAF2);
  static const muted = Color(0xFF8A8FA6);
  static const faint = Color(0xFF5A5F74);
  static const accent = Color(0xFF9AA5FF);
  static const accentInk = Color(0xFF11142A);
  static const deadline = Color(0xFFFF9466);
  static const overdue = Color(0xFFFF5F7E);
  static const workout = Color(0xFF4FD6C4);
  static const workoutInk = Color(0xFF06221E);
}

ThemeData buildTheme() {
  final radius10 = BorderRadius.circular(10);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.accentInk,
      secondary: C.workout,
      onSecondary: C.workoutInk,
      surface: C.surface,
      onSurface: C.fg,
      error: C.overdue,
    ),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.fg, displayColor: C.fg),
    dividerColor: C.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: C.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: const TextStyle(color: C.muted),
      floatingLabelStyle: const TextStyle(color: C.accent),
      hintStyle: const TextStyle(color: C.faint),
      border: OutlineInputBorder(borderRadius: radius10, borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius10, borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius10, borderSide: const BorderSide(color: C.accent)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.accentInk,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.fg,
        side: const BorderSide(color: C.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: radius10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.accent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: C.faint, width: 1.5),
    ),
    dialogTheme: const DialogTheme(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    popupMenuTheme: const PopupMenuThemeData(color: C.surface2, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.surface2,
      contentTextStyle: TextStyle(color: C.fg),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

const tabular = [FontFeature.tabularFigures()];
