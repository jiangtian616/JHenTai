import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeConfig {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    appBarTheme: GetPlatform.isDesktop ? const AppBarTheme(scrolledUnderElevation: 0) : null,
    scaffoldBackgroundColor: const Color(0xFFFFFBFE),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      indicatorColor: Color(0xFFEADDFF),
      surfaceTintColor: Color(0xFFE7E0EC),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.black54),
    dividerTheme: DividerThemeData(color: Colors.grey.shade200),
    dialogTheme: const DialogTheme(surfaceTintColor: Colors.transparent),
    popupMenuTheme: const PopupMenuThemeData(surfaceTintColor: Colors.transparent),
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF6750A4),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFEADDFF),
      onPrimaryContainer: const Color(0xFF21005D),
      secondary: const Color(0xFF625B71),
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: Colors.grey.shade200,
      onSecondaryContainer: const Color(0xFF1D192B),
      tertiary: const Color(0xFF7D5260),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFFFD8E4),
      onTertiaryContainer: const Color(0xFF31111D),
      error: const Color(0xFFB3261E),
      onError: const Color(0xFFFFFFFF),
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      background: const Color(0xFFFFFBFE),
      onBackground: const Color(0xFF1C1B1F),
      surface: const Color(0xFFFFFBFE),
      onSurface: const Color(0xFF1C1B1F),
      outline: const Color(0xFF79747E),
      surfaceVariant: const Color(0xFFE7E0EC),
      onSurfaceVariant: const Color(0xFF49454F),
    ),

    /// for mobile layout v1
    primaryColorLight: Colors.pink.shade300,
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    /// default w500 is not supported for chinese characters in some devices
    textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
    appBarTheme: GetPlatform.isDesktop ? const AppBarTheme(scrolledUnderElevation: 0) : null,
    scaffoldBackgroundColor: const Color(0xFF1C1B1F),
    navigationBarTheme: const NavigationBarThemeData(
      height: 48,
      indicatorColor: Color(0xFF4F378B),
      surfaceTintColor: Color(0xFF49454F),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    cardTheme: CardTheme(color: Colors.grey.shade900),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    dividerTheme: DividerThemeData(color: Colors.grey.shade800),
    dialogTheme: const DialogTheme(surfaceTintColor: Colors.transparent, backgroundColor: Color(0xFF333232)),
    popupMenuTheme: const PopupMenuThemeData(surfaceTintColor: Colors.transparent, color: Color(0xFF333232)),
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFD0BCFF),
      onPrimary: const Color(0xFF381E72),
      primaryContainer: const Color(0xFF4F378B),
      onPrimaryContainer: const Color(0xFFEADDFF),
      secondary: const Color(0xFFCCC2DC),
      onSecondary: const Color(0xFF332D41),
      secondaryContainer: Colors.grey.shade800,
      onSecondaryContainer: Colors.grey.shade300,
      tertiary: const Color(0xFFEFB8C8),
      onTertiary: const Color(0xFF492532),
      tertiaryContainer: const Color(0xFF633B48),
      onTertiaryContainer: const Color(0xFFFFD8E4),
      error: const Color(0xFFF2B8B5),
      onError: const Color(0xFF601410),
      errorContainer: const Color(0xFF8C1D18),
      onErrorContainer: const Color(0xFFF2B8B5),
      background: const Color(0xFF1C1B1F),
      onBackground: const Color(0xFFE6E1E5),
      surface: const Color(0xFF1C1B1F),
      onSurface: const Color(0xFFE6E1E5),
      outline: const Color(0xFF938F99),
      surfaceVariant: const Color(0xFF232123),
      onSurfaceVariant: const Color(0xFFCAC4D0),
    ),

    /// for mobile layout v1
    primaryColorLight: Colors.pink.shade300,
  );
}
