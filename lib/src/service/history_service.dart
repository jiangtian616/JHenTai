import 'dart:convert';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/model/gallery_history_model.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import '../model/gallery.dart';
import '../utils/log.dart';

class HistoryService extends GetxController {
  static const String historyUpdateId = 'historyUpdateId';

  static const int pageSize = 100;

  static void init() {
    Get.put(HistoryService(), permanent: true);
  }

  @override
  Future<void> onInit() async {
    Log.debug('init HistoryService success');

    super.onInit();
  }

  Future<int> getPageCount() async {
    int totalCount = await GalleryHistoryDao.selectTotalCount();
    return totalCount == 0 ? 0 : (totalCount - 1) ~/ pageSize + 1;
  }


  Future<List<GalleryHistoryModel>> getByPageIndex(int pageIndex) async {
    List<GalleryHistoryV2Data> historys = await GalleryHistoryDao.selectByPageIndex(pageIndex, pageSize);
    return historys.map<GalleryHistoryModel>((h) => GalleryHistoryModel.fromJson(jsonDecode(h.jsonBody))).toList();
  }

  Future<List<GalleryHistoryModel>> getAllHistory() async {
    List<GalleryHistoryV2Data> historys = await GalleryHistoryDao.selectAll();
    return IsolateService.run<List<GalleryHistoryV2Data>, List<GalleryHistoryModel>>(
      (historys) => historys.map<GalleryHistoryModel>((h) => GalleryHistoryModel.fromJson(jsonDecode(h.jsonBody))).toList(),
      historys,
    );
  }

  Future<void> record(GalleryHistoryModel gallery) async {
    Log.trace('Record history: ${gallery.galleryUrl.gid}');

    try {
      await GalleryHistoryDao.replaceHistory(
        GalleryHistoryV2Data(
          gid: gallery.galleryUrl.gid,
          jsonBody: jsonEncode(gallery),
          lastReadTime: DateTime.now().toString(),
        ),
      );
    } on Exception catch (e) {
      Log.error('Record history failed!', e);
    }
  }

  Future<void> batchRecord(List<GalleryHistoryModel> gallerys) async {
    Log.trace('Batch record history: $gallerys');

    try {
      for (List<GalleryHistoryModel> partition in gallerys.partition(500)) {
        await GalleryHistoryDao.batchReplaceHistory(
          partition
              .map(
                (gallery) => GalleryHistoryV2Data(
                  gid: gallery.galleryUrl.gid,
                  jsonBody: jsonEncode(gallery),
                  lastReadTime: DateTime.now().toString(),
                ),
              )
              .toList(),
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }
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
