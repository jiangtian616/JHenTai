import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/simple/simple_dashboard_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/simple/simple_dashboard_page_state.dart';

import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';
import '../../../base/base_page.dart';
import '../../../layout/mobile_v2/mobile_layout_page_v2_state.dart';

/// For mobile v2 layout
class SimpleDashboardPage extends BasePage {
  const SimpleDashboardPage({Key? key})
      : super(
          key: key,
          showMenuButton: true,
          showTitle: true,
          showScroll2TopButton: true,
        );

  @override
  String get name => 'home'.tr;

  @override
  SimpleDashboardPageLogic get logic => Get.put<SimpleDashboardPageLogic>(SimpleDashboardPageLogic(), permanent: true);

  @override
  SimpleDashboardPageState get state => Get.find<SimpleDashboardPageLogic>().state;

  @override
  List<Widget> buildAppBarActions() {
    return [
      IconButton(icon: const Icon(Icons.settings), onPressed: logic.handleTapFilterButton),
      IconButton(icon: const Icon(Icons.search), onPressed: () => toRoute(Routes.mobileV2Search)),
      IconButton(icon: const Icon(Icons.more_vert), onPressed: MobileLayoutPageV2State.scaffoldKey.currentState?.openEndDrawer),
    ];
  }
}
