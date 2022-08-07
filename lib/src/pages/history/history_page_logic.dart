import 'package:get/get.dart';

import '../../service/history_service.dart';
import '../../utils/log.dart';
import '../base/base_page_logic.dart';
import 'history_page_state.dart';

class HistoryPageLogic extends BasePageLogic {
  @override
  final String pageId = 'pageId';
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String scroll2TopButtonId = 'scroll2TopButtonId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  int get tabIndex => 6;

  @override
  bool get showJumpButton => false;

  @override
  final HistoryPageState state = HistoryPageState();

  final HistoryService historyService = Get.find();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get history data', false);

    List<dynamic> gallerysAndPageInfo = [historyService.history, historyService.history.isEmpty ? 0 : 1, null, null];
    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);

    return gallerysAndPageInfo;
  }

  void updateBody() {
    update([bodyId]);
  }
}
