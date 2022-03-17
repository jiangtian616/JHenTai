import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/navigation_view/download/download_view.dart';

import 'navigation_view/gallerys/gallerys_view.dart';
import 'navigation_view/setting/setting_view.dart';

class HomePageState {
  late int currentNavigationIndex;
  late List<BottomNavigationBarItem> navigationBarItems;
  late List<Widget> navigationBarViews;

  /// use this manual controller to implement 'scroll to top'
  late ScrollController galleryViewScrollController;

  /// record tap time to implement 'double tap to refresh'
  DateTime? lastTapTime;

  HomePageState() {
    currentNavigationIndex = 0;
    navigationBarItems = [
      BottomNavigationBarItem(icon: const Icon(Icons.collections), label: 'gallery'.tr),
      BottomNavigationBarItem(icon: const Icon(Icons.download), label: 'download'.tr),
      BottomNavigationBarItem(icon: const Icon(Icons.settings), label: 'setting'.tr),
    ];
    navigationBarViews = [GallerysView(), DownloadView(), SettingView()];
    galleryViewScrollController = ScrollController();
  }
}
