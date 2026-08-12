import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/gallery/simple/gallery_page_logic.dart';
import 'package:jhentai/src/pages/history/history_page.dart';
import 'package:jhentai/src/pages/gallery/simple/gallery_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/pages/watched/watched_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/app_icons.dart';
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
  int get selectedTabOrder => icons
      .where((icon) => icon.shouldRender)
      .toList()
      .indexWhere((icon) => icon.name == icons[selectedTabIndex].name);
  int? hoveringTabIndex;

  final ScrollController leftTabBarScrollController = ScrollController();

  DesktopLayoutPageState() {
    icons = [
      TabBarIcon(
        name: TabBarIconNameEnum.home,
        routeName: Routes.gallery,
        selectedIcon: Icon(AppIcons.homeFill),
        unselectedIcon: Icon(AppIcons.home),
        page: () => const GalleryPage(),
        scrollController: () =>
            Get.find<GalleryPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.search,
        routeName: Routes.desktopSearch,
        selectedIcon: Icon(AppIcons.search, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: Icon(AppIcons.search),
        page: () => const DesktopSearchPage(),
        scrollController: () => Get.find<DesktopSearchPageLogic>()
            .state
            .tabLogics[Get.find<DesktopSearchPageLogic>().state.currentTabIndex]
            .state
            .scrollController,
        shouldRender: true,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.popular,
        routeName: Routes.popular,
        selectedIcon: Icon(AppIcons.popularFill),
        unselectedIcon: Icon(AppIcons.popular),
        page: () => ThemeConfig.isApple
            ? PopularPage(showTitle: true, name: 'popular'.tr)
            : const PopularPage(),
        scrollController: () =>
            Get.find<PopularPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.ranklist,
        routeName: Routes.ranklist,
        selectedIcon:
            Icon(AppIcons.ranklistFill, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: Icon(AppIcons.ranklist),
        page: () => const RanklistPage(),
        scrollController: () =>
            Get.find<RanklistPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.favorite,
        routeName: Routes.favorite,
        selectedIcon: Icon(AppIcons.favoriteFill),
        unselectedIcon: Icon(AppIcons.favorite),
        page: () => ThemeConfig.isApple
            ? FavoritePage(showTitle: true, name: 'favorite'.tr)
            : const FavoritePage(),
        scrollController: () =>
            Get.find<FavoritePageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.watched,
        routeName: Routes.watched,
        selectedIcon: Icon(AppIcons.watchedFill),
        unselectedIcon: Icon(AppIcons.watched),
        page: () => const WatchedPage(),
        scrollController: () =>
            Get.find<WatchedPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.history,
        routeName: Routes.history,
        selectedIcon:
            Icon(AppIcons.historyFill, shadows: [Shadow(blurRadius: 2)]),
        unselectedIcon: Icon(AppIcons.history),
        page: () => ThemeConfig.isApple
            ? HistoryPage(showTitle: true, name: 'history'.tr)
            : HistoryPage(),
        scrollController: () =>
            Get.find<HistoryPageLogic>().state.scrollController,
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.download,
        routeName: Routes.download,
        selectedIcon: Icon(AppIcons.downloadFill),
        unselectedIcon: Icon(AppIcons.download),
        page: () => const DownloadPage(),
        shouldRender: false,
      ),
      TabBarIcon(
        name: TabBarIconNameEnum.setting,
        routeName: Routes.setting,
        selectedIcon: Icon(AppIcons.settingsFill),
        unselectedIcon: Icon(AppIcons.settings),
        page: () => const SettingPage(),
        shouldRender: true,
      ),
    ];

    selectedTabIndex = icons.firstIndexWhereOrNull(
            (icon) => icon.name == preferenceSetting.defaultTab.value) ??
        0;
    icons[selectedTabIndex].shouldRender = true;
  }
}
