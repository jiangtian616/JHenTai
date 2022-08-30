import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import '../model/gallery.dart';
import '../utils/log.dart';

class HistoryService extends GetxController {
  static const String historyUpdateId = 'historyUpdateId';

  List<Gallery> history = [];

  static const int pageSize = 25;

  int get pageCount => history.isEmpty ? 0 : (history.length - 1) ~/ pageSize + 1;

  static void init() {
    Get.put(HistoryService());
  }

  @override
  onInit() async {
    history = (await appDb.selectHistorys().get()).map((h) => Gallery.fromJson(json.decode(h.jsonBody))).toList();

    Log.debug('init HistoryService success');
    super.onInit();
  }

  List<Gallery> getByPageIndex(int pageIndex) {
    return history.sublist(pageIndex * pageSize, min((pageIndex + 1) * pageSize, history.length));
  }

  Future<void> record(Gallery? gallery) async {
    if (gallery == null) {
      return;
    }

    Log.verbose('Record history: $gallery');

    Gallery? record = history.singleWhereOrNull((h) => h.gid == gallery.gid);

    try {
      if (record == null) {
        history.insert(0, gallery);
        await appDb.insertHistory(gallery.gid, json.encode(gallery), DateTime.now().toString());
      } else {
        history.remove(record);
        history.insert(0, record);
        await appDb.updateHistoryLastReadTime(DateTime.now().toString(), gallery.gid);
      }
    } on Exception catch (e) {
      Log.error('Record history failed!', e);
      Log.error(e);
    }
  }

  Future<bool> delete(int gid) async {
    Log.info('Delete history: $gid');
    return await appDb.deleteGallery(gid) > 0;
  }

  Future<bool> deleteAll() async {
    Log.info('Delete all historys');
    history.clear();
    return await appDb.deleteAllHistorys() > 0;
  }
}
