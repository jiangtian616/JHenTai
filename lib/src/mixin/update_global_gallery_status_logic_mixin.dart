import 'package:get/get.dart';

import '../pages/gallerys/dashboard/dashboard_page_logic.dart';
import '../pages/gallerys/nested/nested_gallerys_page_logic.dart' as g;
import '../pages/gallerys/simple/gallerys_page_logic.dart';
import '../pages/search/desktop/desktop_search_page_logic.dart';
import '../pages/search/mobile/search_page_logic.dart';
import '../pages/search/mobile_v2/search_page_mobile_v2_logic.dart';

mixin UpdateGlobalGalleryStatusLogicMixin on GetxController {
  void updateGlobalGalleryStatus() {
    /// update galleryPage status
    if (Get.isRegistered<g.NestedGallerysPageLogic>()) {
      Get.find<g.NestedGallerysPageLogic>().update([g.bodyId]);
    }
    if (Get.isRegistered<GallerysPageLogic>()) {
      Get.find<GallerysPageLogic>().updateBody();
    }
    if (Get.isRegistered<DashboardPageLogic>()) {
      Get.find<DashboardPageLogic>().updateGalleryList();
    }

    /// update searchPage status
    SearchPageLogic.current?.update();
    if (Get.isRegistered<DesktopSearchPageLogic>()) {
      Get.find<DesktopSearchPageLogic>().updateGalleryBody();
    }
    if (Get.isRegistered<SearchPageMobileV2Logic>()) {
      Get.find<SearchPageMobileV2Logic>().updateGalleryBody();
    }
  }
}
