import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF0E0D12);
  static const surface = Color(0xFF17161C);
  static const surfaceHigh = Color(0xFF1E1E26);
  static const border = Color(0xFF2B2A34);
  static const primary = Color(0xFF7554F5);

  /// Purple for text, light enough to read on every dark surface.
  static const link = Color(0xFFA996FF);
  static const primarySoft = Color(0xFF1A162D);
  static const gold = Color(0xFFFFC53D);
  static const green = Color(0xFF3DD68C);
  static const danger = Color(0xFFFF6B6B);

  /// The check after a verified channel's name.
  static const verified = Color(0xFF3B9DFF);
  static const text = Color(0xFFF4F3F7);
  static const muted = Color(0xFF9A98A6);
}

class AppTheme {
  const AppTheme._();

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.background,
          error: AppColors.danger,
        ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      indicatorShape: const StadiumBorder(),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.link
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.link
              : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
}
