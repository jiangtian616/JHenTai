import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import '../service/log.dart';

Future<void> requestStoragePermission() async {
  if (!GetPlatform.isMacOS && !GetPlatform.isLinux) {
    try {
      await Permission.manageExternalStorage.request().isGranted;
      log.info(await Permission.manageExternalStorage.status);
    } on Exception catch (e) {
      log.error('Request manageExternalStorage permission failed!', e);
    }

    try {
      await Permission.storage.request().isGranted;
      log.info(await Permission.storage.status);
    } on Exception catch (e) {
      log.error('Request storage permission failed!', e);
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

  log.info('requestPermission result: $statuses');
}

enum MediaType {
  image,
  video,
  audio,
}

Future<bool> checkAndRequestPermissions({MediaType mediaType = MediaType.image}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return false; // Only Android and iOS platforms are supported
  }

  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    if (sdkInt < 29) {
      return await Permission.storage.request().isGranted;
    }

    if (sdkInt < 33) {
      return await Permission.storage.request().isGranted;
    }

    switch (mediaType) {
      case MediaType.image:
        return await Permission.photos.request().isGranted;
      case MediaType.video:
        return await Permission.videos.request().isGranted;
      case MediaType.audio:
        return await Permission.audio.request().isGranted;
    }
  } else if (Platform.isIOS) {
    // iOS permission for saving images to the gallery
    return await Permission.photos.request().isGranted && await Permission.photosAddOnly.request().isGranted;
  }

  return false; // Unsupported platforms
}

bool checkPermissionForPath(String path) {
  try {
    File file = File(join(path, 'JHenTaiTest'));
    file.createSync(recursive: true);
    file.deleteSync();
  } on FileSystemException catch (e) {
    log.error('${'invalidPath'.tr}:$path', e);
    log.uploadError(e, extraInfos: {'path': path});
    return false;
  }

  return true;
}
