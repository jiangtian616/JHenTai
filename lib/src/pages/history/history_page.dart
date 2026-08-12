import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

import '../base/base_page.dart';
import 'history_page_logic.dart';
import 'history_page_state.dart';

class HistoryPage extends BasePage {
  HistoryPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    String? name,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showTitle: showTitle,
          showJumpButton: true,
          showScroll2TopButton: true,
          name: name,
        );

  @override
  HistoryPageLogic get logic => Get.put<HistoryPageLogic>(HistoryPageLogic(), permanent: true);

  @override
  HistoryPageState get state => Get.find<HistoryPageLogic>().state;

  @override
  List<Widget> buildAppBarActions() {
    return [
      EHAppleIconButton(icon: const Icon(Icons.delete_outline_outlined, size: 27), onPressed: logic.handleTapDeleteButton),
      if (state.galleries.isNotEmpty) const SizedBox(width: 8),
      ...super.buildAppBarActions(),
    ];
  }
}
