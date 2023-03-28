import 'package:flutter/material.dart';
import 'package:material_color_utilities/palettes/core_palette.dart';
import 'package:material_color_utilities/scheme/scheme.dart';

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
  );

  static ThemeData generateThemeData(Color color, Brightness brightness) {
    final colorScheme = generateColorScheme(color, brightness);
    return brightness == Brightness.light
        ? light.copyWith(
            colorScheme: colorScheme,
            scaffoldBackgroundColor: colorScheme.background,
            listTileTheme: ListTileThemeData(iconColor: colorScheme.onBackground),

            /// for DropdownButton
            canvasColor: colorScheme.background,
          )
        : dark.copyWith(
            colorScheme: colorScheme,
            scaffoldBackgroundColor: colorScheme.background,
            listTileTheme: ListTileThemeData(iconColor: colorScheme.onBackground),

            /// for DropdownButton
            canvasColor: colorScheme.background,
          );
  }

  static ColorScheme generateColorScheme(Color seedColor, Brightness brightness) {
    Scheme scheme;
    if (brightness == Brightness.light) {
      scheme = Scheme.lightFromCorePalette(CorePalette.contentOf(seedColor.value));
    } else {
      scheme = Scheme.darkFromCorePalette(CorePalette.contentOf(seedColor.value));
    }

    return ColorScheme(
      brightness: brightness,
      primary: Color(scheme.primary),
      onPrimary: Color(scheme.onPrimary),
      primaryContainer: Color(scheme.primaryContainer),
      onPrimaryContainer: Color(scheme.onPrimaryContainer),
      secondary: Color(scheme.secondary),
      onSecondary: Color(scheme.onSecondary),
      secondaryContainer: Color(scheme.secondaryContainer),
      onSecondaryContainer: Color(scheme.onSecondaryContainer),
      tertiary: Color(scheme.tertiary),
      onTertiary: Color(scheme.onTertiary),
      tertiaryContainer: Color(scheme.tertiaryContainer),
      onTertiaryContainer: Color(scheme.onTertiaryContainer),
      error: Color(scheme.error),
      onError: Color(scheme.onError),
      errorContainer: Color(scheme.errorContainer),
      onErrorContainer: Color(scheme.onErrorContainer),
      outline: Color(scheme.outline),
      outlineVariant: Color(scheme.outlineVariant),
      background: Color(scheme.background),
      onBackground: Color(scheme.onBackground),
      surface: Color(scheme.surface),
      onSurface: Color(scheme.onSurface),
      surfaceVariant: Color(scheme.surfaceVariant),
      onSurfaceVariant: Color(scheme.onSurfaceVariant),
      inverseSurface: Color(scheme.inverseSurface),
      onInverseSurface: Color(scheme.inverseOnSurface),
      inversePrimary: Color(scheme.inversePrimary),
      shadow: Color(scheme.shadow),
      scrim: Color(scheme.scrim),
      surfaceTint: Color(scheme.primary),
    );
  }
}
