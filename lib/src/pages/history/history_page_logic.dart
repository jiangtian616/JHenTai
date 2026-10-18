import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_context_menu.dart';

import '../../model/gallery.dart';
import '../../model/gallery_history_model.dart';
import '../../service/history_service.dart';
import '../../utils/convert_util.dart';
import '../../service/log.dart';
import '../base/old_base_page_logic.dart';
import 'history_page_state.dart';

class HistoryPageLogic extends OldBasePageLogic {
  @override
  final HistoryPageState state = HistoryPageState();

  @override
  bool get useSearchConfig => false;

  @override
  Future<List<dynamic>> getGalleriesAndPageInfoByPage(int pageIndex) async {
    log.info('Get history by page index $pageIndex');

    int pageCount = await historyService.getPageCount();
    List<GalleryHistoryModel> galleryModels = await historyService.getByPageIndex(pageIndex);
    List<Gallery> galleries = galleryModels.map(galleryHistoryModel2Gallery).toList();

    return [
      galleries,
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
  void handleLongPressCard(BuildContext context, Gallery gallery, {Offset? position}) {
    showEHContextMenu(
      context,
      position: position,
      actions: [
        EHContextMenuAction(
          text: 'delete'.tr,
          color: UIConfig.alertColor(context),
          onTap: () => delete(gallery.gid),
        ),
      ],
    );
  }

  @override
  void handleSecondaryTapCard(BuildContext context, Gallery gallery, {Offset? position}) {
    handleLongPressCard(context, gallery, position: position);
  }

  Future<void> delete(int gid) async {
    await historyService.delete(gid);
    state.galleries.removeWhere((g) => g.gid == gid);
    updateSafely([bodyId]);
  }
}
