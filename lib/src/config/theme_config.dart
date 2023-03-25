import 'package:flutter/material.dart';

class ThemeConfig {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    popupMenuTheme: const PopupMenuThemeData(surfaceTintColor: Colors.transparent),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    popupMenuTheme: const PopupMenuThemeData(surfaceTintColor: Colors.transparent),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0BCFF),
      brightness: Brightness.dark,
    ),
  );
}
