import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/home_page_logic.dart';
import 'package:jhentai/src/pages/home/home_page_state.dart';

class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  final HomePageLogic homePageLogic = Get.put(HomePageLogic());
  final HomePageState homePageState = Get.find<HomePageLogic>().state;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomePageLogic>(
      builder: (logic) {
        return Material(
          child: CupertinoTabScaffold(
            controller: homePageState.tabController,
            tabBar: CupertinoTabBar(
              items: homePageState.navigationBarItems,
              backgroundColor: Get.theme.appBarTheme.backgroundColor,
              border: null,
              iconSize: 26,
              onTap: (index) => homePageLogic.handleTapNavigationBar(index),
            ),
            tabBuilder: (BuildContext context, int index) {
              return homePageState.navigationBarViews[index];
            },
          ),
        );
      },
    );
  }
}
