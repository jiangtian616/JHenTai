import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeConfig {
  /// Since Flutter 3.35, Material buttons default to the basic arrow cursor on desktop; restore the hand cursor.
  static const WidgetStatePropertyAll<MouseCursor> clickableMouseCursor = WidgetStatePropertyAll(WidgetStateMouseCursor.clickable);

  /// Apple platforms (iOS / macOS) get the native Apple look; everything else keeps Material 3.
  static bool get isApple => GetPlatform.isIOS || GetPlatform.isMacOS;

  static ThemeData theme(Color color, Brightness brightness) {
    if (isApple) {
      return _buildAppleTheme(brightness);
    }
    return _buildMaterialTheme(color, brightness);
  }

  static ThemeData _buildMaterialTheme(Color color, Brightness brightness) {
    ThemeData themeData = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: color,

      /// default w500 is not supported for chinese characters in some devices
      textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
      appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(
        height: 48,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      popupMenuTheme: const PopupMenuThemeData(surfaceTintColor: Colors.transparent),
      textButtonTheme: const TextButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      elevatedButtonTheme: const ElevatedButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      outlinedButtonTheme: const OutlinedButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      listTileTheme: const ListTileThemeData(mouseCursor: clickableMouseCursor),
      switchTheme: const SwitchThemeData(mouseCursor: clickableMouseCursor),
      checkboxTheme: const CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: const RadioThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: const SliderThemeData(mouseCursor: clickableMouseCursor),
      tabBarTheme: const TabBarThemeData(mouseCursor: clickableMouseCursor),
    );

    return themeData.copyWith(
      appBarTheme: themeData.appBarTheme.copyWith(backgroundColor: themeData.colorScheme.surface),
      dialogTheme: DialogThemeData(backgroundColor: themeData.colorScheme.surface),
    );
  }

  /// macOS / iOS look: neutral gray surfaces, fixed SF accent, native controls.
  static ThemeData _buildAppleTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color accent = isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF); // SF Blue
    final Color window = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F7); // macOS window / iOS grouped bg
    final Color onSurface = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F); // primary label
    final Color secondary = isDark ? const Color(0xFF98989D) : const Color(0xFF6E6E73); // secondary label
    final Color separator = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD2D2D7); // separators
    final Color error = isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30); // systemRed

    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withValues(alpha: 0.2),
      onPrimaryContainer: onSurface,
      secondaryContainer: accent.withValues(alpha: 0.12),
      onSecondaryContainer: onSurface,
      surface: window,
      onSurface: onSurface,
      onSurfaceVariant: secondary,
      surfaceContainerHighest: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE5E5EA),
      outline: separator,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: GetPlatform.isMacOS ? TargetPlatform.macOS : TargetPlatform.iOS,
      textTheme: const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
      appBarTheme: AppBarTheme(
        backgroundColor: window,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 48,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      popupMenuTheme: PopupMenuThemeData(surfaceTintColor: Colors.transparent, color: window),
      dialogTheme: DialogThemeData(backgroundColor: window, surfaceTintColor: Colors.transparent),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: accent.withValues(alpha: 0.2),
        cursorColor: accent,
        selectionHandleColor: accent,
      ),
      dividerTheme: DividerThemeData(color: separator),
      textButtonTheme: const TextButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      elevatedButtonTheme: const ElevatedButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      outlinedButtonTheme: const OutlinedButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      iconButtonTheme: const IconButtonThemeData(style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      listTileTheme: const ListTileThemeData(mouseCursor: clickableMouseCursor),
      switchTheme: const SwitchThemeData(mouseCursor: clickableMouseCursor),
      checkboxTheme: const CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: const RadioThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: const SliderThemeData(mouseCursor: clickableMouseCursor),
      tabBarTheme: const TabBarThemeData(mouseCursor: clickableMouseCursor),
    );
  }
}
