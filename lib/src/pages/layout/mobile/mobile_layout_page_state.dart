import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';

import '../../download/download_page.dart';
import '../../gallerys/nested/nested_gallerys_page.dart';
import '../../ranklist/ranklist_page.dart';

class MobileLayoutPageState {
  int currentIndex = 0;
  CupertinoTabController tabController = CupertinoTabController();

  List<BottomNavigationBarItem> get navigationBarItems => [
        BottomNavigationBarItem(icon: const Icon(Icons.collections), label: 'gallery'.tr),
        BottomNavigationBarItem(icon: const Icon(Icons.whatshot), label: 'ranklist'.tr),
        BottomNavigationBarItem(icon: const Icon(Icons.download), label: 'download'.tr),
        BottomNavigationBarItem(icon: const Icon(Icons.settings), label: 'setting'.tr),
      ];

  List<Widget> navigationBarViews = [NestedGallerysPage(), RanklistPage(), const DownloadPage(), const SettingPage()];

  /// record tap time to implement 'double tap to refresh'
  DateTime? lastTapTime;
}
