import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/eh_dashboard_card.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../config/ui_config.dart';
import '../../layout/mobile_v2/mobile_layout_page_v2_state.dart';
import '../../layout/mobile_v2/notification/tap_tab_bat_button_notification.dart';
import 'dashboard_page_logic.dart';

/// For mobile v2 layout
class DashboardPage extends BasePage {
  const DashboardPage({Key? key})
      : super(
          key: key,
          showMenuButton: true,
          showTitle: true,
          showScroll2TopButton: true,
        );

  @override
  String get name => 'home'.tr;

  @override
  DashboardPageLogic get logic => Get.put<DashboardPageLogic>(DashboardPageLogic(), permanent: true);

  @override
  DashboardPageState get state => Get.find<DashboardPageLogic>().state;

  @override
  List<Widget> buildAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => toRoute(Routes.mobileV2Search),
      ),
      IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: MobileLayoutPageV2State.scaffoldKey.currentState?.openEndDrawer,
      ),
    ];
  }

  @override
  Widget buildBody(BuildContext context) {
    return GetBuilder<DashboardPageLogic>(
      id: logic.bodyId,
      builder: (_) => NotificationListener<UserScrollNotification>(
        onNotification: logic.onUserScroll,
        child: EHWheelSpeedController(
          controller: state.scrollController,
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
              _buildGalleryDesc(context),
              _buildGalleryBody(context),
              super.buildLoadMoreIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildPullDownIndicator() {
    return CupertinoSliverRefreshControl(
      refreshTriggerPullDistance: UIConfig.refreshTriggerPullDistance,
      onRefresh: logic.handleRefreshTotalPage,
    );
  }

  Widget _buildRanklistDesc() {
    return const SliverPadding(
      padding: EdgeInsets.only(left: 10, right: 10, top: 4),
      sliver: SliverToBoxAdapter(
        child: _RankListDesc(),
      ),
    );
  }

  Widget _buildRanklist() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: UIConfig.dashboardCardSize,
        child: GetBuilder<DashboardPageLogic>(
          id: logic.ranklistId,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.ranklistLoadingState,
            errorTapCallback: logic.loadRanklist,
            successWidgetBuilder: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: state.ranklistGallerys.length,
              itemBuilder: (_, index) => EHDashboardCard(gallery: state.ranklistGallerys[index], badge: _getRanklistBadge(index)),
              separatorBuilder: (_, __) => const VerticalDivider(),
              cacheExtent: 2000,
            ).fadeIn(),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularListDesc() {
    return const SliverPadding(
      padding: EdgeInsets.only(left: 10, right: 10, top: 8),
      sliver: SliverToBoxAdapter(
        child: _PopularListDesc(),
      ),
    );
  }

  Widget _buildPopular() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: UIConfig.dashboardCardSize,
        child: GetBuilder<DashboardPageLogic>(
          id: logic.popularListId,
          builder: (_) => LoadingStateIndicator(
            loadingState: state.popularLoadingState,
            errorTapCallback: logic.loadPopular,
            successWidgetBuilder: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: state.popularGallerys.length,
              itemBuilder: (_, index) => EHDashboardCard(gallery: state.popularGallerys[index]),
              separatorBuilder: (_, __) => const VerticalDivider(),
              cacheExtent: 2000,
            ).fadeIn(),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryDesc(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 20),
      sliver: SliverToBoxAdapter(
        child: _GalleryListDesc(
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 22, color: UIConfig.dashboardPageGalleryDescButtonColor(context)),
              onPressed: logic.handleTapFilterButton,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(vertical: -4)),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 25, color: UIConfig.dashboardPageGalleryDescButtonColor(context)),
              onPressed: logic.handleClearAndRefresh,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(vertical: -4, horizontal: -4)),
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

class _RankListDesc extends StatelessWidget {
  const _RankListDesc({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 16)),
            Text('ranklistBoard'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const Expanded(child: SizedBox()),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(vertical: -4)),
          onPressed: () => const TapTabBarButtonNotification(Routes.ranklist).dispatch(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'seeAll'.tr,
                style: TextStyle(color: UIConfig.dashboardPageSeeAllTextColor(context), fontSize: 12, fontWeight: FontWeight.w400, height: 1),
              ),
              Icon(Icons.keyboard_arrow_right, color: UIConfig.dashboardPageArrowButtonColor(context)),
            ],
          ),
        )
      ],
    );
  }
}

class _PopularListDesc extends StatelessWidget {
  const _PopularListDesc({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥵 ', style: TextStyle(fontSize: 16)),
            Text('popular'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const Expanded(child: SizedBox()),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(vertical: -4)),
          onPressed: () => const TapTabBarButtonNotification(Routes.popular).dispatch(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'seeAll'.tr,
                style: TextStyle(color: UIConfig.dashboardPageSeeAllTextColor(context), fontSize: 12, fontWeight: FontWeight.w400, height: 1),
              ),
              Icon(Icons.keyboard_arrow_right, color: UIConfig.dashboardPageArrowButtonColor(context)),
            ],
          ),
        )
      ],
    );
  }
}

class _GalleryListDesc extends StatelessWidget {
  final List<Widget> actions;

  const _GalleryListDesc({Key? key, required this.actions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 16)),
            Text('newest'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const Expanded(child: SizedBox()),
        Row(mainAxisSize: MainAxisSize.min, children: actions)
      ],
    );
  }
}
