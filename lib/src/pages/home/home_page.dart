import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/home/home_page_logic.dart';
import 'package:jhentai/src/pages/home/home_page_state.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/log.dart';

class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  final HomePageLogic homePageLogic = Get.put(HomePageLogic());
  final HomePageState homePageState = Get.find<HomePageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomePageLogic>(
      builder: (logic) {
        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            items: homePageState.navigationBarItems,
            onTap: (index) {
              homePageLogic.handleTapNavigationBar(index);
            },
            currentIndex: homePageState.currentNavigationIndex,
          ),
          body: homePageState.navigationBarViews[homePageState.currentNavigationIndex],
          floatingActionButton: FloatingActionButton(
            child: Text('change'),
            onPressed: () {
              // Get.toNamed(Routes.test);
              // Get.changeTheme(Get.isDarkMode ? ThemeConfig.light : ThemeConfig.dark);
              // EHRequest.getUserInfoByCookieAndMemberId(UserSetting.ipbMemberId!);
              Log.info(Get.find<StorageService>().getKeys(), false);
            },
          ),
        );
      },
    );
  }
}
