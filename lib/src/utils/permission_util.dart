import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import 'log.dart';

Future<void> requestPermission() async {
  if (!GetPlatform.isMacOS) {
    try {
      await Permission.manageExternalStorage.request().isGranted;
      Log.info(await Permission.manageExternalStorage.status);
    } on Exception catch (e) {
      Log.error('Request manageExternalStorage permission failed!', e);
    }

    try {
      await Permission.storage.request().isGranted;
      Log.info(await Permission.storage.status);
    } on Exception catch (e) {
      Log.error('Request storage permission failed!', e);
    }
  }
}

bool checkPermissionForPath(String path) {
  try {
    File file = File(join(path, 'JHenTaiTest'));
    file.createSync(recursive: true);
    file.deleteSync();
  } on FileSystemException catch (e) {
    Log.error('${'invalidPath'.tr}:$path', e);
    Log.upload(e, extraInfos: {'path': path});
    return false;
  }

  return true;
}
