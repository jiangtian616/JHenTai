import 'package:collection/collection.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_logic.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/pages/search/quick_search/quick_search_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import '../../../setting/preference_setting.dart';
import '../../../widget/eh_log_out_dialog.dart';
import 'notification/tap_tab_bat_button_notification.dart';

class MobileLayoutPageV2 extends StatelessWidget {
  final MobileLayoutPageV2Logic logic = Get.put(MobileLayoutPageV2Logic(), permanent: true);
  final MobileLayoutPageV2State state = Get.find<MobileLayoutPageV2Logic>().state;

  MobileLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        key: MobileLayoutPageV2State.scaffoldKey,
        drawerEdgeDragWidth: PreferenceSetting.drawerGestureEdgeWidth.value.toDouble(),
        drawer: buildLeftDrawer(context),
        drawerEnableOpenDragGesture: PreferenceSetting.enableLeftMenuDrawerGesture.isTrue,
        endDrawer: buildRightDrawer(),
        endDrawerEnableOpenDragGesture: PreferenceSetting.enableQuickSearchDrawerGesture.isTrue,
        body: buildBody(),
        bottomNavigationBar: PreferenceSetting.hideBottomBar.isTrue ? null : buildBottomNavigationBar(context),
      ),
    );
  }

  Widget buildLeftDrawer(BuildContext context) {
    return Drawer(
      width: 278,
      child: GetBuilder<MobileLayoutPageV2Logic>(
        id: logic.tabBarId,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EHUserAvatar(),
              Expanded(
                child: ScrollConfiguration(
                  behavior: UIConfig.leftDrawerPhysicsBehaviour,
                  child: ListView.builder(
                    key: const PageStorageKey('leftDrawer'),
                    controller: state.scrollController,
                    itemCount: state.icons.length,
                    cacheExtent: 1000,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      title: Text(state.icons[index].name.name.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      selected: state.selectedDrawerTabIndex == index,
                      selectedTileColor: UIConfig.mobileDrawerSelectedTileColor(context),
                      leading: state.icons[index].unselectedIcon,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadiusDirectional.only(topEnd: Radius.circular(32), bottomEnd: Radius.circular(32)),
                      ),
                      onTap: () => logic.handleTapTabBarButton(index),
                    ).marginOnly(right: 8, top: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRightDrawer() {
    return Drawer(width: 278, child: QuickSearchPage());
  }

  Widget buildBottomNavigationBar(BuildContext context) {
    return GetBuilder<MobileLayoutPageV2Logic>(
      id: logic.bottomNavigationBarId,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(splashColor: Colors.transparent),
        child: NavigationBar(
          selectedIndex: state.selectedNavigationIndex,
          onDestinationSelected: (int index) => logic.handleTapNavigationBarButton(index),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home), label: 'home'.tr),
            NavigationDestination(icon: const Icon(Icons.download), label: 'download'.tr),
            NavigationDestination(icon: const Icon(Icons.settings), label: 'setting'.tr),
          ],
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
              Offstage(offstage: state.selectedNavigationIndex != 0, child: buildHomeBody()),
              Offstage(offstage: state.selectedNavigationIndex != 1, child: const DownloadPage()),
              Offstage(offstage: state.selectedNavigationIndex != 2, child: const SettingPage()),
            ],
          ),
        ),
        onNotification: (_) {
          MobileLayoutPageV2State.scaffoldKey.currentState?.openDrawer();
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
              foregroundImage:
                  UserSetting.avatarImgUrl.value != null ? ExtendedNetworkImageProvider(UserSetting.avatarImgUrl.value!, cache: true) : null,
              child: Icon(UserSetting.hasLoggedIn() ? Icons.face_retouching_natural : Icons.face,
                  color: UIConfig.loginAvatarForeGroundColor(context), size: 32),
            ),
          ),
          title: Text(UserSetting.nickName.value ?? UserSetting.userName.value ?? 'tap2Login'.tr),
          onTap: () {
            if (!UserSetting.hasLoggedIn()) {
              toRoute(Routes.login);
              return;
            }
            Get.dialog(const LogoutDialog());
          },
        ),
      ),
    );
  }
}
