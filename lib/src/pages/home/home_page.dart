import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/home_page_logic.dart';
import 'package:jhentai/src/pages/home/home_page_state.dart';

import '../../config/theme_config.dart';

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
              Get.changeTheme(Get.isDarkMode ? ThemeConfig.light : ThemeConfig.dark);
              // EHRequest.getUserInfoByCookieAndMemberId(UserSetting.ipbMemberId!);
              // Log.info(Get.find<StorageService>().getKeys(), false);
            },
          ),
        );
      },
    );
  }
}
