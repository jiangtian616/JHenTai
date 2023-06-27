import 'package:get/get.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart';

import '../service/storage_service.dart';

class DownloadSetting {
  static String defaultDownloadPath = join(PathSetting.getVisibleDir().path, 'download');
  static RxString downloadPath = defaultDownloadPath.obs;
  static RxnBool downloadOriginalImageByDefault = RxnBool(UserSetting.hasLoggedIn() ? false : null);
  static String defaultExtraGalleryScanPath = join(PathSetting.getVisibleDir().path, 'local_gallery');
  static RxList<String> extraGalleryScanPath = <String>[defaultExtraGalleryScanPath].obs;
  static RxString singleImageSavePath = join(PathSetting.getVisibleDir().path, 'save').obs;
  static RxInt downloadTaskConcurrency = 6.obs;
  static RxInt maximum = 2.obs;
  static Rx<Duration> period = const Duration(seconds: 1).obs;
  static RxInt timeout = 20.obs;
  static RxBool downloadInOrderOfInsertTime = true.obs;
  static RxBool deleteArchiveFileAfterDownload = true.obs;

  static void init() {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('downloadSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init DownloadSetting success', false);
    } else {
      Log.debug('init DownloadSetting success: default', false);
    }

    /// listen to login and logout
    ever(UserSetting.ipbMemberId, (v) {
      if (UserSetting.hasLoggedIn()) {
        saveDownloadOriginalImageByDefault(false);
      } else {
        saveDownloadOriginalImageByDefault(null);
      }
    });
  }

  static saveDownloadPath(String downloadPath) {
    Log.debug('saveDownloadPath:$downloadPath');
    DownloadSetting.downloadPath.value = downloadPath;
    _save();
  }

  static addExtraGalleryScanPath(String newPath) {
    Log.debug('addExtraGalleryScanPath:$newPath');
    extraGalleryScanPath.add(newPath);
    _save();
  }

  static removeExtraGalleryScanPath(String path) {
    Log.debug('removeExtraGalleryScanPath:$path');
    extraGalleryScanPath.remove(path);
    _save();
  }

  static saveSingleImageSavePath(String singleImageSavePath) {
    Log.debug('saveSingleImageSavePath:$singleImageSavePath');
    DownloadSetting.singleImageSavePath.value = singleImageSavePath;
    _save();
  }

  static saveDownloadOriginalImageByDefault(bool? value) {
    Log.debug('saveDownloadOriginalImageByDefault:$value');
    DownloadSetting.downloadOriginalImageByDefault.value = value;
    _save();
  }

  static saveDownloadTaskConcurrency(int downloadTaskConcurrency) {
    Log.debug('saveDownloadTaskConcurrency:$downloadTaskConcurrency');
    DownloadSetting.downloadTaskConcurrency.value = downloadTaskConcurrency;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static saveMaximum(int maximum) {
    Log.debug('saveMaximum:$maximum');
    DownloadSetting.maximum.value = maximum;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static savePeriod(Duration period) {
    Log.debug('savePeriod:$period');
    DownloadSetting.period.value = period;
    _save();

    Get.find<GalleryDownloadService>().updateExecutor();
  }

  static saveTimeout(int value) {
    Log.debug('saveTimeout:$value');
    timeout.value = value;
    _save();
  }

  static saveDownloadInOrderOfInsertTime(bool value) {
    Log.debug('saveDownloadInOrderOfInsertTime:$value');
    downloadInOrderOfInsertTime.value = value;
    _save();
  }

  static saveDeleteArchiveFileAfterDownload(bool value) {
    Log.debug('saveDeleteArchiveFileAfterDownload:$value');
    deleteArchiveFileAfterDownload.value = value;
    _save();
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('downloadSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'downloadPath': downloadPath.value,
      'extraGalleryScanPath': extraGalleryScanPath.value,
      'singleImageSavePath': singleImageSavePath.value,
      'downloadOriginalImageByDefault': downloadOriginalImageByDefault.value,
      'downloadTaskConcurrency': downloadTaskConcurrency.value,
      'maximum': maximum.value,
      'period': period.value.inMilliseconds,
      'timeout': timeout.value,
      'downloadInOrderOfInsertTime': downloadInOrderOfInsertTime.value,
      'deleteArchiveFileAfterDownload': deleteArchiveFileAfterDownload.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    if (!GetPlatform.isIOS) {
      downloadPath.value = map['downloadPath'] ?? downloadPath.value;
    }
    if (map['extraGalleryScanPath'] != null) {
      extraGalleryScanPath.addAll(map['extraGalleryScanPath'].cast<String>());
      extraGalleryScanPath.value = extraGalleryScanPath.toSet().toList();
    }
    singleImageSavePath.value = map['singleImageSavePath'] ?? singleImageSavePath.value;
    downloadOriginalImageByDefault.value = map['downloadOriginalImageByDefault'] ?? downloadOriginalImageByDefault.value;
    downloadTaskConcurrency.value = map['downloadTaskConcurrency'];
    maximum.value = map['maximum'];
    period.value = Duration(milliseconds: map['period']);
    timeout.value = map['timeout'];
    downloadInOrderOfInsertTime.value = map['downloadInOrderOfInsertTime'] ?? downloadInOrderOfInsertTime.value;
    deleteArchiveFileAfterDownload.value = map['deleteArchiveFileAfterDownload'] ?? deleteArchiveFileAfterDownload.value;
  }
}
