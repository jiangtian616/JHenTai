import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:path/path.dart';

import '../service/storage_service.dart';
import '../utils/toast_util.dart';

class DownloadSetting {
  static String defaultDownloadPath = join(pathService.getVisibleDir().path, 'download');
  static RxString downloadPath = defaultDownloadPath.obs;
  static RxBool downloadOriginalImageByDefault = false.obs;
  static RxnString defaultGalleryGroup = RxnString();
  static RxnString defaultArchiveGroup = RxnString();
  static String defaultExtraGalleryScanPath = join(pathService.getVisibleDir().path, 'local_gallery');
  static RxList<String> extraGalleryScanPath = <String>[defaultExtraGalleryScanPath].obs;
  static RxString singleImageSavePath = join(pathService.getVisibleDir().path, 'save').obs;
  static RxString tempDownloadPath = join(pathService.tempDir.path, EHConsts.appName).obs;
  static RxInt downloadTaskConcurrency = 6.obs;
  static RxInt maximum = 2.obs;
  static Rx<Duration> period = const Duration(seconds: 1).obs;
  static RxBool downloadAllGallerysOfSamePriority = false.obs;
  static RxInt archiveDownloadIsolateCount = 1.obs;
  static RxBool manageArchiveDownloadConcurrency = true.obs;
  static RxBool deleteArchiveFileAfterDownload = true.obs;
  static RxBool restoreTasksAutomatically = false.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>(ConfigEnum.downloadSetting.key);
    if (map != null) {
      _initFromMap(map);
      log.debug('init DownloadSetting success', false);
    } else {
      log.debug('init DownloadSetting success: default', false);
    }

    _ensureDownloadDirExists();
    _clearTempDownloadPath();
  }

  static saveDownloadPath(String downloadPath) {
    log.debug('saveDownloadPath:$downloadPath');
    DownloadSetting.downloadPath.value = downloadPath;
    _save();
  }

  static addExtraGalleryScanPath(String newPath) {
    log.debug('addExtraGalleryScanPath:$newPath');
    extraGalleryScanPath.add(newPath);
    _save();
  }

  static removeExtraGalleryScanPath(String path) {
    log.debug('removeExtraGalleryScanPath:$path');
    extraGalleryScanPath.remove(path);
    _save();
  }

  static saveSingleImageSavePath(String singleImageSavePath) {
    log.debug('saveSingleImageSavePath:$singleImageSavePath');
    DownloadSetting.singleImageSavePath.value = singleImageSavePath;
    _save();
  }

  static saveDownloadOriginalImageByDefault(bool value) {
    log.debug('saveDownloadOriginalImageByDefault:$value');
    DownloadSetting.downloadOriginalImageByDefault.value = value;
    _save();
  }

  static saveDefaultGalleryGroup(String? group) {
    log.debug('saveDefaultGalleryGroup:$group');
    DownloadSetting.defaultGalleryGroup.value = group;
    _save();
  }

  static saveDefaultArchiveGroup(String? group) {
    log.debug('saveDefaultArchiveGroup:$group');
    DownloadSetting.defaultArchiveGroup.value = group;
    _save();
  }

  static saveDownloadTaskConcurrency(int downloadTaskConcurrency) {
    log.debug('saveDownloadTaskConcurrency:$downloadTaskConcurrency');
    DownloadSetting.downloadTaskConcurrency.value = downloadTaskConcurrency;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static saveMaximum(int maximum) {
    log.debug('saveMaximum:$maximum');
    DownloadSetting.maximum.value = maximum;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static savePeriod(Duration period) {
    log.debug('savePeriod:$period');
    DownloadSetting.period.value = period;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static saveDownloadAllGallerysOfSamePriority(bool value) {
    log.debug('saveDownloadAllGallerysOfSamePriority:$value');
    downloadAllGallerysOfSamePriority.value = value;
    _save();
  }

  static saveArchiveDownloadIsolateCount(int count) {
    log.debug('saveArchiveDownloadIsolateCount:$count');
    archiveDownloadIsolateCount.value = count;
    _save();
  }

  static saveManageArchiveDownloadConcurrency(bool value) {
    log.debug('saveManageArchiveDownloadConcurrency:$value');
    manageArchiveDownloadConcurrency.value = value;
    _save();
  }

  static saveDeleteArchiveFileAfterDownload(bool value) {
    log.debug('saveDeleteArchiveFileAfterDownload:$value');
    deleteArchiveFileAfterDownload.value = value;
    _save();
  }

  static saveRestoreTasksAutomatically(bool value) {
    log.debug('saveRestoreTasksAutomatically:$value');
    restoreTasksAutomatically.value = value;
    _save();
  }

  static void _ensureDownloadDirExists() {
    try {
      Directory(downloadPath.value).createSync(recursive: true);
      Directory(defaultExtraGalleryScanPath).createSync(recursive: true);
      Directory(singleImageSavePath.value).createSync(recursive: true);
    } on Exception catch (e) {
      toast('brokenDownloadPathHint'.tr);
      log.error(e);
      log.uploadError(
        e,
        extraInfos: {
          'defaultDownloadPath': DownloadSetting.defaultDownloadPath,
          'downloadPath': DownloadSetting.downloadPath.value,
          'exists': pathService.getVisibleDir().existsSync(),
        },
      );
    }
  }

  static void _clearTempDownloadPath() {
    try {
      Directory directory = Directory(tempDownloadPath.value);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      Directory(tempDownloadPath.value).createSync();
    } on Exception catch (e) {
      log.error(e);
    }
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write(ConfigEnum.downloadSetting.key, _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'downloadPath': downloadPath.value,
      'extraGalleryScanPath': extraGalleryScanPath.value,
      'singleImageSavePath': singleImageSavePath.value,
      'downloadOriginalImageByDefault': downloadOriginalImageByDefault.value,
      'defaultGalleryGroup': defaultGalleryGroup.value,
      'defaultArchiveGroup': defaultArchiveGroup.value,
      'downloadTaskConcurrency': downloadTaskConcurrency.value,
      'maximum': maximum.value,
      'period': period.value.inMilliseconds,
      'downloadAllGallerysOfSamePriority': downloadAllGallerysOfSamePriority.value,
      'archiveDownloadIsolateCount': archiveDownloadIsolateCount.value,
      'manageArchiveDownloadConcurrency': manageArchiveDownloadConcurrency.value,
      'deleteArchiveFileAfterDownload': deleteArchiveFileAfterDownload.value,
      'restoreTasksAutomatically': restoreTasksAutomatically.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    if (!GetPlatform.isIOS) {
      downloadPath.value = map['downloadPath'] ?? downloadPath.value;
      singleImageSavePath.value = map['singleImageSavePath'] ?? singleImageSavePath.value;
    }
    if (map['extraGalleryScanPath'] != null) {
      extraGalleryScanPath.addAll(map['extraGalleryScanPath'].cast<String>());
      extraGalleryScanPath.value = extraGalleryScanPath.toSet().toList();
    }
    downloadOriginalImageByDefault.value = map['downloadOriginalImageByDefault'] ?? downloadOriginalImageByDefault.value;
    defaultGalleryGroup.value = map['defaultGalleryGroup'];
    defaultArchiveGroup.value = map['defaultArchiveGroup'];
    downloadTaskConcurrency.value = map['downloadTaskConcurrency'];
    maximum.value = map['maximum'];
    period.value = Duration(milliseconds: map['period']);
    downloadAllGallerysOfSamePriority.value = map['downloadAllGallerysOfSamePriority'] ?? downloadAllGallerysOfSamePriority.value;
    archiveDownloadIsolateCount.value = map['archiveDownloadIsolateCount'] ?? archiveDownloadIsolateCount.value;
    if (archiveDownloadIsolateCount.value > 10) {
      archiveDownloadIsolateCount.value = 10;
    }
    manageArchiveDownloadConcurrency.value = map['manageArchiveDownloadConcurrency'] ?? manageArchiveDownloadConcurrency.value;
    deleteArchiveFileAfterDownload.value = map['deleteArchiveFileAfterDownload'] ?? deleteArchiveFileAfterDownload.value;
    restoreTasksAutomatically.value = map['restoreTasksAutomatically'] ?? restoreTasksAutomatically.value;
  }
}
