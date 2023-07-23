import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/history/history_page.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/pages/watched/watched_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../../../mixin/double_tap_to_refresh_state_mixin.dart';
import '../../../model/tab_bar_icon.dart';
import '../../favorite/favorite_page.dart';
import '../../favorite/favorite_page_logic.dart';
import '../../history/history_page_logic.dart';
import '../../popular/popular_page_logic.dart';
import '../../ranklist/ranklist_page.dart';
import '../../ranklist/ranklist_page_logic.dart';
import '../../search/desktop/desktop_search_page.dart';
import '../../search/desktop/desktop_search_page_logic.dart';
import '../../watched/watched_page_logic.dart';

class DesktopLayoutPageState with DoubleTapToRefreshStateMixin {
  late final List<TabBarIcon> icons;

  int selectedTabIndex = 0;

  /// selectedTabIndex in [shouldRender] icons
  int get selectedTabOrder => icons.where((icon) => icon.shouldRender).toList().indexWhere((icon) => icon.name == icons[selectedTabIndex].name);
  int? hoveringTabIndex;

  final ScrollController leftTabBarScrollController = ScrollController();

  DesktopLayoutPageState() {
    icons = [
      TabBarIcon(
        name: TabBarIconNameEnum.home,
        routeName: Routes.gallerys,
        selectedIcon: const Icon(Icons.home),
        unselectedIcon: const Icon(Icons.home_outlined),
        page: () => const GallerysPage(),
        scrollController: () => Get.find<GallerysPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.search,
        routeName: Routes.desktopSearch,
        selectedIcon: const Icon(Icons.search, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.search),
        page: () => const DesktopSearchPage(),
        scrollController: () =>
            Get.find<DesktopSearchPageLogic>().state.tabLogics[Get.find<DesktopSearchPageLogic>().state.currentTabIndex].state.scrollController,
        shouldRender: true,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.popular,
        routeName: Routes.popular,
        selectedIcon: const Icon(Icons.whatshot),
        unselectedIcon: const Icon(Icons.whatshot_outlined),
        page: () => const PopularPage(),
        scrollController: () => Get.find<PopularPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.ranklist,
        routeName: Routes.ranklist,
        selectedIcon: const Icon(Icons.bar_chart_rounded, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.bar_chart_outlined),
        page: () => const RanklistPage(),
        scrollController: () => Get.find<RanklistPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.favorite,
        routeName: Routes.favorite,
        selectedIcon: const Icon(Icons.favorite),
        unselectedIcon: const Icon(Icons.favorite_outline),
        page: () => const FavoritePage(),
        scrollController: () => Get.find<FavoritePageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.watched,
        routeName: Routes.watched,
        selectedIcon: const Icon(Icons.visibility),
        unselectedIcon: const Icon(Icons.visibility_outlined),
        page: () => const WatchedPage(),
        scrollController: () => Get.find<WatchedPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.history,
        routeName: Routes.history,
        selectedIcon: const Icon(Icons.history, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: const Icon(Icons.history_outlined),
        page: () => HistoryPage(),
        scrollController: () => Get.find<HistoryPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.download,
        routeName: Routes.download,
        selectedIcon: const Icon(Icons.download),
        unselectedIcon: const Icon(Icons.download_outlined),
        page: () => const DownloadPage(),
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.setting,
        routeName: Routes.setting,
        selectedIcon: const Icon(Icons.settings),
        unselectedIcon: const Icon(Icons.settings_outlined),
        page: () => const SettingPage(),
        shouldRender: true,
      ),
    ];
    
    selectedTabIndex = icons.firstIndexWhereOrNull((icon) => icon.name == PreferenceSetting.defaultTab.value) ?? 0;
    icons[selectedTabIndex].shouldRender = true;
  }
}