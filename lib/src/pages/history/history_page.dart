import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base/base_page.dart';
import 'history_page_logic.dart';
import 'history_page_state.dart';

class HistoryPage extends BasePage {
  const HistoryPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    String? name,
  }) : super(
    key: key,
    showMenuButton: showMenuButton,
    showTitle: showTitle,
    name: name,
  );

  @override
  HistoryPageLogic get logic => Get.find<HistoryPageLogic>();

  @override
  HistoryPageState get state => Get.find<HistoryPageLogic>().state;
}
