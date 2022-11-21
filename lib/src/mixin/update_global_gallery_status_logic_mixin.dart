import 'package:get/get.dart';

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
