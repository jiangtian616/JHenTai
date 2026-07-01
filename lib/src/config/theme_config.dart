import 'package:flutter/material.dart';

class ThemeConfig {
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
    );

    return themeData.copyWith(
      appBarTheme: themeData.appBarTheme.copyWith(backgroundColor: themeData.colorScheme.surface),
      dialogTheme: DialogThemeData(backgroundColor: themeData.colorScheme.surface),
    );
  }
}
