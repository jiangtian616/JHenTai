import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeConfig {
  /// The Apple visual overhaul is opt-in, even on Apple platforms.
  static bool appleVisualStyleEnabled = false;

  /// Since Flutter 3.35, Material buttons default to the basic arrow cursor on desktop; restore the hand cursor.
  static const WidgetStatePropertyAll<MouseCursor> clickableMouseCursor =
      WidgetStatePropertyAll(WidgetStateMouseCursor.clickable);

  static bool get isApplePlatform => GetPlatform.isIOS || GetPlatform.isMacOS;

  /// iOS/macOS only, and only after the user enables it in Style settings.
  static bool get isApple => isApplePlatform && appleVisualStyleEnabled;

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
      textTheme:
          const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
      appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(
        height: 48,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      popupMenuTheme:
          const PopupMenuThemeData(surfaceTintColor: Colors.transparent),
      textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      elevatedButtonTheme: const ElevatedButtonThemeData(
          style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      listTileTheme: const ListTileThemeData(mouseCursor: clickableMouseCursor),
      switchTheme: const SwitchThemeData(mouseCursor: clickableMouseCursor),
      checkboxTheme: const CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: const RadioThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: const SliderThemeData(mouseCursor: clickableMouseCursor),
      tabBarTheme: const TabBarThemeData(mouseCursor: clickableMouseCursor),
    );

    return themeData.copyWith(
      appBarTheme: themeData.appBarTheme
          .copyWith(backgroundColor: themeData.colorScheme.surface),
      dialogTheme:
          DialogThemeData(backgroundColor: themeData.colorScheme.surface),
    );
  }

  /// macOS / iOS look: neutral gray surfaces with a monochrome accent.
  /// The user's regular accent is preserved for Material mode and restored
  /// automatically when the Apple visual style is turned off.
  static ThemeData _buildAppleTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color appleAccent = isDark ? Colors.white : Colors.black;

    final Color window = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF5F5F7); // macOS window / iOS grouped bg
    final Color onSurface = isDark
        ? const Color(0xFFF5F5F7)
        : const Color(0xFF1D1D1F); // primary label
    final Color secondary = isDark
        ? const Color(0xFF98989D)
        : const Color(0xFF6E6E73); // secondary label
    final Color separator = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFD2D2D7); // separators
    final Color error =
        isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30); // systemRed
    final BorderRadius controlRadius = BorderRadius.circular(7);
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: BorderSide(color: separator.withValues(alpha: 0.85)),
    );

    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: appleAccent, brightness: brightness)
            .copyWith(
      primary: appleAccent,
      onPrimary: isDark ? Colors.black : Colors.white,
      primaryContainer: appleAccent.withValues(alpha: 0.2),
      onPrimaryContainer: onSurface,
      secondaryContainer: appleAccent.withValues(alpha: 0.12),
      onSecondaryContainer: onSurface,
      surface: window,
      onSurface: onSurface,
      onSurfaceVariant: secondary,
      surfaceContainerHighest:
          isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE5E5EA),
      outline: separator,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: GetPlatform.isMacOS ? TargetPlatform.macOS : TargetPlatform.iOS,
      textTheme:
          const TextTheme(titleMedium: TextStyle(fontWeight: FontWeight.w400)),
      appBarTheme: AppBarTheme(
        backgroundColor: window,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 48,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 48,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: window,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: appleAccent, width: 1.5)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: appleAccent.withValues(alpha: 0.2),
        cursorColor: appleAccent,
        selectionHandleColor: appleAccent,
      ),
      dividerTheme: DividerThemeData(color: separator),
      textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(mouseCursor: clickableMouseCursor)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: controlRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: controlRadius)),
          side: WidgetStatePropertyAll(BorderSide(color: separator)),
        ),
      ),
      // Desktop tool icons live inside other MouseRegions (sidebar rows and
      // action groups). Keep one stable macOS cursor/overlay state so they do
      // not continually hand cursor ownership back and forth.
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.basic),
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: const ListTileThemeData(mouseCursor: clickableMouseCursor),
      switchTheme: const SwitchThemeData(mouseCursor: clickableMouseCursor),
      checkboxTheme: const CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: const RadioThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: const SliderThemeData(mouseCursor: clickableMouseCursor),
      tabBarTheme: const TabBarThemeData(mouseCursor: clickableMouseCursor),
    );
  }
}
