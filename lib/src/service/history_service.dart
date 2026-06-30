import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'jh_service.dart';
import 'log.dart';

HistoryService historyService = HistoryService();

class HistoryService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String historyUpdateId = 'historyUpdateId';

  static const int pageSize = 100;

  final Set<int> _visitedGids = {};
  final Set<int> _unvisitedGids = {};

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<int> getPageCount() async {
    int totalCount = await GalleryHistoryDao.selectTotalCount();
    return totalCount == 0 ? 0 : (totalCount - 1) ~/ pageSize + 1;
  }

  Future<List<GalleryHistoryModel>> getByPageIndex(int pageIndex) async {
    List<GalleryHistoryV2Data> historys =
        await GalleryHistoryDao.selectByPageIndex(pageIndex, pageSize);
    return historys
        .map<GalleryHistoryModel>(
            (h) => GalleryHistoryModel.fromJson(jsonDecode(h.jsonBody)))
        .toList();
  }

  Future<List<GalleryHistoryV2Data>> getLatest10000RawHistory() async {
    return appDb.managers.galleryHistoryV2
        .orderBy((o) => o.lastReadTime.desc() & o.gid.desc())
        .limit(10000)
        .get();
  }

  Future<void> record(GalleryHistoryModel gallery) async {
    int gid = gallery.galleryUrl.gid;
    log.trace('Record history: $gid');

    _visitedGids.add(gid);
    _unvisitedGids.remove(gid);
    updateSafely(['$historyUpdateId::$gid']);

    try {
      await GalleryHistoryDao.replaceHistory(
        GalleryHistoryV2Data(
          gid: gid,
          jsonBody: jsonEncode(gallery),
          lastReadTime: DateTime.now().toString(),
        ),
      );
    } on Exception catch (e) {
      log.error('Record history failed!', e);
    }
  }

  Future<bool> hasVisited(int gid) async {
    if (_visitedGids.contains(gid)) {
      return true;
    }
    if (_unvisitedGids.contains(gid)) {
      return false;
    }

    bool hasVisited = await GalleryHistoryDao.contains(gid);
    if (hasVisited) {
      _visitedGids.add(gid);
    } else {
      _unvisitedGids.add(gid);
    }
    return hasVisited;
  }

  Future<void> batchRecord(List<GalleryHistoryV2Data> gallerys) async {
    log.trace('Batch record history, size: ${gallerys.length}');

    try {
      for (List<GalleryHistoryV2Data> partition in gallerys.partition(2000)) {
        await GalleryHistoryDao.batchReplaceHistory(partition);
        _visitedGids.addAll(partition.map((gallery) => gallery.gid));
        _unvisitedGids.removeAll(partition.map((gallery) => gallery.gid));
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } on Exception catch (e) {
      log.error('Record history failed!', e);
    }
  }

  Future<bool> delete(int gid) async {
    log.info('Delete history: $gid');

    bool deleted = await GalleryHistoryDao.deleteHistory(gid) > 0;
    if (deleted) {
      _visitedGids.remove(gid);
      _unvisitedGids.add(gid);
      updateSafely(['$historyUpdateId::$gid']);
    }
    return deleted;
  }

  Future<bool> deleteAll() async {
    log.info('Delete all historys');
    bool deleted = await GalleryHistoryDao.deleteAllHistory() > 0;
    if (deleted) {
      Set<int> visitedGids = {..._visitedGids};
      _visitedGids.clear();
      _unvisitedGids.clear();
      updateSafely(visitedGids.map((gid) => '$historyUpdateId::$gid').toList());
      updateSafely();
    }
    return deleted;
  }
}
