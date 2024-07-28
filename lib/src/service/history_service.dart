import 'dart:convert';

import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'jh_service.dart';
import 'log.dart';

HistoryService historyService = HistoryService();

class HistoryService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String historyUpdateId = 'historyUpdateId';

  static const int pageSize = 100;

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {}

  Future<int> getPageCount() async {
    int totalCount = await GalleryHistoryDao.selectTotalCount();
    return totalCount == 0 ? 0 : (totalCount - 1) ~/ pageSize + 1;
  }

  Future<List<GalleryHistoryModel>> getByPageIndex(int pageIndex) async {
    List<GalleryHistoryV2Data> historys = await GalleryHistoryDao.selectByPageIndex(pageIndex, pageSize);
    return historys.map<GalleryHistoryModel>((h) => GalleryHistoryModel.fromJson(jsonDecode(h.jsonBody))).toList();
  }

  Future<List<GalleryHistoryV2Data>> getLatest10000RawHistory() async {
    return appDb.managers.galleryHistoryV2.orderBy((o) => o.lastReadTime.desc() & o.gid.desc()).limit(10000).get();
  }

  Future<void> record(GalleryHistoryModel gallery) async {
    log.trace('Record history: ${gallery.galleryUrl.gid}');

    try {
      await GalleryHistoryDao.replaceHistory(
        GalleryHistoryV2Data(
          gid: gallery.galleryUrl.gid,
          jsonBody: jsonEncode(gallery),
          lastReadTime: DateTime.now().toString(),
        ),
      );
    } on Exception catch (e) {
      log.error('Record history failed!', e);
    }
  }

  Future<void> batchRecord(List<GalleryHistoryV2Data> gallerys) async {
    log.trace('Batch record history, size: ${gallerys.length}');

    try {
      for (List<GalleryHistoryV2Data> partition in gallerys.partition(2000)) {
        await GalleryHistoryDao.batchReplaceHistory(partition);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } on Exception catch (e) {
      log.error('Record history failed!', e);
    }
  }

  Future<bool> delete(int gid) async {
    log.info('Delete history: $gid');

    return await GalleryHistoryDao.deleteHistory(gid) > 0;
  }

  Future<bool> deleteAll() async {
    log.info('Delete all historys');
    return await GalleryHistoryDao.deleteAllHistory() > 0;
  }
}
