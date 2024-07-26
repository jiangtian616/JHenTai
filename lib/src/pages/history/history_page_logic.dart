import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';

import '../../model/gallery.dart';
import '../../model/gallery_history_model.dart';
import '../../service/history_service.dart';
import '../../utils/convert_util.dart';
import '../../service/log.dart';
import '../../utils/route_util.dart';
import '../base/old_base_page_logic.dart';
import 'history_page_state.dart';

class HistoryPageLogic extends OldBasePageLogic {
  @override
  final HistoryPageState state = HistoryPageState();

  final HistoryService historyService = Get.find();

  @override
  bool get useSearchConfig => false;

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    log.info('Get history by page index $pageIndex');

    int pageCount = await historyService.getPageCount();
    List<GalleryHistoryModel> galleryModels = await historyService.getByPageIndex(pageIndex);
    List<Gallery> gallerys = galleryModels.map(galleryHistoryModel2Gallery).toList();

    return [
      gallerys,
      pageCount,
      pageIndex >= 1 ? pageIndex - 1 : null,
      pageIndex < pageCount - 1 ? pageIndex + 1 : null,
    ];
  }

  Future<void> handleTapDeleteButton() async {
    bool? result = await Get.dialog(EHDialog(title: 'delete'.tr + '?'));

    if (result == true) {
      await historyService.deleteAll();
      handleClearAndRefresh();
    }
  }

  @override
  void handleLongPressCard(BuildContext context, Gallery gallery) {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
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
  void handleSecondaryTapCard(BuildContext context, Gallery gallery) {
    handleLongPressCard(context, gallery);
  }

  Future<void> delete(int gid) async {
    await historyService.delete(gid);
    state.gallerys.removeWhere((g) => g.gid == gid);
    updateSafely([bodyId]);
  }
}
