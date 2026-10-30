import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE5484D),
      brightness: Brightness.dark,
    ),
  );
}
