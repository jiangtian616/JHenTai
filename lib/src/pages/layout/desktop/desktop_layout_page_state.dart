import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/download/download_view.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_view.dart';
import 'package:jhentai/src/pages/search/search_page.dart';
import 'package:jhentai/src/pages/setting/setting_view.dart';

class DesktopLayoutPageState {
  late final List<LeftBarIcon> icons;

  int selectedTabIndex = 0;
  int? hoverTabIndex;

  DesktopLayoutPageState() {
    icons = [
      LeftBarIcon(
        name: 'home',
        selectedIcon: const Icon(Icons.home),
        unselectedIcon: const Icon(Icons.home_outlined),
        page: const GallerysPage(key: Key('1')),
      ),
      LeftBarIcon(
        name: 'search',
        selectedIcon: const Icon(Icons.search, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.search),
        page: SearchPage(),
      ),
      LeftBarIcon(
        name: 'popular',
        selectedIcon: const Icon(Icons.whatshot),
        unselectedIcon: const Icon(Icons.whatshot_outlined),
        page: const PopularPage( key:  Key('3')),
      ),
      LeftBarIcon(
        name: 'ranklist',
        selectedIcon: const Icon(Icons.bar_chart_rounded, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.bar_chart_outlined),
        page: RanklistPage(),
      ),
      LeftBarIcon(
        name: 'favorite',
        selectedIcon: const Icon(Icons.favorite),
        unselectedIcon: const Icon(Icons.favorite_outline),
        page: GallerysPage(),
      ),
      LeftBarIcon(
        name: 'watched',
        selectedIcon: const Icon(Icons.visibility),
        unselectedIcon: const Icon(Icons.visibility_outlined),
        page: GallerysPage(),
      ),
      LeftBarIcon(
        name: 'history',
        selectedIcon: const Icon(Icons.history, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.history_outlined),
        page: GallerysPage(),
      ),
      LeftBarIcon(
        name: 'download',
        selectedIcon: const Icon(Icons.download),
        unselectedIcon: const Icon(Icons.download_outlined),
        page: DownloadPage(),
      ),
      LeftBarIcon(
        name: 'setting',
        selectedIcon: const Icon(Icons.settings),
        unselectedIcon: const Icon(Icons.settings_outlined),
        page: SettingPage(),
      ),
    ];
  }
}

class LeftBarIcon {
  final String name;
  final Icon selectedIcon;
  final Icon unselectedIcon;
  final Widget page;

  LeftBarIcon({
    required this.name,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.page,
  });
}
