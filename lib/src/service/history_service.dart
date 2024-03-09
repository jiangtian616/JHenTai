import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import '../model/gallery.dart';
import '../utils/log.dart';

class HistoryService extends GetxController {
  static const String historyUpdateId = 'historyUpdateId';

  static const int pageSize = 100;

  static void init() {
    Get.put(HistoryService(), permanent: true);
  }

  @override
  onInit() async {
    Log.debug('init HistoryService success');

    super.onInit();
  }

  Future<int> getPageCount() async {
    int totalCount = await GalleryHistoryDao.selectTotalCount();
    return totalCount == 0 ? 0 : (totalCount - 1) ~/ pageSize + 1;
  }

  Future<List<Gallery>> getByPageIndex(int pageIndex) async {
    List<GalleryHistoryData> historys = await GalleryHistoryDao.selectByPageIndex(pageIndex, pageSize);
    return historys.map((h) => Gallery.fromJson(json.decode(h.jsonBody))).toList();
  }

  Future<void> record(Gallery gallery) async {
    Log.verbose('Record history: ${gallery.gid}');

    try {
      await GalleryHistoryDao.replaceHistory(
        GalleryHistoryData(
          gid: gallery.gid,
          jsonBody: json.encode(gallery),
          lastReadTime: DateTime.now().toString(),
        ),
      );
    } on Exception catch (e) {
      Log.error('Record history failed!', e);
    }
  }

  Future<bool> delete(int gid) async {
    Log.info('Delete history: $gid');

    return await GalleryHistoryDao.deleteHistory(gid) > 0;
  }

  Future<bool> deleteAll() async {
    Log.info('Delete all historys');
    return await GalleryHistoryDao.deleteAllHistory() > 0;
  }
}
