import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:path/path.dart';

import '../setting/download_setting.dart';
import '../setting/preference_setting.dart';
import '../utils/locale_util.dart';
import '../utils/log.dart';

class AppUpdateService extends GetxService {
  static const int appVersion = 4 ;

  static void init() {
    Get.put(AppUpdateService(), permanent: true);
  }

  @override
  void onInit() async {
    super.onInit();

    File file = File(join(PathSetting.getVisibleDir().path, 'jhentai.version'));
    if (!file.existsSync()) {
      file.create().then((_) => file.writeAsString(appVersion.toString()));
      handleFirstOpen();
      return;
    }

    String? version = file.readAsStringSync();
    file.writeAsString(appVersion.toString());
    if (isEmptyOrNull(version)) {
      return;
    }

    int? oldVersion = int.tryParse(version);
    if (oldVersion == null) {
      return;
    }

    if (appVersion > oldVersion) {
      handleAppUpdateWhenInit(oldVersion);
      handleAppUpdateWhenReady(oldVersion);
    }
  }

  void handleFirstOpen() {
    Get.engine.addPostFrameCallback((_) {
      if (PreferenceSetting.locale.value.languageCode == 'zh') {
        PreferenceSetting.saveEnableTagZHTranslation(true);
        Get.find<TagTranslationService>().refresh();
      }
    });
  }

  void handleAppUpdateWhenInit(int oldVersion) {
    try {
      if (oldVersion < 4) {
        File(join(PathSetting.getVisibleDir().path, '.GetStorage.gs')).copySync(join(PathSetting.getVisibleDir().path, 'jhentai.gs'));
        File(join(PathSetting.getVisibleDir().path, '.GetStorage.bak')).copySync(join(PathSetting.getVisibleDir().path, 'jhentai.bak'));
      }
    } on Exception catch (e) {
      Log.upload(e);
    }
  }

  void handleAppUpdateWhenReady(int oldVersion) {
    Get.engine.addPostFrameCallback((_) {
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
    });
  }
}
