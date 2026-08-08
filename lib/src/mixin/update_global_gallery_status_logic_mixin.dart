import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/favorite/favorite_page_logic.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/watched/watched_page_logic.dart';

import '../pages/gallerys/dashboard/dashboard_page_logic.dart';
import '../pages/gallerys/dashboard/simple/simple_dashboard_page_logic.dart';
import '../pages/gallerys/simple/gallerys_page_logic.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/desktop/desktop_search_page_tab_logic.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';

mixin UpdateGlobalGalleryStatusLogicMixin on GetxController {
  /// Notify list pages that a gallery's favorite/rating/download status
  /// changed. When [gid] is known, pages whose loaded list does not contain
  /// that gallery are skipped, avoiding a full rebuild fan-out on every change.
  /// Pages that do not expose a gid-filterable list (e.g. [RanklistPageLogic])
  /// are always updated, keeping the original behavior.
  void updateGlobalGalleryStatus([int? gid]) {
    void updateIfNeeded(GetxController logic, List<String> ids) {
      if (gid != null && logic is BasePageLogic && !logic.containsGallery(gid)) {
        return;
      }
      logic.update(ids);
    }

    /// update galleryPage status
    if (Get.isRegistered<GallerysPageLogic>()) {
      GallerysPageLogic gallerysPageLogic = Get.find<GallerysPageLogic>();
      updateIfNeeded(gallerysPageLogic, [gallerysPageLogic.bodyId]);
    }
    if (Get.isRegistered<SimpleDashboardPageLogic>()) {
      SimpleDashboardPageLogic simpleDashboardPageLogic = Get.find<SimpleDashboardPageLogic>();
      updateIfNeeded(simpleDashboardPageLogic, [simpleDashboardPageLogic.bodyId]);
    }
    if (Get.isRegistered<DashboardPageLogic>()) {
      DashboardPageLogic dashboardPageLogic = Get.find<DashboardPageLogic>();
      updateIfNeeded(dashboardPageLogic, [dashboardPageLogic.galleryListId]);
    }
    if (Get.isRegistered<RanklistPageLogic>()) {
      RanklistPageLogic ranklistPageLogic = Get.find<RanklistPageLogic>();
      updateIfNeeded(ranklistPageLogic, [ranklistPageLogic.bodyId]);
    }
    if (Get.isRegistered<PopularPageLogic>()) {
      PopularPageLogic popularPageLogic = Get.find<PopularPageLogic>();
      updateIfNeeded(popularPageLogic, [popularPageLogic.bodyId]);
    }
    if (Get.isRegistered<FavoritePageLogic>()) {
      FavoritePageLogic favoritePageLogic = Get.find<FavoritePageLogic>();
      updateIfNeeded(favoritePageLogic, [favoritePageLogic.bodyId]);
    }
    if (Get.isRegistered<WatchedPageLogic>()) {
      WatchedPageLogic watchedPageLogic = Get.find<WatchedPageLogic>();
      updateIfNeeded(watchedPageLogic, [watchedPageLogic.bodyId]);
    }

    /// update searchPage status
    if (Get.isRegistered<DesktopSearchPageLogic>()) {
      DesktopSearchPageLogic desktopSearchPageLogic = Get.find<DesktopSearchPageLogic>();
      for (DesktopSearchPageTabLogic tabLogic in desktopSearchPageLogic.state.tabLogics) {
        updateIfNeeded(tabLogic, [tabLogic.galleryBodyId]);
      }
    }
    if (Get.isRegistered<SearchPageMobileV2Logic>()) {
      SearchPageMobileV2Logic searchPageMobileV2Logic = Get.find<SearchPageMobileV2Logic>();
      updateIfNeeded(searchPageMobileV2Logic, [searchPageMobileV2Logic.galleryBodyId]);
    }
  }
}
