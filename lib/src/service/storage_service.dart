import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:path/path.dart';

import '../utils/log.dart';

class StorageService extends GetxService {
  static const storageFileName = 'jhentai';

  final GetStorage _storage = GetStorage(storageFileName, pathService.getVisibleDir().path);

  static Future<void> init() async {
    _migrateOldConfigFile();

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

  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  static void _migrateOldConfigFile() {
    try {
      File oldConfigFile = File(join(pathService.getVisibleDir().path, '.GetStorage.gs'));
      File oldBakFile = File(join(pathService.getVisibleDir().path, '.GetStorage.bak'));
      if (oldConfigFile.existsSync()) {
        oldConfigFile.copySync(join(pathService.getVisibleDir().path, 'jhentai.gs'));
        oldConfigFile.delete();
      }
      if (oldBakFile.existsSync()) {
        oldBakFile.copySync(join(pathService.getVisibleDir().path, 'jhentai.bak'));
        oldBakFile.delete();
      }
    } on Exception catch (e) {
      Log.uploadError(e);
    }
  }
}
