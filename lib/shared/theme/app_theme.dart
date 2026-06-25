import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF6366F1); // indigo-500
  static const _background = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF111111);
  static const _card = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _muted = Color(0xFF71717A);
  static const _foreground = Color(0xFFF4F4F5);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          surface: _surface,
          onSurface: _foreground,
          outline: _border,
          onSurfaceVariant: _muted,
        ),
        scaffoldBackgroundColor: _background,
        cardColor: _card,
        dividerColor: _border,
        fontFamily: 'SF Pro Display', // falls back to system font
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _foreground),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _foreground),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _foreground),
          bodyMedium: TextStyle(fontSize: 14, color: _foreground),
          bodySmall: TextStyle(fontSize: 12, color: _muted),
          labelSmall: TextStyle(fontSize: 11, color: _muted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintStyle: const TextStyle(color: _muted, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _foreground,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          textColor: _foreground,
          iconColor: _muted,
        ),
      );
}
