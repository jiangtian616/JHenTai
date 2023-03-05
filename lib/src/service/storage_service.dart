import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/setting/path_setting.dart';

import '../utils/log.dart';

class StorageService extends GetxService {
  static const storageFileName = 'jhentai';

  final GetStorage _storage = GetStorage(storageFileName, PathSetting.getVisibleDir().path);

  static Future<void> init() async {
    StorageService storageService = StorageService();
    Get.put(storageService);
    await storageService._storage.initStorage;
    Log.debug('init StorageService success', false);
  }

  Future<void> write(String key, dynamic value) {
    return _storage.write(key, value);
  }

  T? read<T>(String key) {
    return _storage.read(key);
  }

  T getKeys<T>() {
    return _storage.getKeys();
  }

  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  Future<void> erase() async {
    _storage.erase();
  }
}
