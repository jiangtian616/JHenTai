import 'dart:io';

import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:path/path.dart';

import 'log.dart';
import 'jh_service.dart';

StorageService storageService = StorageService();

class StorageService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String storageFileName = 'jhentai';

  late final GetStorage _storage;

  @override
  Future<void> doOnInit() async {
    _migrateOldConfigFile();
    _storage = GetStorage(storageFileName, pathService.getVisibleDir().path);
    await _storage.initStorage;
  }

  @override
  void doOnReady() {}

  Future<void> write(String key, dynamic value) {
    return _storage.write(key, value);
  }

  T? read<T>(String key) {
    return _storage.read(key);
  }

  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  void _migrateOldConfigFile() {
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
      log.uploadError(e);
    }
  }
}
