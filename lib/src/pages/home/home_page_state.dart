import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/download/download_view.dart';
import 'package:jhentai/src/pages/home/tab_view/gallerys/gallerys_view.dart';
import 'package:jhentai/src/pages/home/tab_view/ranklist/ranklist_view.dart';
import 'package:jhentai/src/pages/home/tab_view/setting/setting_view.dart';


class HomePageState {
  late int currentIndex;
  late CupertinoTabController tabController;
  late List<BottomNavigationBarItem> navigationBarItems;
  late List<Widget> navigationBarViews;

  /// record tap time to implement 'double tap to refresh'
  DateTime? lastTapTime;

  Map<int, VoidCallback> tabTapCallback = {};

  HomePageState() {
    currentIndex = 0;
    tabController = CupertinoTabController();
    navigationBarItems = [
      BottomNavigationBarItem(icon: const Icon(Icons.collections), label: 'gallery'.tr),
      BottomNavigationBarItem(icon: const Icon(Icons.whatshot), label: 'ranklist'.tr),
      BottomNavigationBarItem(icon: const Icon(Icons.download), label: 'download'.tr),
      BottomNavigationBarItem(icon: const Icon(Icons.settings), label: 'setting'.tr),
    ];
    navigationBarViews = [GallerysView(), RanklistView(), DownloadView(), SettingView()];
  }
}
