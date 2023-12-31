import 'package:get/get.dart';
import 'package:jhentai/src/pages/favorite/favorite_page_logic.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/watched/watched_page_logic.dart';

import '../pages/gallerys/dashboard/dashboard_page_logic.dart';
import '../pages/gallerys/simple/gallerys_page_logic.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/desktop/desktop_search_page_tab_logic.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';

mixin UpdateGlobalGalleryStatusLogicMixin on GetxController {
  void updateGlobalGalleryStatus() {
    /// update galleryPage status
    if (Get.isRegistered<GallerysPageLogic>()) {
      GallerysPageLogic gallerysPageLogic = Get.find<GallerysPageLogic>();
      gallerysPageLogic.update([gallerysPageLogic.bodyId]);
    }
    if (Get.isRegistered<DashboardPageLogic>()) {
      DashboardPageLogic dashboardPageLogic = Get.find<DashboardPageLogic>();
      dashboardPageLogic.update([dashboardPageLogic.galleryListId]);
    }
    if (Get.isRegistered<RanklistPageLogic>()) {
      RanklistPageLogic ranklistPageLogic = Get.find<RanklistPageLogic>();
      ranklistPageLogic.update([ranklistPageLogic.bodyId]);
    }
    if (Get.isRegistered<PopularPageLogic>()) {
      PopularPageLogic popularPageLogic = Get.find<PopularPageLogic>();
      popularPageLogic.update([popularPageLogic.bodyId]);
    }
    if (Get.isRegistered<FavoritePageLogic>()) {
      FavoritePageLogic favoritePageLogic = Get.find<FavoritePageLogic>();
      favoritePageLogic.update([favoritePageLogic.bodyId]);
    }
    if (Get.isRegistered<WatchedPageLogic>()) {
      WatchedPageLogic watchedPageLogic = Get.find<WatchedPageLogic>();
      watchedPageLogic.update([watchedPageLogic.bodyId]);
    }

    /// update searchPage status
    if (Get.isRegistered<DesktopSearchPageLogic>()) {
      DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
      for (DesktopSearchPageTabLogic tabLogic in desktopSearchPageLogic.state.tabLogics) {
        tabLogic.update([tabLogic.galleryBodyId]);
      }
    }
    if (Get.isRegistered<SearchPageMobileV2Logic>()) {
      SearchPageMobileV2Logic searchPageMobileV2Logic = Get.find<SearchPageMobileV2Logic>();
      searchPageMobileV2Logic.update([searchPageMobileV2Logic.galleryBodyId]);
    }
  }
}
