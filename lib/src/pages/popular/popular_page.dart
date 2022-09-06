import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/popular/popular_page_state.dart';

import '../base/base_page.dart';

class PopularPage extends BasePage {
  const PopularPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    String? name,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showTitle: showTitle,
          showJumpButton: false,
          name: name,
        );

  @override
  PopularPageLogic get logic => Get.find<PopularPageLogic>();

  @override
  PopularPageState get state => Get.find<PopularPageLogic>().state;
}
