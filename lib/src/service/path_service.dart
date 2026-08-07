import 'dart:io';

import 'package:extended_image/extended_image.dart'
    show extendedImageDiskCacheDirectory;
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'jh_service.dart';

PathService pathService = PathService();

class PathService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  /// Smart cache (pages + images) lives in a dedicated folder inside temp.
  static const String smartCacheFolderName = 'autotemp';

  /// Unified data root inside the documents folder: Documents/JHTData.
  late Directory jhDataDir;

  /// Temporary/page cache directory: Documents/JHTData/temp.
  late Directory tempDir;

  /// Super-resolution model directory: Documents/JHTData/SRmodel.
  late Directory jhSrModelDir;

  /// OCR / translation model & virtual environment directory:
  /// Documents/JHTData/OCRmodel.
  late Directory jhOcrModelDir;

  /// Gallery download directory: Documents/JHTData/download.
  late Directory jhDownloadDir;

  /// visible on ios&windows&macos
  Directory? appDocDir;

  /// visible on windows
  Directory? appSupportDir;

  /// visible on android
  Directory? externalStorageDir;

  Directory? systemDownloadDir;

  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<void> doInitBean() async {
    await Future.wait([
      getApplicationDocumentsDirectory().then<Directory?>((value) {
        appDocDir = value;
        return value;
      }).catchError((Object error) => null),
      getApplicationSupportDirectory().then<Directory?>((value) {
        appSupportDir = value;
        return value;
      }).catchError((Object error) => null),
      getExternalStorageDirectory().then<Directory?>((value) {
        externalStorageDir = value;
        return value;
      }).catchError((Object error) => null),
      getDownloadsDirectory().then<Directory?>((value) {
        systemDownloadDir = value;
        return value;
      }).catchError((Object error) => null),
    ]);

    final Directory baseDir = appDocDir ?? getVisibleDir();
    jhDataDir = Directory(join(baseDir.path, 'JHTData'));
    tempDir = Directory(join(jhDataDir.path, 'temp'));
    jhSrModelDir = Directory(join(jhDataDir.path, 'SRmodel'));
    jhOcrModelDir = Directory(join(jhDataDir.path, 'OCRmodel'));
    jhDownloadDir = Directory(join(jhDataDir.path, 'download'));

    await Future.wait([
      jhDataDir.create(recursive: true),
      tempDir.create(recursive: true),
      Directory(join(tempDir.path, smartCacheFolderName))
          .create(recursive: true),
      jhSrModelDir.create(recursive: true),
      jhOcrModelDir.create(recursive: true),
      jhDownloadDir.create(recursive: true),
    ]);

    extendedImageDiskCacheDirectory =
        join(tempDir.path, smartCacheFolderName);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Directory getVisibleDir() {
    if (Platform.isAndroid && externalStorageDir != null) {
      return externalStorageDir!;
    }
    if (GetPlatform.isWindows && appSupportDir != null) {
      return appSupportDir!;
    }
    if (GetPlatform.isLinux && appSupportDir != null) {
      return appSupportDir!;
    }
    return appDocDir ?? appSupportDir ?? systemDownloadDir!;
  }
}
