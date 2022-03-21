import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jhentai/src/config/global_config.dart';

class ThemeConfig {
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color.fromARGB(255, 0, 122, 255),
    primaryColorLight: Colors.pink.shade300,
    backgroundColor: Colors.grey.shade100,
    appBarTheme: AppBarTheme(
      foregroundColor: Colors.grey.shade900,
      backgroundColor: Colors.white,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      iconTheme: IconThemeData(
        color: Colors.grey.shade800,
      ),
      actionsIconTheme: IconThemeData(
        color: Colors.grey.shade900,
      ),
      elevation: 0,
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.pink.shade300,
            width: 3,
          ),
        ),
      ),
    ),
    cardColor: Colors.white,
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    appBarTheme: AppBarTheme(
      foregroundColor: Colors.grey.shade100,
      backgroundColor: Colors.grey.shade900,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      actionsIconTheme: const IconThemeData(
        color: Colors.white,
      ),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.pink.shade300,
            width: 3,
          ),
        ),
      ),
    ),
    cardColor: Colors.grey.shade900,
  );
}
