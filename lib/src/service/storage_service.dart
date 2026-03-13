import 'dart:io';

import 'package:get_storage/get_storage.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:path/path.dart';

import 'log.dart';
import 'jh_service.dart';

StorageService storageService = StorageService();

class StorageService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String storageFileName = 'jhentai';

  GetStorage? _storage;
  bool _storageAvailable = false;

  Directory _resolveStorageBaseDir() {
    if (pathService.isAndroid16OrAbove) {
      return pathService.getInternalRootDir();
    }

    return pathService.appSupportDir ?? pathService.appDocDir ?? pathService.externalStorageDir ?? pathService.tempDir;
  }

  @override
  Future<void> doInitBean() async {
    final Directory storageDir = Directory(join(_resolveStorageBaseDir().path, 'storage'));
    try {
      await storageDir.create(recursive: true);
      await _migrateOldConfigFile(storageDir);

      _storage = GetStorage(storageFileName, storageDir.path);
      await _storage!.initStorage;
      _storageAvailable = true;
    } catch (e, s) {
      _storageAvailable = false;
      _storage = null;
      log.error('Init StorageService failed, fallback to disabled storage', e, s);
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> write(String key, dynamic value) {
    if (!_storageAvailable || _storage == null) {
      return Future.value();
    }

    try {
      return _storage!.write(key, value);
    } catch (e, s) {
      log.error('StorageService write failed: $key', e, s);
      return Future.value();
    }
  }

  T? read<T>(String key) {
    if (!_storageAvailable || _storage == null) {
      return null;
    }

    try {
      return _storage!.read(key);
    } catch (e, s) {
      log.error('StorageService read failed: $key', e, s);
      return null;
    }
  }

  Iterable<String>? getKeys() {
    if (!_storageAvailable || _storage == null) {
      return null;
    }

    try {
      return _storage!.getKeys().whereType<String>();
    } catch (e, s) {
      log.error('StorageService getKeys failed', e, s);
      return null;
    }
  }
  
  Future<void> remove(String key) async {
    if (!_storageAvailable || _storage == null) {
      return;
    }

    try {
      _storage!.remove(key);
    } catch (e, s) {
      log.error('StorageService remove failed: $key', e, s);
    }
  }

  Future<void> _migrateOldConfigFile(Directory targetDir) async {
    if (pathService.isAndroid16OrAbove) {
      return;
    }

    final File targetConfig = File(join(targetDir.path, '$storageFileName.gs'));
    final File targetBak = File(join(targetDir.path, '$storageFileName.bak'));
    final List<Directory> legacyDirs = [
      if (pathService.externalStorageDir != null) pathService.externalStorageDir!,
      if (pathService.appDocDir != null) pathService.appDocDir!,
      if (pathService.appSupportDir != null) pathService.appSupportDir!,
    ];

    Future<void> copyFirstExisting(List<File> candidates, File target) async {
      if (await target.exists()) {
        return;
      }

      for (File source in candidates) {
        if (source.path == target.path) {
          continue;
        }

        try {
          if (await source.exists()) {
            await target.parent.create(recursive: true);
            await source.copy(target.path);
            return;
          }
        } catch (_) {
          continue;
        }
      }
    }

    try {
      await copyFirstExisting(
        legacyDirs
            .expand((dir) => [
                  File(join(dir.path, '$storageFileName.gs')),
                  File(join(dir.path, '.GetStorage.gs')),
                ])
            .toList(),
        targetConfig,
      );
      await copyFirstExisting(
        legacyDirs
            .expand((dir) => [
                  File(join(dir.path, '$storageFileName.bak')),
                  File(join(dir.path, '.GetStorage.bak')),
                ])
            .toList(),
        targetBak,
      );
    } catch (e, s) {
      log.error('Migrate old GetStorage files failed', e, s);
    }
  }
}
