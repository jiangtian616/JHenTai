import 'package:flutter/material.dart';

class ThemeConfig {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    colorScheme: ColorScheme.light(
      primary: Color(0xFF6750A4),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFEADDFF),
      onPrimaryContainer: Color(0xFF21005D),
      secondary: Color(0xFF625B71),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Colors.grey.shade200,
      onSecondaryContainer: Color(0xFF1D192B),
      tertiary: Color(0xFF7D5260),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFD8E4),
      onTertiaryContainer: Color(0xFF31111D),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      background: Color(0xFFFFFBFE),
      onBackground: Color(0xFF1C1B1F),
      surface: Color(0xFFFFFBFE),
      onSurface: Color(0xFF1C1B1F),
      outline: Color(0xFF79747E),
      surfaceVariant: Color(0xFFE7E0EC),
      onSurfaceVariant: Color(0xFF49454F),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      indicatorColor: Color(0xFFEADDFF),
      surfaceTintColor: Color(0xFFE7E0EC),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    scaffoldBackgroundColor: Color(0xFFFFFBFE),

    /// for mobile layout v1
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.pink.shade300, width: 3))),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    cardTheme: CardTheme(
      color: Colors.grey.shade900,
    ),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFFD0BCFF),
      onPrimary: Color(0xFF381E72),
      primaryContainer: Color(0xFF4F378B),
      onPrimaryContainer: Color(0xFFEADDFF),
      secondary: Color(0xFFCCC2DC),
      onSecondary: Color(0xFF332D41),
      secondaryContainer: Colors.grey.shade800,
      onSecondaryContainer: Colors.grey.shade300,
      tertiary: Color(0xFFEFB8C8),
      onTertiary: Color(0xFF492532),
      tertiaryContainer: Color(0xFF633B48),
      onTertiaryContainer: Color(0xFFFFD8E4),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF8C1D18),
      onErrorContainer: Color(0xFFF2B8B5),
      background: Color(0xFF1C1B1F),
      onBackground: Color(0xFFE6E1E5),
      surface: Color(0xFF1C1B1F),
      onSurface: Color(0xFFE6E1E5),
      outline: Color(0xFF938F99),
      surfaceVariant: Color(0xFF232123),
      onSurfaceVariant: Color(0xFFCAC4D0),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      indicatorColor: Color(0xFF4F378B),
      surfaceTintColor: Color(0xFF49454F),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    scaffoldBackgroundColor: Color(0xFF1C1B1F),

    /// for mobile layout v1
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.pink.shade300, width: 3))),
    ),
  );
}
