import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_logic.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/pages/search/quick_search/quick_search_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/app_icons.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/will_pop_interceptor.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../model/tab_bar_icon.dart';
import '../../../network/eh_request.dart';
import '../../../setting/preference_setting.dart';
import '../../../widget/eh_alert_dialog.dart';
import 'notification/tap_tab_bat_button_notification.dart';

class MobileLayoutPageV2 extends StatelessWidget {
  final MobileLayoutPageV2Logic logic =
      Get.put(MobileLayoutPageV2Logic(), permanent: true);
  final MobileLayoutPageV2State state =
      Get.find<MobileLayoutPageV2Logic>().state;

  /// Codex-style content-shift drawer (Apple mode only): the current page is
  /// pulled right, revealing the sidebar underneath on a deeper layer.
  static const double _drawerWidth = 278;
  final GlobalKey<_ContentShiftDrawerState> _drawerKey =
      GlobalKey<_ContentShiftDrawerState>();

  void _toggleDrawer() => _drawerKey.currentState?.toggle();

  MobileLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => WillPopInterceptor(
        child: Scaffold(
          key: MobileLayoutPageV2State.scaffoldKey,
          // Apple mode uses the custom content-shift drawer, so the Material
          // drawer/gesture are disabled.
          drawerEdgeDragWidth: ThemeConfig.isApple
              ? 0
              : preferenceSetting.drawerGestureEdgeWidth.value.toDouble(),
          drawer: ThemeConfig.isApple ? null : buildLeftDrawer(context),
          drawerEnableOpenDragGesture:
              ThemeConfig.isApple
                  ? false
                  : preferenceSetting.enableLeftMenuDrawerGesture.isTrue,
          endDrawer: buildRightDrawer(),
          endDrawerEnableOpenDragGesture:
              preferenceSetting.enableQuickSearchDrawerGesture.isTrue,
          body: ThemeConfig.isApple
              ? _buildAppleBody(context)
              : buildBody(),
          bottomNavigationBar: ThemeConfig.isApple
              ? null
              : (preferenceSetting.hideBottomBar.isTrue
                  ? null
                  : buildBottomNavigationBar(context)),
        ),
      ),
    );
  }

  /// The left sidebar panel (avatar + tab list). Used both by the Material
  /// [Drawer] (non-Apple) and the codex-style content-shift drawer (Apple).
  /// [onItemTapped] fires after a sidebar entry is selected. In Apple mode the
  /// top shows a JHenTai wordmark instead of the avatar/login tile, and the
  /// Settings/Download entries are hidden (they live in the bottom tab bar).
  Widget buildLeftDrawerPanel(
    BuildContext context, {
    VoidCallback? onItemTapped,
  }) {
    // Displayed indices map back to the full state.icons list the logic uses.
    final List<int> visibleIndices = ThemeConfig.isApple
        ? [
            for (var i = 0; i < state.icons.length; i++)
              if (state.icons[i].name != TabBarIconNameEnum.download &&
                  state.icons[i].name != TabBarIconNameEnum.setting)
                i,
          ]
        : [for (var i = 0; i < state.icons.length; i++) i];

    return GetBuilder<MobileLayoutPageV2Logic>(
      id: logic.tabBarId,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ThemeConfig.isApple)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  'JHenTai',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
            else
              const EHUserAvatar(),
            Expanded(
              child: ScrollConfiguration(
                behavior: UIConfig.leftDrawerPhysicsBehaviour,
                child: ListView.builder(
                  key: const PageStorageKey('leftDrawer'),
                  controller: state.scrollController,
                  itemCount: visibleIndices.length,
                  scrollCacheExtent: ScrollCacheExtent.pixels(1000),
                  itemBuilder: (context, displayIndex) {
                    final int index = visibleIndices[displayIndex];
                    final TabBarIcon icon = state.icons[index];
                    return ListTile(
                      dense: true,
                      title: Text(icon.name.name.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      selected: state.selectedDrawerTabIndex == index,
                      selectedTileColor:
                          UIConfig.mobileDrawerSelectedTileColor(context),
                      leading: icon.unselectedIcon,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadiusDirectional.only(
                            topEnd: Radius.circular(32),
                            bottomEnd: Radius.circular(32)),
                      ),
                      onTap: () {
                        logic.handleTapTabBarButton(index);
                        onItemTapped?.call();
                      },
                    ).marginOnly(right: 8, top: 2);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLeftDrawer(BuildContext context) {
    return Drawer(
      width: _drawerWidth,
      // Apple style: a translucent surface so the body behind shows through.
      backgroundColor: ThemeConfig.isApple
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.88)
          : null,
      child: buildLeftDrawerPanel(context),
    );
  }

  /// Codex-style content-shift drawer for Apple mode: the page is pulled right
  /// (live with the finger, or via the hamburger), the sidebar stays on a
  /// deeper layer underneath, and a shadow separates the two surfaces.
  Widget _buildAppleBody(BuildContext context) {
    return _ContentShiftDrawer(
      key: _drawerKey,
      width: _drawerWidth,
      sidebar: buildLeftDrawerPanel(
        context,
        onItemTapped: () => _drawerKey.currentState?.close(),
      ),
      content: Stack(
        fit: StackFit.expand,
        children: [
          buildBody(),
          // Hide the floating nav while the on-screen keyboard is up so it
          // never sits on top of the keyboard (e.g. quick-search typing).
          if (!preferenceSetting.hideBottomBar.value &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            buildLiquidGlassBottomNavigationBar(context),
        ],
      ),
    );
  }

  Widget buildRightDrawer() {
    return Drawer(
        width: 278,
        child: QuickSearchPage(
            scrollController: quickSearchService.drawerScrollController));
  }

  Widget buildBottomNavigationBar(BuildContext context) {
    return GetBuilder<MobileLayoutPageV2Logic>(
      id: logic.bottomNavigationBarId,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(splashColor: Colors.transparent),
        child: NavigationBar(
          selectedIndex: state.selectedNavigationIndex,
          onDestinationSelected: logic.handleTapNavigationBarButton,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home), label: 'home'.tr),
            NavigationDestination(
                icon: const Icon(Icons.download), label: 'download'.tr),
            NavigationDestination(
                icon: const Icon(Icons.settings), label: 'setting'.tr),
          ],
        ),
      ),
    );
  }

  Widget buildLiquidGlassBottomNavigationBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItemColor = isDark ? Colors.white : Colors.black;
    final unselectedItemColor = isDark ? Colors.white70 : Colors.black54;

    return GetBuilder<MobileLayoutPageV2Logic>(
      id: logic.bottomNavigationBarId,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            UIConfig.liquidGlassNavBarMarginBottom,
          ),
          child: GlassTabBar.bottom(
            tabs: [
              GlassTab(
                icon: Icon(AppIcons.home),
                activeIcon: Icon(AppIcons.homeFill),
                label: 'home'.tr,
              ),
              GlassTab(
                icon: Icon(AppIcons.download),
                activeIcon: Icon(AppIcons.downloadFill),
                label: 'download'.tr,
              ),
              GlassTab(
                icon: Icon(AppIcons.settings),
                activeIcon: Icon(AppIcons.settingsFill),
                label: 'setting'.tr,
              ),
            ],
            selectedIndex: state.selectedNavigationIndex,
            onTabSelected: logic.handleTapNavigationBarButton,
            selectedIconColor: selectedItemColor,
            unselectedIconColor: unselectedItemColor,
            selectedLabelColor: selectedItemColor,
            unselectedLabelColor: unselectedItemColor,
            barHeight: UIConfig.liquidGlassNavBarHeight,
            // Deepen the bar in dark mode so it separates from the dark body.
            settings: LiquidGlassSettings(
              glassColor:
                  isDark ? const Color(0xCC1E1E1E) : const Color(0x8CFFFFFF),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    return NotificationListener<TapTabBarButtonNotification>(
      child: NotificationListener<TapMenuButtonNotification>(
        child: GetBuilder<MobileLayoutPageV2Logic>(
          id: logic.bodyId,
          builder: (_) => Stack(
            children: [
              Offstage(
                  offstage: state.selectedNavigationIndex != 0,
                  child: buildHomeBody()),
              Offstage(
                  offstage: state.selectedNavigationIndex != 1,
                  child: const DownloadPage()),
              Offstage(
                  offstage: state.selectedNavigationIndex != 2,
                  child: const SettingPage()),
            ],
          ),
        ),
        onNotification: (_) {
          if (ThemeConfig.isApple) {
            _toggleDrawer();
          } else {
            MobileLayoutPageV2State.scaffoldKey.currentState?.openDrawer();
          }
          return true;
        },
      ),
      onNotification: (notification) {
        logic.handleTapTabBarButtonByRouteName(notification.routeName);
        return true;
      },
    );
  }

  /// use [shouldRender] to implement lazy load with [Offstage]
  Widget buildHomeBody() {
    return Stack(
      children: state.icons
          .where((icon) => icon.shouldRender)
          .mapIndexed(
            (index, icon) => Offstage(
              offstage: state.selectedDrawerTabOrder != index,
              child: icon.page.call(),
            ),
          )
          .toList(),
    );
  }
}

class EHUserAvatar extends StatelessWidget {
  const EHUserAvatar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Obx(
        () => ListTile(
          leading: GestureDetector(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: UIConfig.loginAvatarBackGroundColor(context),
              foregroundImage: userSetting.avatarImgUrl.value != null
                  ? ExtendedNetworkImageProvider(
                      userSetting.avatarImgUrl.value!,
                      cache: true)
                  : null,
              child: Icon(
                  userSetting.hasLoggedIn()
                      ? Icons.face_retouching_natural
                      : Icons.face,
                  color: UIConfig.loginAvatarForeGroundColor(context),
                  size: 32),
            ),
          ),
          title: Text(userSetting.nickName.value ??
              userSetting.userName.value ??
              'tap2Login'.tr),
          onTap: () async {
            if (!userSetting.hasLoggedIn()) {
              toRoute(Routes.login);
              return;
            }
            bool? result = await Get.dialog(const EHDialog(title: 'logout ?'));
            if (result == true) {
              await ehRequest.requestLogout();
            }
          },
        ),
      ),
    );
  }
}

/// Codex-style content-shift drawer used by the Apple mobile layout.
///
/// The [content] layer sits on top and translates right — following the finger
/// live during a drag — revealing [sidebar] on a deeper layer underneath, with
/// a shadow on the content edge. Opening plays a haptic tick.
class _ContentShiftDrawer extends StatefulWidget {
  const _ContentShiftDrawer({
    super.key,
    required this.sidebar,
    required this.content,
    this.width = 278,
  });

  final Widget sidebar;
  final Widget content;
  final double width;

  @override
  State<_ContentShiftDrawer> createState() => _ContentShiftDrawerState();
}

class _ContentShiftDrawerState extends State<_ContentShiftDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isOpen => _controller.value > 0.5;

  void toggle() => _isOpen ? close() : open();

  void open() => _animateTo(1.0);

  void close() => _animateTo(0.0);

  void _animateTo(double target) {
    if (target > _controller.value && target == 1.0) {
      // Opening just passed the halfway snap — a light haptic confirms it.
      HapticFeedback.mediumImpact();
    }
    _controller.animateTo(
      target,
      curve: Curves.easeOutCubic,
    );
  }

  void _onDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Accumulate the incremental horizontal delta so the drawer tracks the
    // finger 1:1. Previously only the last update's delta was applied, so a
    // slow swipe barely moved the sidebar and only a fast flick could open it.
    _controller.value = (_controller.value + (details.primaryDelta ?? 0) / widget.width)
        .clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity > 300) {
      _animateTo(1.0);
    } else if (velocity < -300) {
      _animateTo(0.0);
    } else if (_controller.value < 0.08) {
      // Negligible drag — settle back closed.
      _animateTo(0.0);
    } else {
      // Slow drag: keep the drawer at the dragged fraction so a slight swipe
      // leaves it visibly open instead of snapping shut.
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double shift = _controller.value * widget.width;
        final bool open = _controller.value > 0.01;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.width,
              child: ColoredBox(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.92),
                child: widget.sidebar,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: Offset(shift, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: open
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 28,
                              spreadRadius: 3,
                              offset: const Offset(6, 0),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.content,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
