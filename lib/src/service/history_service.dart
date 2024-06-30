import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import '../model/gallery.dart';
import '../model/gallery_tag.dart';
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

  Future<List<Gallery>> getByPageIndex(int pageIndex) async {
    List<GalleryHistoryData> historys = await GalleryHistoryDao.selectByPageIndex(pageIndex, pageSize);
    return historys.map((h) => Gallery.fromJson(json.decode(h.jsonBody))).toList();
  }

  Future<List<Gallery>> getAllHistory() async {
    List<GalleryHistoryData> historys = await GalleryHistoryDao.selectAll();
    return historys.map((h) => Gallery.fromJson(json.decode(h.jsonBody))).toList();
  }

  Future<void> record(Gallery gallery) async {
    Log.trace('Record history: ${gallery.gid}');

    try {
      await GalleryHistoryDao.replaceHistory(
        GalleryHistoryData(
          gid: gallery.gid,
          jsonBody: gallery2jsonBody(gallery),
          lastReadTime: DateTime.now().toString(),
        ),
      );
    } on Exception catch (e) {
      Log.error('Record history failed!', e);
    }
  }

  Future<void> batchRecord(List<Gallery> gallerys) async {
    Log.trace('Batch record history: $gallerys');

    try {
      await GalleryHistoryDao.batchReplaceHistory(
        gallerys
            .map(
              (gallery) => GalleryHistoryCompanion.insert(
                gid: Value(gallery.gid),
                jsonBody: gallery2jsonBody(gallery),
                lastReadTime: DateTime.now().toString(),
              ),
            )
            .toList(),
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

  String gallery2jsonBody(Gallery gallery) {
    LinkedHashMap<String, List<GalleryTag>> thinTagsMap = LinkedHashMap();
    gallery.tags.forEach((key, value) {
      List<GalleryTag> thinTags = [];
      for (var tag in value) {
        GalleryTag thinTag = tag.copyWith();
        thinTag.tagData = thinTag.tagData.copyWith(
          fullTagName: const Value(null),
          intro: const Value(null),
          links: const Value(null),
        );
        thinTags.add(thinTag);
      }
      thinTagsMap[key] = thinTags;
    });
    Gallery thinGallery = gallery.copyWith(tags: thinTagsMap);

    return json.encode(thinGallery);
  }
}
