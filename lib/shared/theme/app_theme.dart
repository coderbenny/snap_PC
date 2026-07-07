import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Light palette ─────────────────────────────────────────────────────────
  static const _lBackground = Color(0xFFFAFAFA);
  static const _lSurface    = Color(0xFFFFFFFF);
  static const _lCard       = Color(0xFFF4F4F5);
  static const _lBorder     = Color(0xFFE4E4E7);
  static const _lMuted      = Color(0xFF71717A);
  static const _lForeground = Color(0xFF09090B);
  static const _lPrimary    = Color(0xFF09090B); // near-black on white

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const _dBackground = Color(0xFF0A0A0A);
  static const _dSurface    = Color(0xFF111111);
  static const _dCard       = Color(0xFF1A1A1A);
  static const _dBorder     = Color(0xFF2A2A2A);
  static const _dMuted      = Color(0xFF71717A);
  static const _dForeground = Color(0xFFF4F4F5);
  static const _dPrimary    = Color(0xFFF4F4F5); // near-white on black

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: _lPrimary,
          onPrimary: _lSurface,
          surface: _lSurface,
          onSurface: _lForeground,
          outline: _lBorder,
          onSurfaceVariant: _lMuted,
        ),
        scaffoldBackgroundColor: _lBackground,
        cardColor: _lCard,
        dividerColor: _lBorder,
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          titleLarge:  TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _lForeground),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _lForeground),
          titleSmall:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _lForeground),
          bodyMedium:  TextStyle(fontSize: 14, color: _lForeground),
          bodySmall:   TextStyle(fontSize: 12, color: _lMuted),
          labelSmall:  TextStyle(fontSize: 11, color: _lMuted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _lBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _lBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _lPrimary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintStyle: const TextStyle(color: _lMuted, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _lPrimary,
            foregroundColor: _lSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _lPrimary,
            foregroundColor: _lSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _lForeground,
            side: const BorderSide(color: _lBorder),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          textColor: _lForeground,
          iconColor: _lMuted,
        ),
      );

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _dPrimary,
          onPrimary: _dBackground,
          surface: _dSurface,
          onSurface: _dForeground,
          outline: _dBorder,
          onSurfaceVariant: _dMuted,
        ),
        scaffoldBackgroundColor: _dBackground,
        cardColor: _dCard,
        dividerColor: _dBorder,
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          titleLarge:  TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _dForeground),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _dForeground),
          titleSmall:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dForeground),
          bodyMedium:  TextStyle(fontSize: 14, color: _dForeground),
          bodySmall:   TextStyle(fontSize: 12, color: _dMuted),
          labelSmall:  TextStyle(fontSize: 11, color: _dMuted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _dCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _dBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _dBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _dPrimary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintStyle: const TextStyle(color: _dMuted, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _dPrimary,
            foregroundColor: _dBackground,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _dPrimary,
            foregroundColor: _dBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _dForeground,
            side: const BorderSide(color: _dBorder),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          textColor: _dForeground,
          iconColor: _dMuted,
        ),
      );
}
