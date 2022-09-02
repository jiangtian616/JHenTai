import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_utils/src/platform/platform.dart';

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
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
      iconTheme: IconThemeData(color: Colors.grey.shade800),
      actionsIconTheme: IconThemeData(color: Colors.grey.shade900),
      elevation: 0,
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.pink.shade300, width: 3))),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(scaffoldBackgroundColor: Colors.white),
    dialogTheme: const DialogTheme(
      titleTextStyle: TextStyle(
        fontSize: 16,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(elevation: MaterialStateProperty.all(0))),
    cardColor: Colors.white,
    hoverColor: Colors.transparent,
    fontFamily: GetPlatform.isWindows ? '新宋体' : null,
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color.fromARGB(255, 0, 122, 255),
    primaryColorLight: Colors.pink.shade300,
    backgroundColor: Colors.grey.shade900,
    appBarTheme: AppBarTheme(
      foregroundColor: Colors.grey.shade100,
      backgroundColor: Colors.grey.shade900,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: Colors.pink.shade300,
      labelStyle: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
      unselectedLabelColor: Colors.grey.shade600,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.pink.shade300, width: 3))),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(scaffoldBackgroundColor: Colors.grey.shade900),
    dialogTheme: const DialogTheme(
      titleTextStyle: TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(elevation: MaterialStateProperty.all(0))),
    cardColor: Colors.grey.shade900,
    hoverColor: Colors.transparent,
    fontFamily: GetPlatform.isWindows ? '新宋体' : null,
  );
}
