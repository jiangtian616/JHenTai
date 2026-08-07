import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';

/// Chrome icons: SF Symbols (`CupertinoIcons`) while the Apple visual style is
/// enabled, Material icons otherwise. `xxxFill` is the selected/filled variant,
/// `xxx` the unselected/outline variant.
class AppIcons {
  static bool get isApple => ThemeConfig.isApple;

  static IconData get home =>
      isApple ? CupertinoIcons.house : Icons.home_outlined;
  static IconData get homeFill =>
      isApple ? CupertinoIcons.house_fill : Icons.home;
  static IconData get search => isApple ? CupertinoIcons.search : Icons.search;
  static IconData get popular =>
      isApple ? CupertinoIcons.flame : Icons.whatshot_outlined;
  static IconData get popularFill =>
      isApple ? CupertinoIcons.flame_fill : Icons.whatshot;
  static IconData get ranklist =>
      isApple ? CupertinoIcons.chart_bar : Icons.bar_chart_outlined;
  static IconData get ranklistFill =>
      isApple ? CupertinoIcons.chart_bar_fill : Icons.bar_chart_rounded;
  static IconData get favorite =>
      isApple ? CupertinoIcons.heart : Icons.favorite_outline;
  static IconData get favoriteFill =>
      isApple ? CupertinoIcons.heart_fill : Icons.favorite;
  static IconData get watched =>
      isApple ? CupertinoIcons.eye : Icons.visibility_outlined;
  static IconData get watchedFill =>
      isApple ? CupertinoIcons.eye_fill : Icons.visibility;
  static IconData get history =>
      isApple ? CupertinoIcons.clock : Icons.history_outlined;
  static IconData get historyFill =>
      isApple ? CupertinoIcons.clock_fill : Icons.history;
  static IconData get download =>
      isApple ? CupertinoIcons.square_arrow_down : Icons.download_outlined;
  static IconData get downloadFill =>
      isApple ? CupertinoIcons.square_arrow_down_fill : Icons.download;
  static IconData get settings =>
      isApple ? CupertinoIcons.gear : Icons.settings_outlined;
  static IconData get settingsFill =>
      isApple ? CupertinoIcons.gear_solid : Icons.settings;
  static IconData get menu => isApple ? CupertinoIcons.bars : Icons.menu;
  static IconData get jump => isApple ? CupertinoIcons.paperplane : Icons.send;
  static IconData get filter => isApple
      ? CupertinoIcons.line_horizontal_3_decrease
      : Icons.filter_alt_outlined;
  static IconData get chevronRight =>
      isApple ? CupertinoIcons.chevron_right : Icons.keyboard_arrow_right;
}
