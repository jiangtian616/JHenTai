import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/download/download_page.dart';
import 'package:jhentai/src/pages/history/history_page.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/search/simple/simple_search_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/pages/watched/watched_page.dart';
import 'package:jhentai/src/routes/routes.dart';

import '../../favorite/favorite_page.dart';
import '../../ranklist/ranklist_page.dart';

class DesktopLayoutPageState {
  late final List<LeftBarIcon> icons;
  late final List<ScrollController?> scrollControllers;
  late final List<bool> isFocused;

  int selectedTabIndex = 0;
  int? hoverTabIndex;

  final FocusScopeNode leftTabBarFocusScopeNode = FocusScopeNode();
  final FocusScopeNode leftColumnFocusScopeNode = FocusScopeNode();
  final FocusScopeNode rightColumnFocusScopeNode = FocusScopeNode();

  /// record tap time to implement 'double tap to refresh'
  DateTime? lastTapTime;

  DesktopLayoutPageState() {
    icons = [
      LeftBarIcon(
        name: 'home',
        routeName: Routes.gallerys,
        selectedIcon: const Icon(Icons.home),
        unselectedIcon: const Icon(Icons.home_outlined),
        page: () => const GallerysPage(),
      ),
      LeftBarIcon(
        name: 'search',
        routeName: Routes.simpleSearch,
        selectedIcon: const Icon(Icons.search, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.search),
        page: () => const SimpleSearchPage(),
      ),
      LeftBarIcon(
        name: 'popular',
        routeName: Routes.popular,
        selectedIcon: const Icon(Icons.whatshot),
        unselectedIcon: const Icon(Icons.whatshot_outlined),
        page: () => const PopularPage(),
      ),
      LeftBarIcon(
        name: 'ranklist',
        routeName: Routes.ranklist,
        selectedIcon: const Icon(Icons.bar_chart_rounded, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.bar_chart_outlined),
        page: () => const RanklistPage(),
      ),
      LeftBarIcon(
        name: 'favorite',
        routeName: Routes.favorite,
        selectedIcon: const Icon(Icons.favorite),
        unselectedIcon: const Icon(Icons.favorite_outline),
        page: () => const FavoritePage(),
      ),
      LeftBarIcon(
        name: 'watched',
        routeName: Routes.watched,
        selectedIcon: const Icon(Icons.visibility),
        unselectedIcon: const Icon(Icons.visibility_outlined),
        page: () => const WatchedPage(),
      ),
      LeftBarIcon(
        name: 'history',
        routeName: Routes.history,
        selectedIcon: const Icon(Icons.history, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.history_outlined),
        page: () => const HistoryPage(),
      ),
      LeftBarIcon(
        name: 'download',
        routeName: Routes.download,
        selectedIcon: const Icon(Icons.download),
        unselectedIcon: const Icon(Icons.download_outlined),
        page: () => const DownloadPage(),
      ),
      LeftBarIcon(
        name: 'setting',
        routeName: Routes.setting,
        selectedIcon: const Icon(Icons.settings),
        unselectedIcon: const Icon(Icons.settings_outlined),
        page: () => const SettingPage(),
      ),
    ];

    scrollControllers = List.filled(icons.length, null);
    isFocused = List.filled(icons.length, false);
  }
}

class LeftBarIcon {
  final String name;
  final String routeName;
  final Icon selectedIcon;
  final Icon unselectedIcon;
  final ValueGetter<Widget> page;

  LeftBarIcon({
    required this.name,
    required this.routeName,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.page,
  });
}
