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

Future<List<PermissionStatus>> checkAndRequestPermissions({MediaType mediaType = MediaType.image}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    // Only Android and iOS platforms are supported
    return [PermissionStatus.denied];
  }

  if (Platform.isAndroid) {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    if (sdkInt < 33) {
      return Future.wait([Permission.storage.request()]);
    }

    switch (mediaType) {
      case MediaType.image:
        return Future.wait([Permission.photos.request()]);
      case MediaType.video:
        return Future.wait([Permission.videos.request()]);
      case MediaType.audio:
        return Future.wait([Permission.audio.request()]);
    }
  } else {
    // iOS permission for saving images to the gallery
    return Future.wait([Permission.photos.request(), Permission.photosAddOnly.request()]);
  }
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
