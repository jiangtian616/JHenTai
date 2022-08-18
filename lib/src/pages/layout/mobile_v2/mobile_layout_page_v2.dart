import 'package:collection/collection.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_logic.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/notification/tap_menu_button_notification.dart';
import 'package:jhentai/src/pages/search/quick_search/quick_search_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import '../../../widget/log_out_dialog.dart';

class MobileLayoutPageV2 extends StatelessWidget {
  final MobileLayoutPageV2Logic logic = Get.put(MobileLayoutPageV2Logic(), permanent: true);
  final MobileLayoutPageV2State state = Get.find<MobileLayoutPageV2Logic>().state;

  MobileLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
        scrollbars: true,
      ),
      child: Obx(
        () => Scaffold(
          key: MobileLayoutPageV2State.scaffoldKey,
          drawer: _buildLeftDrawer(),
          endDrawer: _buildRightDrawer(),
          endDrawerEnableOpenDragGesture: StyleSetting.enableQuickSearchDrawerGesture.isTrue,
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildLeftDrawer() {
    return Drawer(
      width: 278,
      child: GetBuilder<MobileLayoutPageV2Logic>(
        id: logic.tabBarId,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(),
              ...state.icons
                  .mapIndexed(
                    (index, icon) => ListTile(
                      dense: true,
                      title: Text(state.icons[index].name.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      selected: state.selectedTabIndex == index,
                      selectedTileColor: Get.theme.primaryColor.withOpacity(0.1),
                      leading: state.icons[index].unselectedIcon,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadiusDirectional.only(topEnd: Radius.circular(32), bottomEnd: Radius.circular(32)),
                      ),
                      onTap: () => logic.handleTapTabBarButton(index),
                    ).marginOnly(right: 8, top: 2),
                  )
                  .toList()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightDrawer() {
    return Drawer(
      width: 278,
      child: QuickSearchPage(automaticallyImplyLeading: false),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: NotificationListener<TapMenuButtonNotification>(
        child: GetBuilder<MobileLayoutPageV2Logic>(
          id: logic.pageId,
          builder: (_) => Stack(
            children: state.icons
                .where((icon) => icon.shouldRender)
                .mapIndexed((index, icon) => Offstage(
                      offstage: state.selectedTabOrder != index,
                      child: icon.page.call(),
                    ))
                .toList(),
          ),
        ),
        onNotification: (_) {
          MobileLayoutPageV2State.scaffoldKey.currentState?.openDrawer();
          return true;
        },
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      height: 120,
      child: Obx(
        () => Align(
          child: ListTile(
            leading: GestureDetector(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade300,
                foregroundImage: UserSetting.avatarImgUrl.value != null ? ExtendedNetworkImageProvider(UserSetting.avatarImgUrl.value!) : null,
                child: Icon(UserSetting.hasLoggedIn() ? Icons.face_retouching_natural : Icons.face, color: Colors.grey.withOpacity(0.8), size: 32),
              ),
              onTap: _handleTapAvatar,
            ),
            title: Text(UserSetting.hasLoggedIn() ? UserSetting.userName.value! : ''),
          ),
        ),
      ),
    );
  }

  void _handleTapAvatar() {
    if (!UserSetting.hasLoggedIn()) {
      toRoute(Routes.login);
      return;
    }

    Get.dialog(const LogoutDialog());
  }
}
