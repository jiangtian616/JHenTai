import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page_state.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/search_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_glass_toolbar.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/eh_dashboard_card.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../config/ui_config.dart';
import '../../layout/mobile_v2/mobile_layout_page_v2_state.dart';
import '../../layout/mobile_v2/notification/tap_tab_bat_button_notification.dart';
import '../../layout/mobile_v2/mobile_layout_page_v2.dart';
import 'dashboard_page_logic.dart';

/// For mobile v2 layout
class DashboardPage extends BasePage {
  DashboardPage({Key? key})
      : super(
          key: key,
          showMenuButton: true,
          showTitle: true,
          showScroll2TopButton: true,
        );

  /// Apple slide-down quick-search overlay (a bar drops from under the AppBar
  /// and focuses the keyboard). Plain icons replace the glass circles so the
  /// four function buttons stay compact.
  ///
  /// The overlay state (notifier, controller, focus node) lives on the
  /// persistent [DashboardPageState]: this page is a StatelessWidget that gets
  /// recreated when the parent layout rebuilds (e.g. the keyboard popping up
  /// changes viewInsets), so widget-local fields would reset the bar and drop
  /// the keyboard instantly.
  void _toggleSearch() {
    final bool opening = !state.searchVisible.value;
    state.searchVisible.value = opening;
    if (opening) {
      // Focus right away so the system keyboard pops immediately.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => state.searchFocusNode.requestFocus(),
      );
    } else {
      state.searchFocusNode.unfocus();
    }
  }

  @override
  String get name => 'home'.tr;

  @override
  DashboardPageLogic get logic => Get.put<DashboardPageLogic>(DashboardPageLogic(), permanent: true);

  @override
  DashboardPageState get state => Get.find<DashboardPageLogic>().state;

  @override
  List<Widget> buildAppBarActions() {
    // Apple style: plain pull-out icons (no glass circle) so the four function
    // buttons (menu, search, more, plus bottom nav) stay compact.
    return [
      if (ThemeConfig.isApple)
        IconButton(
          onPressed: _toggleSearch,
          icon: const Icon(Icons.search, size: 24),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        )
      else
        EHAppleIconButton(
          icon: const Icon(Icons.search),
          onPressed: () => toRoute(Routes.mobileV2Search),
        ),
      if (ThemeConfig.isApple)
        IconButton(
          onPressed:
              MobileLayoutPageV2.openQuickSearchDrawer,
          icon: const Icon(Icons.door_front_door_outlined, size: 24),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        )
      else
        EHAppleIconButton(
          icon: const Icon(Icons.more_vert),
          onPressed:
              MobileLayoutPageV2State.scaffoldKey.currentState?.openEndDrawer,
        ),
    ];
  }

  @override
  Widget buildBody(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: state.searchVisible,
      builder: (context, visible, _) => Stack(
        fit: StackFit.expand,
        children: [
          // Underlying gallery content.
          GetBuilder<DashboardPageLogic>(
            id: logic.bodyId,
            builder: (_) => NotificationListener<UserScrollNotification>(
              onNotification: logic.onUserScroll,
              child: EHWheelSpeedController(
                controller: state.scrollController,
                child: CustomScrollView(
                  key: state.pageStorageKey,
                  controller: state.scrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  scrollBehavior:
                      UIConfig.scrollBehaviourWithScrollBarWithMouse,
                  slivers: [
                    buildPullDownIndicator(),
                    _buildRanklistDesc(),
                    _buildRanklist(),
                    _buildPopularListDesc(),
                    _buildPopular(),
                    _buildGalleryDesc(context),
                    _buildGalleryBody(context),
                    super.buildLoadMoreIndicator(context),
                  ],
                ),
              ),
            ),
          ),
          // Dim the underlying content while the quick-search bar is open;
          // tapping the scrim closes it.
          if (visible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleSearch,
                child: Container(color: Colors.black54),
              ),
            ),
          // Slide-down search bar pinned to the top, above the scrim.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildSlideDownSearch(visible),
          ),
        ],
      ),
    );
  }

  /// Apple quick-search bar that drops down from under the AppBar and focuses
  /// the system keyboard immediately; submitting runs a new search and closes.
  Widget _buildSlideDownSearch(bool visible) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: ClipRect(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: visible ? 44 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: EHAppleTextField(
                controller: state.searchController,
                focusNode: state.searchFocusNode,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'search'.tr,
                ),
                onSubmitted: (keyword) {
                  final String trimmed = keyword.trim();
                  if (trimmed.isEmpty) {
                    return;
                  }
                  _toggleSearch();
                  state.searchController.clear();
                  newSearch(keyword: trimmed);
                },
              ),
            ),
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
              scrollCacheExtent: ScrollCacheExtent.pixels(2000),
            ).enableMouseDrag(withScrollBar: false).fadeIn(),
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
              scrollCacheExtent: ScrollCacheExtent.pixels(2000),
            ).enableMouseDrag(withScrollBar: false).fadeIn(),
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
            EHAppleGlassToolbar(
              materialSpacing: 0,
              itemPadding: const EdgeInsets.all(7),
              items: [
                EHAppleToolbarItem(
                  icon: Icon(Icons.settings, size: 22, color: UIConfig.dashboardPageGalleryDescButtonColor(context)),
                  onPressed: logic.handleTapFilterButton,
                  padding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(vertical: -4),
                ),
                EHAppleToolbarItem(
                  icon: Icon(Icons.refresh, size: 25, color: UIConfig.dashboardPageGalleryDescButtonColor(context)),
                  onPressed: logic.handleClearAndRefresh,
                  padding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(vertical: -4, horizontal: -4),
                ),
              ],
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
        EHAppleTextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 12), visualDensity: const VisualDensity(vertical: -4)),
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
        EHAppleTextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 12), visualDensity: const VisualDensity(vertical: -4)),
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
