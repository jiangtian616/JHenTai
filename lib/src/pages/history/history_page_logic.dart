import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../../model/gallery.dart';
import '../../service/history_service.dart';
import '../../utils/log.dart';
import '../../utils/route_util.dart';
import '../base/base_page_logic.dart';
import 'history_page_state.dart';

class HistoryPageLogic extends BasePageLogic {
  @override
  int get tabIndex => 6;

  @override
  final HistoryPageState state = HistoryPageState();

  final HistoryService historyService = Get.find();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get history by page index $pageIndex');

    return [
      historyService.getByPageIndex(pageIndex),
      historyService.pageCount,
      pageIndex >= 1 ? pageIndex - 1 : null,
      pageIndex < historyService.pageCount - 1 ? pageIndex + 1 : null,
    ];
  }

  @override
  void handleLongPressCard(Gallery gallery) {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: Get.theme.colorScheme.error)),
            onPressed: () {
              backRoute();
              delete(gallery.gid);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
      ),
    );
  }

  @override
  void handleSecondaryTapCard(Gallery gallery) {
    handleLongPressCard(gallery);
  }

  Future<void> delete(int gid) async {
    await historyService.delete(gid);
    state.gallerys.removeWhere((g) => g.gid == gid);
    updateSafely([bodyId]);
  }

  Future<void> deleteAll() async {
    await historyService.deleteAll();
    clearAndRefresh();
  }
}
