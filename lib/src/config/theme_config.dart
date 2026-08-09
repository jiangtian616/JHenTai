import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeConfig {
  /// The Apple visual overhaul is opt-in on every platform.
  static bool appleVisualStyleEnabled = false;

  /// Since Flutter 3.35, Material buttons default to the basic arrow cursor on desktop; restore the hand cursor.
  static const WidgetStatePropertyAll<MouseCursor> clickableMouseCursor =
      WidgetStatePropertyAll(WidgetStateMouseCursor.clickable);

  static bool get isApplePlatform => GetPlatform.isIOS || GetPlatform.isMacOS;

  /// Apple visual style takes effect after the user enables it in Style
  /// settings, on every platform.
  static bool get isApple => appleVisualStyleEnabled;

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
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontWeight: FontWeight.w400),
      ),
      appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(
        height: 48,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableMouseCursor),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableMouseCursor),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableMouseCursor),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(mouseCursor: clickableMouseCursor),
      ),
      listTileTheme: const ListTileThemeData(mouseCursor: clickableMouseCursor),
      switchTheme: const SwitchThemeData(mouseCursor: clickableMouseCursor),
      checkboxTheme: const CheckboxThemeData(mouseCursor: clickableMouseCursor),
      radioTheme: const RadioThemeData(mouseCursor: clickableMouseCursor),
      sliderTheme: const SliderThemeData(mouseCursor: clickableMouseCursor),
      tabBarTheme: const TabBarThemeData(mouseCursor: clickableMouseCursor),
    );

    return themeData.copyWith(
      appBarTheme: themeData.appBarTheme.copyWith(
        backgroundColor: themeData.colorScheme.surface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: themeData.colorScheme.surface,
      ),
    );
  }

  /// macOS / iOS look: neutral gray surfaces with a monochrome accent.
  /// The user's regular accent is preserved for Material mode and restored
  /// automatically when the Apple visual style is turned off.
  static ThemeData _buildAppleTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color appleAccent = isDark ? Colors.white : Colors.black;

    final Color window =
        isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF5F5F7); // macOS window / iOS grouped bg
    final Color onSurface =
        isDark
            ? const Color(0xFFF5F5F7)
            : const Color(0xFF1D1D1F); // primary label
    final Color secondary =
        isDark
            ? const Color(0xFF98989D)
            : const Color(0xFF6E6E73); // secondary label
    final Color separator =
        isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFD2D2D7); // separators
    final Color error =
        isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30); // systemRed
    // Keep Apple mode monochrome, but make controls read as layered liquid
    // glass rather than flat Material buttons.  The two surfaces deliberately
    // swap in dark mode: a black primary button and pale glass secondary
    // buttons in light mode, and the inverse in dark mode.
    final BorderRadius controlRadius = BorderRadius.circular(14);
    final Color glassSurface =
        isDark
            ? const Color(0xFF090909).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.76);
    final Color glassBorder =
        isDark
            ? Colors.white.withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.92);
    final Color glassShadow = Colors.black.withValues(
      alpha: isDark ? 0.34 : 0.14,
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: BorderSide(color: separator.withValues(alpha: 0.85)),
    );

    // fromSeed() with a neutral black/white seed does NOT produce a grayscale
    // scheme: it derives pink/magenta tones for the roles not overridden below
    // (secondary, tertiary, tertiaryContainer, …). That leaked as pink sidebars
    // and pink translation UI on iOS. Override every tinted role with gray so
    // the Apple style is truly monochrome on all platforms.
    final Color tertiaryColor =
        isDark ? const Color(0xFF9E9EA4) : const Color(0xFF6B6B70);
    final Color tertiaryContainer =
        isDark ? const Color(0xFF333336) : const Color(0xFFEDEDF0);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: appleAccent,
      brightness: brightness,
    ).copyWith(
      primary: appleAccent,
      onPrimary: isDark ? Colors.black : Colors.white,
      primaryContainer: appleAccent.withValues(alpha: 0.2),
      onPrimaryContainer: onSurface,
      secondary: secondary,
      onSecondary: onSurface,
      secondaryContainer: appleAccent.withValues(alpha: 0.12),
      onSecondaryContainer: onSurface,
      tertiary: tertiaryColor,
      onTertiary: onSurface,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onSurface,
      inversePrimary: appleAccent,
      inverseSurface:
          isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F),
      onInverseSurface: onSurface,
      surface: window,
      onSurface: onSurface,
      onSurfaceVariant: secondary,
      surfaceContainerHighest:
          isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE5E5EA),
      outline: separator,
      surfaceTint: Colors.transparent,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      platform: GetPlatform.isMacOS ? TargetPlatform.macOS : TargetPlatform.iOS,
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontWeight: FontWeight.w400),
      ),
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
        // Translucent glass panel for the imperative context menus
        // (showEHContextMenu / showMenu) that can't be rebuilt as GlassMenu
        // widgets — download/favorite item actions, history, tag sets, etc.
        color: window.withValues(alpha: isDark ? 0.88 : 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.60),
            width: 0.8,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        // Translucent panel + hairline edge so the rich form dialogs read as
        // frosted glass even though they keep the AlertDialog structure (they
        // carry custom content GlassDialog can't hold).
        backgroundColor: window.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.60),
            width: 0.8,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: appleAccent, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: appleAccent.withValues(alpha: 0.2),
        cursorColor: appleAccent,
        selectionHandleColor: appleAccent,
      ),
      // Make every Cupertino widget render in the app's monochrome accent
      // instead of the default iOS system-blue: buttons, switches, sliders,
      // segmented controls, text-field cursors, list-tile tints. This is also
      // what lets CupertinoButton (used by the EHApple* wrappers) stay black in
      // light mode / white in dark mode.
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: appleAccent,
        primaryContrastingColor: isDark ? Colors.black : Colors.white,
        barBackgroundColor: window,
        scaffoldBackgroundColor: window,
      ).noDefault(),
      dividerTheme: DividerThemeData(color: separator),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled)
                    ? secondary.withValues(alpha: 0.45)
                    : onSurface,
          ),
          overlayColor: WidgetStatePropertyAll(
            appleAccent.withValues(alpha: isDark ? 0.14 : 0.09),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return appleAccent.withValues(alpha: 0.28);
            }
            return appleAccent;
          }),
          foregroundColor: WidgetStatePropertyAll(
            isDark ? Colors.black : Colors.white,
          ),
          overlayColor: WidgetStatePropertyAll(
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.14),
          ),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 1 : 5,
          ),
          shadowColor: WidgetStatePropertyAll(glassShadow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return appleAccent.withValues(alpha: 0.28);
            }
            return appleAccent;
          }),
          foregroundColor: WidgetStatePropertyAll(
            isDark ? Colors.black : Colors.white,
          ),
          overlayColor: WidgetStatePropertyAll(
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.14),
          ),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 1 : 5,
          ),
          shadowColor: WidgetStatePropertyAll(glassShadow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: clickableMouseCursor,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return glassSurface.withValues(alpha: 0.28);
            }
            return glassSurface;
          }),
          foregroundColor: WidgetStatePropertyAll(onSurface),
          overlayColor: WidgetStatePropertyAll(
            appleAccent.withValues(alpha: isDark ? 0.16 : 0.08),
          ),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 0 : 3,
          ),
          shadowColor: WidgetStatePropertyAll(glassShadow),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: glassBorder)),
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
