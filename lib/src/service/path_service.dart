import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'jh_service.dart';

PathService pathService = PathService();

class PathService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const int android16SdkInt = 36;

  /// visible for all
  late Directory tempDir;

  /// visible on ios&windows&macos
  Directory? appDocDir;

  /// visible on windows
  Directory? appSupportDir;

  /// visible on android
  Directory? externalStorageDir;

  Directory? systemDownloadDir;
  int? androidSdkInt;

  bool get isAndroid16OrAbove => Platform.isAndroid && (androidSdkInt ?? 0) >= android16SdkInt;

  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<void> doInitBean() async {
    await Future.wait([
      () async {
        tempDir = await getTemporaryDirectory();
      }(),
      () async {
        try {
          appDocDir = await getApplicationDocumentsDirectory();
        } catch (_) {}
      }(),
      () async {
        try {
          appSupportDir = await getApplicationSupportDirectory();
        } catch (_) {}
      }(),
      () async {
        try {
          externalStorageDir = await getExternalStorageDirectory();
        } catch (_) {}
      }(),
      () async {
        try {
          systemDownloadDir = await getDownloadsDirectory();
        } catch (_) {}
      }(),
      if (Platform.isAndroid)
        () async {
          try {
            androidSdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
          } catch (_) {
            androidSdkInt = _parseSdkIntFromOperatingSystemVersion();
          }
        }(),
    ]);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Directory getInternalRootDir() {
    return appSupportDir ?? appDocDir ?? tempDir;
  }

  bool isRestrictedAndroidDataPath(String rawPath) {
    if (!Platform.isAndroid || !isAndroid16OrAbove) {
      return false;
    }

    final String normalizedPath = rawPath.replaceAll('\\', '/').toLowerCase();
    return normalizedPath.contains('/android/data/');
  }

  int? _parseSdkIntFromOperatingSystemVersion() {
    final RegExpMatch? match = RegExp(r'sdk\s*(\d+)', caseSensitive: false).firstMatch(Platform.operatingSystemVersion);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  Directory getVisibleDir() {
    if (Platform.isAndroid) {
      if (isAndroid16OrAbove) {
        return getInternalRootDir();
      }
      if (externalStorageDir != null) {
        return externalStorageDir!;
      }
    }
    if (GetPlatform.isWindows && appSupportDir != null) {
      return appSupportDir!;
    }
    if (GetPlatform.isLinux && appSupportDir != null) {
      return appSupportDir!;
    }
    return appDocDir ?? appSupportDir ?? systemDownloadDir ?? tempDir;
  }
}
