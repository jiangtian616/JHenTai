import 'package:flutter/material.dart';

class ThemeConfig {
  /// Since Flutter 3.35, Material buttons default to the basic arrow cursor on desktop; restore the hand cursor.
  static const WidgetStatePropertyAll<MouseCursor> clickableMouseCursor = WidgetStatePropertyAll(WidgetStateMouseCursor.clickable);

  static ThemeData theme(Color color, Brightness brightness) {
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
}
