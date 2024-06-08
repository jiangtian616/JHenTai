import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'desktop_layout_page_logic.dart';
import 'desktop_layout_page_state.dart';

class DesktopHomePage extends StatelessWidget {
  final DesktopLayoutPageLogic logic = Get.find();
  final DesktopLayoutPageState state = Get.find<DesktopLayoutPageLogic>().state;

  DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DesktopLayoutPageLogic>(
      id: logic.leftColumnId,
      builder: (_) => Stack(
        children: state.icons
            .where((icon) => icon.shouldRender)
            .mapIndexed((index, icon) => Offstage(
                  offstage: state.selectedTabOrder != index,
                  child: icon.page.call(),
                ))
            .toList(),
      ),
    );
  }
}
