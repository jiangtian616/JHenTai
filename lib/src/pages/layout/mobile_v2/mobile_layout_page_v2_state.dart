import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2.dart';

import '../../../model/tab_bar_icon.dart';
import '../../../routes/routes.dart';
import '../../download/download_base_page.dart';
import '../../favorite/favorite_page.dart';
import '../../gallerys/dashboard/dashboard_page.dart';
import '../../history/history_page.dart';
import '../../popular/popular_page.dart';
import '../../ranklist/ranklist_page.dart';
import '../../setting/setting_page.dart';
import '../../watched/watched_page.dart';

class MobileLayoutPageV2State {
  late final List<TabBarIcon> icons;

  int selectedDrawerTabIndex = 0;
  int selectedNavigationIndex = 0;

  /// selectedNavigationIndex's order in [shouldRender] tabs
  int get selectedDrawerTabOrder =>
      icons.where((icon) => icon.shouldRender).toList().indexWhere((icon) => icon.name == icons[selectedDrawerTabIndex].name);

  static GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  MobileLayoutPageV2State() {
    icons = [
      TabBarIcon(
        name: 'home',
        routeName: Routes.dashboard,
        selectedIcon: const Icon(Icons.home),
        unselectedIcon: const Icon(Icons.home_outlined),
        page: () => const DashboardPage(),
        shouldRender: true,
      ),
      TabBarIcon(
        name: 'search',
        routeName: Routes.mobileV2Search,
        selectedIcon: const Icon(Icons.search, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.search),
        page: () => SearchPageMobileV2(),
        shouldRender: false,
        enterNewRoute: true,
      ),
      TabBarIcon(
        name: 'popular',
        routeName: Routes.popular,
        selectedIcon: const Icon(Icons.whatshot),
        unselectedIcon: const Icon(Icons.whatshot_outlined),
        page: () => PopularPage(showMenuButton: true, showTitle: true, name: 'popular'.tr),
        shouldRender: false,
      ),
      TabBarIcon(
        name: 'ranklist',
        routeName: Routes.ranklist,
        selectedIcon: const Icon(Icons.bar_chart_rounded, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.bar_chart_outlined),
        page: () => const RanklistPage(showMenuButton: true, showTitle: true),
        shouldRender: false,
      ),
      TabBarIcon(
        name: 'favorite',
        routeName: Routes.favorite,
        selectedIcon: const Icon(Icons.favorite),
        unselectedIcon: const Icon(Icons.favorite_outline),
        page: () => FavoritePage(showMenuButton: true, showTitle: true, name: 'favorite'.tr),
        shouldRender: false,
      ),
      TabBarIcon(
        name: 'watched',
        routeName: Routes.watched,
        selectedIcon: const Icon(Icons.visibility),
        unselectedIcon: const Icon(Icons.visibility_outlined),
        page: () => WatchedPage(showMenuButton: true, showTitle: true, name: 'watched'.tr),
        shouldRender: false,
      ),
      TabBarIcon(
        name: 'history',
        routeName: Routes.history,
        selectedIcon: const Icon(Icons.history, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.history_outlined),
        page: () => HistoryPage(showMenuButton: true, showTitle: true, name: 'history'.tr),
        shouldRender: false,
      ),
    ];
  }
}
