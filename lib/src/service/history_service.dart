import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';

import '../model/gallery.dart';
import '../utils/log.dart';

class HistoryService extends GetxService {
  final StorageService storageService = Get.find();

  List<Gallery> history = [];

  static void init() {
    Get.put(HistoryService());
    Log.verbose('init HistoryService success', false);
  }

  @override
  void onInit() {
    List<Gallery>? gallerys = storageService.read<List>('history')?.map((e) => Gallery.fromJson(e)).toList();
    if (gallerys == null) {
      history = <Gallery>[];
    } else {
      history = gallerys;
    }
    super.onInit();
  }

  void record(Gallery gallery) {
    history.removeWhere((element) => element.gid == gallery.gid);
    history.insert(0, gallery);
    storageService.write('history', history);
  }

  void clear() {
    history.clear();
    storageService.remove('history');
  }
}
