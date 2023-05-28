import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../../../../../utils/toast_util.dart';
import 'multi_select_download_page_state_mixin.dart';

mixin MultiSelectDownloadPageLogicMixin<T> on GetxController {
  final String itemCardId = 'itemCardId';
  final String bottomAppbarId = 'bottomAppbarId';

  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState;

  void enterSelectMode() {
    multiSelectDownloadPageState.inMultiSelectMode = true;
    toast('multiSelectHint'.tr);
    updateSafely([bottomAppbarId]);
  }

  void exitSelectMode() {
    Set<int> selectedGids = Set.from(multiSelectDownloadPageState.selectedGids);
    multiSelectDownloadPageState.selectedGids.clear();

    multiSelectDownloadPageState.inMultiSelectMode = false;

    updateSafely([
      bottomAppbarId,
      ...selectedGids.map((gid) => '$itemCardId::$gid').toList(),
    ]);
  }

  void toggleSelectItem(int gid) {
    bool hasSelectedBefore = multiSelectDownloadPageState.selectedGids.isNotEmpty;

    if (multiSelectDownloadPageState.selectedGids.contains(gid)) {
      multiSelectDownloadPageState.selectedGids.remove(gid);
    } else {
      multiSelectDownloadPageState.selectedGids.add(gid);
    }

    bool hasSelectedAfter = multiSelectDownloadPageState.selectedGids.isNotEmpty;

    if (hasSelectedBefore != hasSelectedAfter) {
      updateSafely([bottomAppbarId, '$itemCardId::$gid']);
    } else {
      updateSafely(['$itemCardId::$gid']);
    }
  }

  void selectAllItem();

  void handleTapItem(T item);

  void handleLongPressOrSecondaryTapItem(T item, BuildContext context);
}
