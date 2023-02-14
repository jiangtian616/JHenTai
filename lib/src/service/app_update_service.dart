import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:path/path.dart';

import '../setting/download_setting.dart';
import '../setting/preference_setting.dart';
import '../utils/locale_util.dart';
import '../utils/log.dart';

class AppUpdateService extends GetxService {
  StorageService storageService = Get.find();

  static const int appVersion = 3;

  static void init() {
    Get.put(AppUpdateService(), permanent: true);
  }

  @override
  void onInit() async {
    super.onInit();

    int? oldVersion = storageService.read('appVersion');
    storageService.write('appVersion', appVersion);
    Log.debug('App old version: $oldVersion, current version: $appVersion');

    if (oldVersion == null) {
      handleFirstOpen();
      return;
    }

    handleAppUpdate(oldVersion);

    if (appVersion > oldVersion) {
      Log.info('AppUpdateService update from $oldVersion to $appVersion');
      handleAppUpdate(oldVersion);
    }
  }

  void handleFirstOpen() {
    if (PreferenceSetting.locale.value.languageCode == 'zh') {
      PreferenceSetting.saveEnableTagZHTranslation(true);
      Get.find<TagTranslationService>().refresh();
    }
  }

  void handleAppUpdate(int oldVersion) async {
    if (oldVersion <= 2) {
      Log.info('Move style setting to preference setting');

      Map<String, dynamic>? styleSettingMap = Get.find<StorageService>().read<Map<String, dynamic>>('styleSetting');

      if (styleSettingMap?['locale'] != null) {
        PreferenceSetting.saveLanguage(localeCode2Locale(styleSettingMap!['locale']));
      }
      if (styleSettingMap?['enableTagZHTranslation'] != null) {
        PreferenceSetting.saveEnableTagZHTranslation(styleSettingMap!['enableTagZHTranslation']);
      }
      if (styleSettingMap?['showR18GImageDirectly'] != null) {
        PreferenceSetting.saveShowR18GImageDirectly(styleSettingMap!['showR18GImageDirectly']);
      }
      if (styleSettingMap?['enableQuickSearchDrawerGesture'] != null) {
        PreferenceSetting.saveEnableQuickSearchDrawerGesture(styleSettingMap!['enableQuickSearchDrawerGesture']);
      }
      if (styleSettingMap?['hideBottomBar'] != null) {
        PreferenceSetting.saveHideBottomBar(styleSettingMap!['hideBottomBar']);
      }
      if (styleSettingMap?['alwaysShowScroll2TopButton'] != null) {
        PreferenceSetting.saveAlwaysShowScroll2TopButton(styleSettingMap!['alwaysShowScroll2TopButton']);
      }
    }

    if (oldVersion <= 3) {
      Log.info('Rename metadata file');

      Directory downloadDir = Directory(DownloadSetting.downloadPath.value);
      downloadDir.exists().then((exists) {
        if (!exists) {
          return;
        }

        downloadDir.list().listen((entity) {
          if (entity is! Directory) {
            return;
          }

          File oldGalleryMetadataFile = File(join(entity.path, '.metadata'));
          oldGalleryMetadataFile.exists().then((exists) {
            if (exists) {
              oldGalleryMetadataFile.copy('${entity.path}/${GalleryDownloadService.metadataFileName}');
            }
          });

          File oldArchiveMetadataFile = File(join(entity.path, '.archive.metadata'));
          oldArchiveMetadataFile.exists().then((exists) {
            if (exists) {
              oldArchiveMetadataFile.copy('${entity.path}/${ArchiveDownloadService.metadataFileName}');
            }
          });
        });
      });
    }
  }
}
