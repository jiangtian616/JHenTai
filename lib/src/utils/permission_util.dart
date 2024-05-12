import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import 'log.dart';

Future<void> requestStoragePermission() async {
  if (!GetPlatform.isMacOS && !GetPlatform.isLinux) {
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

Future<void> requestAlbumPermission() async {
  bool statuses;
  if (Platform.isAndroid) {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;
    statuses = sdkInt < 29 ? await Permission.storage.request().isGranted : true;
  } else {
    statuses = await Permission.photosAddOnly.request().isGranted;
  }
  
  Log.info('requestPermission result: $statuses');
}

bool checkPermissionForPath(String path) {
  try {
    File file = File(join(path, 'JHenTaiTest'));
    file.createSync(recursive: true);
    file.deleteSync();
  } on FileSystemException catch (e) {
    Log.error('${'invalidPath'.tr}:$path', e);
    Log.uploadError(e, extraInfos: {'path': path});
    return false;
  }

  return true;
}
