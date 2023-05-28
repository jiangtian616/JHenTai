import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';

import '../../../../../widget/fade_shrink_widget.dart';
import 'multi_select_download_page_logic_mixin.dart';
import 'multi_select_download_page_state_mixin.dart';

mixin MultiSelectDownloadPageMixin on StatelessWidget {
  MultiSelectDownloadPageLogicMixin get multiSelectDownloadPageLogic;

  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState;

  Widget buildBottomAppBar() {
    return GetBuilder<MultiSelectDownloadPageLogicMixin>(
      id: multiSelectDownloadPageLogic.bottomAppbarId,
      init: multiSelectDownloadPageLogic,
      global: false,
      builder: (_) => FadeShrinkWidget(
        show: multiSelectDownloadPageState.inMultiSelectMode,
        child: BottomAppBar(
          child: Row(
            children: buildBottomAppBarButtons(),
          ),
        ),
      ),
    );
  }

  List<Widget> buildBottomAppBarButtons();
}
