import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../base/base_page.dart';
import 'watched_page_logic.dart';

class WatchedPage extends BasePage {
  const WatchedPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    String? name,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showJumpButton: true,
          showFilterButton: true,
          showTitle: showTitle,
          showScroll2TopButton: true,
          name: name,
        );

  @override
  WatchedPageLogic get logic => Get.find<WatchedPageLogic>();

  @override
  WatchedPageState get state => Get.find<WatchedPageLogic>().state;
}
