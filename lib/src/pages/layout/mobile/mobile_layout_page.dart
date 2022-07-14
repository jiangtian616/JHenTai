import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'mobile_layout_page_logic.dart';
import 'mobile_layout_page_state.dart';

class MobileLayoutPage extends StatelessWidget {
  final MobileLayoutPageLogic logic = Get.put(MobileLayoutPageLogic(), permanent: true);
  final MobileLayoutPageState state = Get.find<MobileLayoutPageLogic>().state;

  MobileLayoutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MobileLayoutPageLogic>(
      builder: (_) => ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.unknown,
          },
          scrollbars: false,
        ),
        child: CupertinoTabScaffold(
          backgroundColor: Theme.of(context).cupertinoOverrideTheme?.scaffoldBackgroundColor,
          controller: state.tabController,
          tabBar: CupertinoTabBar(
            items: state.navigationBarItems,
            backgroundColor: Get.theme.appBarTheme.backgroundColor,
            activeColor: Get.theme.primaryColorLight,
            border: null,
            iconSize: 26,
            onTap: (index) => logic.handleTapNavigationBar(index),
          ),
          tabBuilder: (BuildContext context, int index) => state.navigationBarViews[index],
        ),
      ),
    );
  }
}
