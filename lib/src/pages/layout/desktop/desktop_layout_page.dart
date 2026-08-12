import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_home_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_state.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:macos_window_utils/widgets/visual_effect_subview_container/visual_effect_subview_container.dart';

import '../../../config/theme_config.dart';
import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../service/windows_service.dart';
import '../../../setting/preference_setting.dart';
import '../../../utils/route_util.dart';
import '../../blank_page.dart';
import 'desktop_layout_page_logic.dart';

class DesktopLayoutPage extends StatelessWidget {
  final DesktopLayoutPageLogic logic = Get.put(
    DesktopLayoutPageLogic(),
    permanent: true,
  );
  final DesktopLayoutPageState state = Get.find<DesktopLayoutPageLogic>().state;

  DesktopLayoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool useNativeMacOSSidebar =
        GetPlatform.isMacOS && ThemeConfig.isApple;
    return Row(
      children: [
        _leftTabBar(
          context,
          includeTrailingDivider: useNativeMacOSSidebar,
        ),
        if (!useNativeMacOSSidebar) _layoutDivider(context),
        Expanded(child: _buildDoubleColumn(context)),
      ],
    );
  }

  Widget _layoutDivider(BuildContext context) {
    return VerticalDivider(
      width: 1,
      color:
          ThemeConfig.isApple
              ? Theme.of(context).colorScheme.outline
              : UIConfig.layoutDividerColor(context),
    );
  }

  Widget _leftTabBar(
    BuildContext context, {
    required bool includeTrailingDivider,
  }) {
    final bool isMacOS = GetPlatform.isMacOS && ThemeConfig.isApple;
    final Brightness brightness = Theme.of(context).brightness;
    final double width =
        isMacOS
            ? UIConfig.desktopMacOSLeftTabBarWidth
            : UIConfig.desktopLeftTabBarWidth;
    final Color sideBarColor =
        isMacOS
            ? UIConfig.desktopSideBarColor(
              context,
            ).withValues(alpha: UIConfig.desktopMacOSSideBarAlpha(brightness))
            : (ThemeConfig.isApple
                ? UIConfig.desktopSideBarColor(context)
                : UIConfig.backGroundColor(context));
    Widget bar = Material(
      color: isMacOS ? Colors.transparent : null,
      child: Container(
        width: width,
        color: isMacOS && includeTrailingDivider ? null : sideBarColor,
        decoration:
            isMacOS && includeTrailingDivider
                ? BoxDecoration(
                  color: sideBarColor,
                  border: Border(
                    right: BorderSide(
                      width: 1,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
                : null,
        child: GetBuilder<DesktopLayoutPageLogic>(
          id: logic.tabBarId,
          builder:
              (_) => Padding(
                padding: EdgeInsets.only(
                  top: isMacOS ? UIConfig.desktopTitleBarHeight : 0,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ScrollConfiguration(
                        behavior:
                            UIConfig.scrollBehaviourWithoutScrollBarWithMouse,
                        child: ListView.builder(
                          controller: state.leftTabBarScrollController,
                          itemCount: state.icons.length,
                          itemExtent: UIConfig.desktopLeftTabBarItemHeight,
                          itemBuilder: _tabBarIcon,
                        ),
                      ),
                    ),
                    _lanDevicesFooter(context),
                  ],
                ),
              ),
        ),
      ),
    );

    if (isMacOS) {
      /// Native macOS translucent sidebar (NSVisualEffectView .sidebar material),
      /// showing the desktop through a frosted surface.
      // Clear the opaque Flutter page background inside the sidebar rect.
      // Without this punch-through, the translucent tint blends with Flutter's
      // window surface instead of the native visual-effect view underneath.
      bar = DecoratedBox(
        decoration: const BoxDecoration(
          // A fully transparent source may be optimized away by Flutter;
          // an opaque source with BlendMode.clear reliably punches the hole.
          color: Colors.black,
          backgroundBlendMode: BlendMode.clear,
        ),
        child: bar,
      );
      bar = VisualEffectSubviewContainer(
        alphaValue: UIConfig.desktopMacOSVisualEffectAlpha(brightness),
        // Extend only the native material. The Flutter child remains at the
        // existing width, so the divider keeps its current position.
        padding: const EdgeInsets.only(
          top: -4320,
          right: -UIConfig.desktopMacOSSidebarEffectRightExtension,
        ),
        material: NSVisualEffectViewMaterial.sidebar,
        child: bar,
      );
    }
    return bar;
  }

  /// Shows trusted LAN devices that are currently connected at the bottom of
  /// the sidebar, so the server host can see which phone is sharing.
  Widget _lanDevicesFooter(BuildContext context) {
    return GetBuilder<LanDeviceTrustService>(
      id: LanDeviceTrustService.devicesChangedId,
      builder: (service) {
        if (!service.isEnabled || service.trustedDevices.isEmpty) {
          return const SizedBox.shrink();
        }
        final List<TrustedLanDevice> connected =
            service.trustedDevices
                .where(
                  (device) =>
                      service.connectionFor(device.deviceId).state ==
                      LanPeerConnectionState.connected,
                )
                .toList();
        if (connected.isEmpty) {
          return const SizedBox.shrink();
        }
        final Color iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                connected.map((device) {
                  return InkWell(
                    onTap: () => toRoute(Routes.lanSharing),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android, size: 18, color: iconColor),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 56,
                            child: Text(
                              device.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _tabBarIcon(BuildContext context, int index) {
    return MouseRegion(
      onEnter: (_) => logic.updateHoveringTabIndex(index),
      onExit: (_) => logic.updateHoveringTabIndex(null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Center(
              child:
                  ThemeConfig.isApple
                      ? AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: EHAppleIconButton.defaultSize,
                        height: EHAppleIconButton.defaultSize,
                        // iOS selected capsule: a solid accent circle with a
                        // contrasting icon, shown through the translucent glass.
                        decoration: BoxDecoration(
                          color:
                              state.selectedTabIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : (state.hoveringTabIndex == index
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest
                                      : Colors.transparent),
                          shape: BoxShape.circle,
                        ),
                        child: EHAppleIconButton(
                          onPressed: () => logic.handleTapTabBarButton(index),
                          icon:
                              state.selectedTabIndex == index
                                  ? state.icons[index].selectedIcon
                                  : state.icons[index].unselectedIcon,
                          color:
                              state.selectedTabIndex == index
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          glowColor:
                              state.selectedTabIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                      )
                      : DecoratedBox(
                        decoration: BoxDecoration(
                          border:
                              state.selectedTabIndex == index
                                  ? Border(
                                    left: BorderSide(
                                      width: 3,
                                      color: UIConfig.desktopLeftTabIconColor(
                                        context,
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                        child: EHAppleIconButton(
                          onPressed: () => logic.handleTapTabBarButton(index),
                          icon:
                              state.selectedTabIndex == index
                                  ? state.icons[index].selectedIcon
                                  : state.icons[index].unselectedIcon,
                          color: UIConfig.desktopLeftTabIconColor(context),
                        ),
                      ),
            ),
          ),
          SizedBox(
            height: UIConfig.desktopLeftTabBarTextHeight,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder:
                    (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                child:
                    state.hoveringTabIndex != index
                        ? null
                        : Text(
                          state.icons[index].name.name.tr,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleColumn(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConfig.backGroundColor(context),
      body: ResizableContainer(
        direction: Axis.horizontal,
        controller: logic.resizableController,
        children: [
          ResizableChild(
            child: _leftColumn(),
            size: ResizableSize.ratio(windowService.leftColumnWidthRatio),
            minSize: 100,
          ),
          ResizableChild(
            child: _rightColumn(),
            size: ResizableSize.ratio(1 - windowService.leftColumnWidthRatio),
            minSize: 100,
          ),
        ],
        divider: ResizableDivider(
          thickness: 1.5,
          size: 7.5,
          color: UIConfig.layoutDividerColor(context),
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return Navigator(
      key: Get.nestedKey(left),
      observers: [GetObserver(null, leftRouting)],
      onGenerateInitialRoutes:
          (_, __) => [
            GetPageRoute(
              settings: const RouteSettings(name: Routes.desktopHome),
              page: DesktopHomePage.new,
              popGesture: false,
              transition: Transition.fadeIn,
              showCupertinoParallax: false,
            ),
          ],
      onGenerateRoute: (settings) {
        Get.routing.args = settings.arguments;
        Get.parameters = Get.routeTree.matchRoute(settings.name!).parameters;
        return GetPageRoute(
          settings: settings,

          /// setting name may include path params
          page:
              Routes.pages
                  .firstWhere(
                    (page) => settings.name!.split('?')[0] == page.name,
                  )
                  .page,

          popGesture: preferenceSetting.enableSwipeBackGesture.isTrue,
          transition: Transition.fadeIn,
          transitionDuration: UIConfig.defaultPageRouteTransitionDuration,
        );
      },
    );
  }

  Widget _rightColumn() {
    return Navigator(
      key: Get.nestedKey(right),
      observers: [GetObserver(null, rightRouting)],
      onGenerateInitialRoutes:
          (_, __) => [
            GetPageRoute(
              settings: const RouteSettings(name: Routes.blank),
              page: () => const BlankPage(),
              popGesture: false,
              transition: Transition.fadeIn,
              showCupertinoParallax: false,
            ),
          ],
      onGenerateRoute: (settings) {
        Get.routing.args = settings.arguments;
        Get.parameters = Get.routeTree.matchRoute(settings.name!).parameters;
        return GetPageRoute(
          settings: settings,

          /// setting name may include path params
          page:
              Routes.pages
                  .firstWhere(
                    (page) => settings.name!.split('?')[0] == page.name,
                  )
                  .page,

          /// do not use swipe back in tablet layout!
          popGesture: false,
          transition: Transition.fadeIn,
          transitionDuration: UIConfig.defaultPageRouteTransitionDuration,
          showCupertinoParallax: false,
        );
      },
    );
  }
}
