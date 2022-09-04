import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/eh_dashboard_card.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../config/global_config.dart';
import '../../layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'dashboard_page_logic.dart';

class DashboardPage extends BasePage {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  bool get showMenuButton => true;

  @override
  bool get showTitle => true;

  @override
  String get name => 'home'.tr;

  @override
  DashboardPageLogic get logic => Get.find<DashboardPageLogic>();

  @override
  DashboardPageState get state => Get.find<DashboardPageLogic>().state;

  @override
  List<Widget> buildAppBarButtons() {
    return [
      IconButton(
        icon: const Icon(Icons.search, size: 28),
        padding: const EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
        onPressed: () => toRoute(Routes.mobileV2Search),
      ),
      IconButton(
        icon: const Icon(Icons.more_vert, size: 28),
        padding: const EdgeInsets.only(left: 8, right: 18, top: 8, bottom: 8),
        onPressed: MobileLayoutPageV2State.scaffoldKey.currentState?.openEndDrawer,
      ),
    ];
  }

  @override
  Widget buildBody(BuildContext context) {
    return GetBuilder<DashboardPageLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        scrollController: state.scrollController,
        child: CustomScrollView(
          key: state.pageStorageKey,
          controller: state.scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          scrollBehavior: ScrollConfiguration.of(context),
          slivers: [
            buildPullDownIndicator(),
            _buildRanklistDesc(),
            _buildRanklist(),
            _buildPopularListDesc(),
            _buildPopular(),
            _buildGalleryDesc(),
            _buildGalleryBody(context),
            buildLoadMoreIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildPullDownIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: GlobalConfig.refreshTriggerPullDistance,
      onRefresh: () => logic.handleRefreshTotalPage(),
    );
  }

  Widget _buildRanklist() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: GlobalConfig.dashboardCardSize,
        child: GetBuilder<DashboardPageLogic>(
          id: logic.ranklistId,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.ranklistLoadingState,
            errorTapCallback: logic.loadRanklist,
            successWidgetBuilder: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.ranklistGallerys.length,
              itemBuilder: (_, index) => EHDashboardCard(gallery: state.ranklistGallerys[index], badge: _getRanklistBadge(index)),
              separatorBuilder: (_, __) => const VerticalDivider(),
              cacheExtent: 2000,
            ).paddingSymmetric(horizontal: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildRanklistDesc() {
    return SliverToBoxAdapter(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 16),
        visualDensity: const VisualDensity(vertical: -4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 16)),
            Text('ranklistBoard'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        trailing: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => toRoute(Routes.ranklist),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('seeAll'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w300)),
              Icon(Icons.arrow_forward_ios, color: Get.theme.primaryColor, size: 14).marginOnly(top: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopular() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: GlobalConfig.dashboardCardSize,
        child: GetBuilder<DashboardPageLogic>(
          id: logic.popularListId,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.popularLoadingState,
            errorTapCallback: logic.loadPopular,
            successWidgetBuilder: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.popularGallerys.length,
              itemBuilder: (_, index) => EHDashboardCard(gallery: state.popularGallerys[index]),
              separatorBuilder: (_, __) => const VerticalDivider(),
              cacheExtent: 2000,
            ).paddingSymmetric(horizontal: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularListDesc() {
    return SliverToBoxAdapter(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 16),
        visualDensity: const VisualDensity(vertical: -3),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥵 ', style: TextStyle(fontSize: 16)),
            Text('popular'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        trailing: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => toRoute(Routes.popular),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('seeAll'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w300)),
              Icon(Icons.arrow_forward_ios, color: Get.theme.primaryColor, size: 14).marginOnly(top: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryDesc() {
    return SliverToBoxAdapter(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 10, right: 10, top: 16),
        visualDensity: const VisualDensity(vertical: -2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 16)),
            Text('newest'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              child: Icon(Icons.settings, color: Get.theme.primaryColor, size: 22),
              onTap: logic.handleTapFilterButton,
            ).marginOnly(right: 16),
            GestureDetector(
              child: Icon(Icons.refresh, color: Get.theme.primaryColor, size: 25),
              onTap: logic.clearAndRefresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryBody(BuildContext context) {
    return GetBuilder<DashboardPageLogic>(
      id: logic.galleryListId,
      builder: (_) => buildGalleryCollection(context),
    );
  }

  String? _getRanklistBadge(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return null;
    }
  }
}
