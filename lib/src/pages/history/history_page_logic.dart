import 'package:get/get.dart';

import '../../service/history_service.dart';
import '../../utils/log.dart';
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

  Future<void> deleteAll() async {
    await historyService.deleteAll();
    clearAndRefresh();
  }

  void updateBody() {
    update([bodyId]);
  }
}
