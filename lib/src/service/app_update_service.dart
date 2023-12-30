import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:path/path.dart';

import '../pages/search/mixin/search_page_logic_mixin.dart';
import '../setting/download_setting.dart';
import '../setting/preference_setting.dart';
import '../utils/locale_util.dart';
import '../utils/log.dart';

class AppUpdateService extends GetxService {
  static const int appVersion = 8;

  static void init() {
    Get.put(AppUpdateService(), permanent: true);
  }

  @override
  void onInit() async {
    super.onInit();

    migrateOldConfigFile();

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

  void migrateOldConfigFile() {
    try {
      File oldConfigFile = File(join(PathSetting.getVisibleDir().path, '.GetStorage.gs'));
      File oldBakFile = File(join(PathSetting.getVisibleDir().path, '.GetStorage.bak'));
      if (oldConfigFile.existsSync()) {
        oldConfigFile.copySync(join(PathSetting.getVisibleDir().path, 'jhentai.gs'));
        oldConfigFile.delete();
      }
      if (oldBakFile.existsSync()) {
        oldBakFile.copySync(join(PathSetting.getVisibleDir().path, 'jhentai.bak'));
        oldBakFile.delete();
      }
    } on Exception catch (e) {
      Log.upload(e);
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
    try {} on Exception catch (e) {
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

      if (oldVersion <= 4) {
        Log.info('update local gallery path');

        DownloadSetting.removeExtraGalleryScanPath(DownloadSetting.defaultDownloadPath);
      }

      if (oldVersion <= 5) {
        Log.info('update read direction setting');

        if (ReadSetting.readDirection.value == ReadDirection.left2rightSinglePageFitWidth) {
          ReadSetting.saveReadDirection(ReadDirection.left2rightDoubleColumn);
        } else if (ReadSetting.readDirection.value == ReadDirection.left2rightDoubleColumn) {
          ReadSetting.saveReadDirection(ReadDirection.left2rightList);
        } else if (ReadSetting.readDirection.value == ReadDirection.left2rightList) {
          ReadSetting.saveReadDirection(ReadDirection.right2leftSinglePage);
        } else if (ReadSetting.readDirection.value == ReadDirection.right2leftSinglePage) {
          ReadSetting.saveReadDirection(ReadDirection.right2leftDoubleColumn);
        } else if (ReadSetting.readDirection.value == ReadDirection.right2leftSinglePageFitWidth) {
          ReadSetting.saveReadDirection(ReadDirection.right2leftList);
        }
      }

      if (oldVersion <= 6) {
        Log.info('migrate search config');

        StorageService storageService = Get.find<StorageService>();

        Map<String, dynamic>? map =
            storageService.read('searchConfig: DesktopSearchPageTabLogic') ?? storageService.read('searchConfig: SearchPageMobileV2Logic');
        if (map != null) {
          storageService.write('searchConfig: ${SearchPageLogicMixin.searchPageConfigKey}', map);
        }
      }

      if (oldVersion <= 7) {
        Log.info('Clear super-resulotion setting');
        SuperResolutionSetting.saveModelDirectoryPath(null);
      }
    });
  }
}
