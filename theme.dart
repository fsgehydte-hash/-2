import 'package:flutter/material.dart';

class Brand {
  static const green = Color(0xFF1B5E20);
  static const lightGreen = Color(0xFF66BB6A);
  static const ivory = Color(0xFFFAF8F1);
  static const expense = Color(0xFFE65100);
  static const ink = Color(0xFF37474F);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.green,
    brightness: brightness,
    primary: dark ? Brand.lightGreen : Brand.green,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? null : Brand.ivory,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? null : Brand.green,
      foregroundColor: dark ? null : Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
