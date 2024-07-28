import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/local_block_rule_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:path/path.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import '../pages/search/mixin/search_page_logic_mixin.dart';
import '../setting/advanced_setting.dart';
import '../setting/download_setting.dart';
import '../setting/favorite_setting.dart';
import '../setting/mouse_setting.dart';
import '../setting/network_setting.dart';
import '../setting/performance_setting.dart';
import '../setting/preference_setting.dart';
import '../setting/security_setting.dart';
import '../setting/site_setting.dart';
import '../setting/style_setting.dart';
import '../setting/user_setting.dart';
import '../utils/locale_util.dart';
import 'jh_service.dart';
import 'log.dart';
import '../utils/uuid_util.dart';

AppUpdateService appUpdateService = AppUpdateService();

class AppUpdateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late File file;
  int? fromVersion;
  static const int toVersion = 12;

  List<UpdateHandler> updateHandlers = [
    FirstOpenHandler(),
    StyleSettingMigrateHandler(),
    RenameMetadataHandler(),
    UpdateLocalGalleryPathHandler(),
    UpdateReadDirectionHandler(),
    MigrateSearchConfigHandler(),
    ClearSuperResolutionSettingHandler(),
    MigrateCookieHandler(),
    MigrateLocalFilterTagsHandler(),
    MigrateGalleryHistoryHandler(),
    MigrateStorageConfigHandler(),
  ];

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll(updateHandlers.map((h) => h.initDependencies).expand((e) => e));

  @override
  Future<void> doInitBean() async {
    file = File(join(pathService.getVisibleDir().path, 'jhentai.version'));
    if (file.existsSync()) {
      fromVersion = int.tryParse(await file.readAsString());
    } else {
      file.create().then((_) => file.writeAsString(toVersion.toString()));
    }

    log.debug('AppUpdateService fromVersion: $fromVersion, toVersion: $toVersion');

    List<UpdateHandler> matchHandlers = [];
    for (UpdateHandler handler in updateHandlers) {
      if (await handler.match(fromVersion, toVersion)) {
        matchHandlers.add(handler);
        try {
          await handler.onInit();
        } on Exception catch (e) {
          log.error('UpdateHandler $handler onInit error', e);
        }
      }
    }
    updateHandlers = matchHandlers;
  }

  @override
  Future<void> doAfterBeanReady() async {
    List<Future> futures = [];

    for (UpdateHandler handler in updateHandlers) {
      futures.add(handler.onReady().onError((e, s) {
        log.error('UpdateHandler $handler onReady error', e, s);
      }));
    }

    await Future.wait(futures);

    await file.writeAsString(toVersion.toString());
  }
}

abstract interface class UpdateHandler {
  List<JHLifeCircleBean> get initDependencies;

  Future<bool> match(int? fromVersion, int toVersion);

  Future<void> onInit();

  Future<void> onReady();
}

class FirstOpenHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion == null || (await localConfigService.read(configKey: ConfigEnum.firstOpenInited) == null);
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onReady() async {
    if (preferenceSetting.locale.value.languageCode == 'zh') {
      preferenceSetting.saveEnableTagZHTranslation(true);
      tagTranslationService.fetchDataFromGithub();
    }

    localConfigService.write(configKey: ConfigEnum.firstOpenInited, value: 'true');
  }
}

class StyleSettingMigrateHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [storageService];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 2;
  }

  @override
  Future<void> onInit() async {
    log.info('StyleSettingMigrateHandler onInit');

    Map<String, dynamic>? styleSettingMap = storageService.read<Map<String, dynamic>>(ConfigEnum.styleSetting.key);

    if (styleSettingMap?['locale'] != null) {
      preferenceSetting.saveLanguage(localeCode2Locale(styleSettingMap!['locale']));
    }
    if (styleSettingMap?['enableTagZHTranslation'] != null) {
      preferenceSetting.saveEnableTagZHTranslation(styleSettingMap!['enableTagZHTranslation']);
    }
    if (styleSettingMap?['showR18GImageDirectly'] != null) {
      preferenceSetting.saveShowR18GImageDirectly(styleSettingMap!['showR18GImageDirectly']);
    }
    if (styleSettingMap?['enableQuickSearchDrawerGesture'] != null) {
      preferenceSetting.saveEnableQuickSearchDrawerGesture(styleSettingMap!['enableQuickSearchDrawerGesture']);
    }
    if (styleSettingMap?['hideBottomBar'] != null) {
      preferenceSetting.saveHideBottomBar(styleSettingMap!['hideBottomBar']);
    }
  }

  @override
  Future<void> onReady() async {}
}

class RenameMetadataHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [downloadSetting];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    if (fromVersion == null) {
      await localConfigService.write(configKey: ConfigEnum.renameDownloadMetadata, value: 'true');
      return false;
    } else {
      return fromVersion <= 3 || (await localConfigService.read(configKey: ConfigEnum.renameDownloadMetadata) == null);
    }
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onReady() async {
    log.info('RenameMetadataHandler onReady');

    Directory downloadDir = Directory(downloadSetting.downloadPath.value);
    if (await downloadDir.exists()) {
      downloadDir.list().listen(
        (entity) async {
          if (entity is! Directory) {
            return;
          }

          File oldGalleryMetadataFile = File(join(entity.path, '.metadata'));
          if (await oldGalleryMetadataFile.exists()) {
            oldGalleryMetadataFile.copy('${entity.path}/${GalleryDownloadService.metadataFileName}');
          }

          File oldArchiveMetadataFile = File(join(entity.path, '.archive.metadata'));
          if (await oldArchiveMetadataFile.exists()) {
            oldArchiveMetadataFile.copy('${entity.path}/${ArchiveDownloadService.metadataFileName}');
          }
        },
        onDone: () async {
          await localConfigService.write(configKey: ConfigEnum.renameDownloadMetadata, value: 'true');
        },
      );
    }
  }
}

class UpdateLocalGalleryPathHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [downloadSetting];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 4;
  }

  @override
  Future<void> onInit() async {
    log.info('UpdateLocalGalleryPathHandler onInit');
    downloadSetting.removeExtraGalleryScanPath(downloadSetting.defaultDownloadPath);
  }

  @override
  Future<void> onReady() async {}
}

class UpdateReadDirectionHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 5;
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onReady() async {
    log.info('UpdateReadDirectionHandler onReady');

    if (readSetting.readDirection.value == ReadDirection.left2rightSinglePageFitWidth) {
      readSetting.saveReadDirection(ReadDirection.left2rightDoubleColumn);
    } else if (readSetting.readDirection.value == ReadDirection.left2rightDoubleColumn) {
      readSetting.saveReadDirection(ReadDirection.left2rightList);
    } else if (readSetting.readDirection.value == ReadDirection.left2rightList) {
      readSetting.saveReadDirection(ReadDirection.right2leftSinglePage);
    } else if (readSetting.readDirection.value == ReadDirection.right2leftSinglePage) {
      readSetting.saveReadDirection(ReadDirection.right2leftDoubleColumn);
    } else if (readSetting.readDirection.value == ReadDirection.right2leftSinglePageFitWidth) {
      readSetting.saveReadDirection(ReadDirection.right2leftList);
    }
  }
}

class MigrateSearchConfigHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 6;
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onReady() async {
    log.info('MigrateSearchConfigHandler onReady');

    Map<String, dynamic>? map = storageService.read('${ConfigEnum.searchConfig.key}: DesktopSearchPageTabLogic') ??
        storageService.read('${ConfigEnum.searchConfig.key}: SearchPageMobileV2Logic');
    if (map != null) {
      storageService.write('${ConfigEnum.searchConfig.key}: ${SearchPageLogicMixin.searchPageConfigKey}', map);
    }
  }
}

class ClearSuperResolutionSettingHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [superResolutionSetting];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 7;
  }

  @override
  Future<void> onInit() async {
    log.info('ClearSuperResolutionSettingHandler onInit');
    superResolutionSetting.saveModelDirectoryPath(null);
  }

  @override
  Future<void> onReady() async {}
}

class MigrateCookieHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [pathService, ehRequest];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 8;
  }

  @override
  Future<void> onInit() async {
    log.info('MigrateCookieHandler onInit');

    File cookieFile = File(join(pathService.getVisibleDir().path, 'cookies', 'ie0_ps1', 'exhentai.org'));
    if (!await cookieFile.exists()) {
      return;
    }

    String str = await cookieFile.readAsString();
    Map<String, Map<String, dynamic>> cookieStrs = json.decode(str).cast<String, Map<String, dynamic>>();

    List<Cookie> cookies = [];
    for (Map<String, dynamic> cookieObject in cookieStrs.values) {
      for (MapEntry<String, dynamic> entry in cookieObject.entries) {
        String key = entry.key;
        String exp = '$key=([^;]+);';
        String? value = RegExp(exp).firstMatch(str)?.group(1);
        if (value != null) {
          cookies.add(Cookie(key, value));
        }
      }
    }

    log.info('MigrateCookieHandler migrate cookies: $cookies');
    ehRequest.storeEHCookies(cookies);
  }

  @override
  Future<void> onReady() async {}
}

class MigrateLocalFilterTagsHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [storageService, localBlockRuleService];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    return fromVersion != null && fromVersion <= 9;
  }

  @override
  Future<void> onInit() async {
    log.info('MigrateLocalFilterTagsHandler onInit');

    Map<String, dynamic>? map = storageService.read<Map<String, dynamic>>(ConfigEnum.myTagsSetting.key);
    if (map != null) {
      List<TagData> localTagSets = (map['localTagSets'] as List).map((e) => TagData.fromJson(e)).toList();

      List<Future> futures = [];
      for (TagData tagData in localTagSets) {
        futures.add(localBlockRuleService.upsertBlockRule(
          LocalBlockRule(
            groupId: newUUID(),
            target: LocalBlockTargetEnum.gallery,
            attribute: LocalBlockAttributeEnum.tag,
            pattern: LocalBlockPatternEnum.equal,
            expression: '${tagData.namespace}:${tagData.key}',
          ),
        ));

        if (tagData.translatedNamespace != null && tagData.tagName != null) {
          futures.add(localBlockRuleService.upsertBlockRule(
            LocalBlockRule(
              groupId: newUUID(),
              target: LocalBlockTargetEnum.gallery,
              attribute: LocalBlockAttributeEnum.tag,
              pattern: LocalBlockPatternEnum.equal,
              expression: '${tagData.translatedNamespace}:${tagData.tagName}',
            ),
          ));
        }
      }
      await Future.wait(futures);
    }
  }

  @override
  Future<void> onReady() async {}
}

class MigrateGalleryHistoryHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [storageService];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    if (fromVersion == null) {
      await localConfigService.write(configKey: ConfigEnum.migrateGalleryHistory, value: 'true');
      return false;
    } else {
      return fromVersion <= 10 || (await localConfigService.read(configKey: ConfigEnum.migrateGalleryHistory) == null);
    }
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onReady() async {
    log.info('MigrateGalleryHistoryHandler onReady');

    int totalCount = await GalleryHistoryDao.selectTotalCountOld();
    int pageSize = 60;
    int pageCount = (totalCount / pageSize).ceil();

    log.info('Migrate gallery history, total count: $totalCount');

    String lastReadTime = DateTime.fromMicrosecondsSinceEpoch(0).toString();

    for (int i = 0; i < pageCount; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 2000));

        List<GalleryHistoryData> oldHistories = await GalleryHistoryDao.selectLargerThanLastReadTimeAndGidOld(lastReadTime, pageSize);
        if (oldHistories.isEmpty) {
          break;
        }

        List<Future> futures = [];
        Map<int, String> gid2NewJsonBodyMap = {};
        for (GalleryHistoryData history in oldHistories) {
          Future future = isolateService.jsonDecodeAsync(history.jsonBody).then((map) {
            return Gallery.fromJson(map);
          }).then((gallery) {
            return isolateService.jsonEncodeAsync(gallery2GalleryHistoryModel(gallery));
          }).then((galleryString) {
            gid2NewJsonBodyMap[history.gid] = galleryString;
          });

          futures.add(future);
        }
        await Future.wait(futures);

        await GalleryHistoryDao.batchReplaceHistory(
          oldHistories.map(
            (h) {
              return GalleryHistoryV2Data(
                gid: h.gid,
                jsonBody: gid2NewJsonBodyMap[h.gid]!,
                lastReadTime: h.lastReadTime,
              );
            },
          ).toList(),
        );

        await  GalleryHistoryDao.batchDeleteHistoryByGidOld(oldHistories.map((h) => h.gid).toList());

        lastReadTime = oldHistories.last.lastReadTime;

        log.info('Migrate gallery history for page index $i success!');
      } on Exception catch (e) {
        log.error('Migrate gallery history for page index $i failed!', e);
      }
    }

    log.info('Migrate gallery history success!');
    await localConfigService.write(configKey: ConfigEnum.migrateGalleryHistory, value: 'true');
  }
}

class MigrateStorageConfigHandler implements UpdateHandler {
  @override
  List<JHLifeCircleBean> get initDependencies => [
        localConfigService,
        storageService,
        favoriteSetting,
        advancedSetting,
        downloadSetting,
        ehSetting,
        mouseSetting,
        networkSetting,
        preferenceSetting,
        performanceSetting,
        readSetting,
        securitySetting,
        siteSetting,
        styleSetting,
        superResolutionSetting,
        userSetting,
        ehRequest,
      ];

  @override
  Future<bool> match(int? fromVersion, int toVersion) async {
    if (fromVersion == null) {
      await localConfigService.write(configKey: ConfigEnum.migrateStorageConfig, value: 'true');
      return false;
    } else {
      return fromVersion <= 11 || (await localConfigService.read(configKey: ConfigEnum.migrateStorageConfig) == null);
    }
  }

  @override
  Future<void> onInit() async {
    log.info('MigrateStorageConfigHandler onInit');

    List<Future> futures = [];

    Map? favoriteSettingMap = storageService.read(ConfigEnum.favoriteSetting.key);
    if (favoriteSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.favoriteSetting, value: jsonEncode(favoriteSettingMap));
        await favoriteSetting.refreshBean();
      }));
    }
    Map? advancedSettingMap = storageService.read(ConfigEnum.advancedSetting.key);
    if (advancedSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.advancedSetting, value: jsonEncode(advancedSettingMap));
        await advancedSetting.refreshBean();
      }));
    }
    Map? downloadSettingMap = storageService.read(ConfigEnum.downloadSetting.key);
    if (downloadSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.downloadSetting, value: jsonEncode(downloadSettingMap));
        await downloadSetting.refreshBean();
      }));
    }
    Map? EHSettingMap = storageService.read(ConfigEnum.EHSetting.key);
    if (EHSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.EHSetting, value: jsonEncode(EHSettingMap));
        await ehSetting.refreshBean();
      }));
    }
    Map? mouseSettingMap = storageService.read(ConfigEnum.mouseSetting.key);
    if (mouseSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.mouseSetting, value: jsonEncode(mouseSettingMap));
        await mouseSetting.refreshBean();
      }));
    }
    Map? networkSettingMap = storageService.read(ConfigEnum.networkSetting.key);
    if (networkSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.networkSetting, value: jsonEncode(networkSettingMap));
        await networkSetting.refreshBean();
      }));
    }
    Map? performanceSettingMap = storageService.read(ConfigEnum.performanceSetting.key);
    if (performanceSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.performanceSetting, value: jsonEncode(performanceSettingMap));
        await performanceSetting.refreshBean();
      }));
    }
    Map? preferenceSettingMap = storageService.read(ConfigEnum.preferenceSetting.key);
    if (preferenceSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.preferenceSetting, value: jsonEncode(preferenceSettingMap));
        await preferenceSetting.refreshBean();
      }));
    }
    Map? readSettingMap = storageService.read(ConfigEnum.readSetting.key);
    if (readSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.readSetting, value: jsonEncode(readSettingMap));
        await readSetting.refreshBean();
      }));
    }
    Map? securitySettingMap = storageService.read(ConfigEnum.securitySetting.key);
    if (securitySettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.securitySetting, value: jsonEncode(securitySettingMap));
        await securitySetting.refreshBean();
      }));
    }
    Map? siteSettingMap = storageService.read(ConfigEnum.siteSetting.key);
    if (siteSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.siteSetting, value: jsonEncode(siteSettingMap));
        await siteSetting.refreshBean();
      }));
    }
    Map? styleSettingMap = storageService.read(ConfigEnum.styleSetting.key);
    if (styleSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.styleSetting, value: jsonEncode(styleSettingMap));
        await styleSetting.refreshBean();
      }));
    }
    Map? superResolutionSettingMap = storageService.read(ConfigEnum.superResolutionSetting.key);
    if (superResolutionSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.superResolutionSetting, value: jsonEncode(superResolutionSettingMap));
        await superResolutionSetting.refreshBean();
      }));
    }
    Map? userSettingMap = storageService.read(ConfigEnum.userSetting.key);
    if (userSettingMap != null) {
      futures.add(Future(() async {
        await localConfigService.write(configKey: ConfigEnum.userSetting, value: jsonEncode(userSettingMap));
        await userSetting.refreshBean();
      }));
    }

    double? windowWidth = storageService.read(ConfigEnum.windowWidth.key);
    if (windowWidth != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.windowWidth, value: windowWidth.toString()));
    }
    double? windowHeight = storageService.read(ConfigEnum.windowHeight.key);
    if (windowHeight != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.windowHeight, value: windowHeight.toString()));
    }
    bool? isMaximized = storageService.read(ConfigEnum.windowMaximize.key);
    if (isMaximized != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.windowMaximize, value: isMaximized.toString()));
    }
    bool? isFullScreen = storageService.read(ConfigEnum.windowFullScreen.key);
    if (isFullScreen != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.windowFullScreen, value: isFullScreen.toString()));
    }
    double? leftColumnWidthRatio = storageService.read(ConfigEnum.leftColumnWidthRatio.key);
    if (leftColumnWidthRatio != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.leftColumnWidthRatio, value: leftColumnWidthRatio.toString()));
    }

    List<String>? cookies = storageService.read<List?>(ConfigEnum.ehCookie.key)?.cast<String>().toList();
    if (cookies != null) {
      List<Cookie> list = cookies.map(Cookie.fromSetCookieValue).toList();
      futures.add(ehRequest.storeEHCookies(list));
    }

    Map<String, dynamic>? dashboardPageSearchConfigMap = storageService.read('${ConfigEnum.searchConfig.key}: DashboardPageLogic');
    if (dashboardPageSearchConfigMap != null) {
      SearchConfig searchConfig = SearchConfig.fromJson(dashboardPageSearchConfigMap);
      futures.add(localConfigService.write(configKey: ConfigEnum.searchConfig, subConfigKey: 'DashboardPageLogic', value: jsonEncode(searchConfig)));
    }
    Map<String, dynamic>? searchPageSearchConfigMap = storageService.read('${ConfigEnum.searchConfig.key}: ${SearchPageLogicMixin.searchPageConfigKey}');
    if (searchPageSearchConfigMap != null) {
      SearchConfig searchConfig = SearchConfig.fromJson(searchPageSearchConfigMap);
      futures.add(
        localConfigService.write(configKey: ConfigEnum.searchConfig, subConfigKey: SearchPageLogicMixin.searchPageConfigKey, value: jsonEncode(searchConfig)),
      );
    }
    Map<String, dynamic>? gallerysPageSearchConfigMap = storageService.read('${ConfigEnum.searchConfig.key}: GallerysPageLogic');
    if (gallerysPageSearchConfigMap != null) {
      SearchConfig searchConfig = SearchConfig.fromJson(gallerysPageSearchConfigMap);
      futures.add(localConfigService.write(configKey: ConfigEnum.searchConfig, subConfigKey: 'GallerysPageLogic', value: jsonEncode(searchConfig)));
    }
    Map<String, dynamic>? favoritePageSearchConfigMap = storageService.read('${ConfigEnum.searchConfig.key}: FavoritePageLogic');
    if (favoritePageSearchConfigMap != null) {
      SearchConfig searchConfig = SearchConfig.fromJson(favoritePageSearchConfigMap);
      futures.add(localConfigService.write(configKey: ConfigEnum.searchConfig, subConfigKey: 'FavoritePageLogic', value: jsonEncode(searchConfig)));
    }

    String? dismissVersion = storageService.read(ConfigEnum.dismissVersion.key);
    if (dismissVersion != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.dismissVersion, value: dismissVersion));
    }

    int? downloadPageBodyType = storageService.read(ConfigEnum.downloadPageBodyType.key);
    if (downloadPageBodyType != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.downloadPageBodyType, value: downloadPageBodyType.toString()));
    }

    List? archiveDisplayGroups = storageService.read<List?>(ConfigEnum.displayArchiveGroups.key);
    if (archiveDisplayGroups != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.displayArchiveGroups, value: jsonEncode(archiveDisplayGroups)));
    }

    List? galleryDisplayGroups = storageService.read<List?>(ConfigEnum.displayGalleryGroups.key);
    if (galleryDisplayGroups != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.displayGalleryGroups, value: jsonEncode(galleryDisplayGroups)));
    }

    bool? enableSearchHistoryTranslation = storageService.read(ConfigEnum.enableSearchHistoryTranslation.key);
    if (enableSearchHistoryTranslation != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.enableSearchHistoryTranslation, value: enableSearchHistoryTranslation.toString()));
    }

    int? tagTranslationLoadingStateIndex = storageService.read(ConfigEnum.tagTranslationServiceLoadingState.key);
    if (tagTranslationLoadingStateIndex != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.tagTranslationServiceLoadingState, value: tagTranslationLoadingStateIndex.toString()));
    }

    String? tagTranslationTimeStamp = storageService.read(ConfigEnum.tagTranslationServiceTimestamp.key);
    if (tagTranslationTimeStamp != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.tagTranslationServiceTimestamp, value: tagTranslationTimeStamp));
    }

    int? tagSearchOrderOptimizationServiceLoadingStateIndex = storageService.read(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key);
    if (tagSearchOrderOptimizationServiceLoadingStateIndex != null) {
      futures.add(
        localConfigService.write(
          configKey: ConfigEnum.tagSearchOrderOptimizationServiceLoadingState,
          value: tagSearchOrderOptimizationServiceLoadingStateIndex.toString(),
        ),
      );
    }

    String? tagSearchOrderOptimizationServiceVersion = storageService.read(ConfigEnum.tagSearchOrderOptimizationServiceVersion.key);
    if (tagSearchOrderOptimizationServiceVersion != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.tagSearchOrderOptimizationServiceVersion, value: tagSearchOrderOptimizationServiceVersion));
    }

    bool? showLocalBlockRulesGroup = storageService.read(ConfigEnum.displayBlockingRulesGroup.key);
    if (showLocalBlockRulesGroup != null) {
      futures.add(localConfigService.write(configKey: ConfigEnum.displayBlockingRulesGroup, value: showLocalBlockRulesGroup.toString()));
    }

    await Future.wait(futures);
  }

  @override
  Future<void> onReady() async {
    log.info('MigrateStorageConfigHandler onReady');

    Iterable<String>? keys = storageService.getKeys();
    if (keys != null) {
      Map<String, int> gid2ReadIndexMap = {};

      keys.toList().whereType<String>().where((key) => key.startsWith(ConfigEnum.readIndexRecord.key)).forEach((key) {
        List<String> parts = key.split('::');
        if (parts.length == 2) {
          int? readIndexRecord = storageService.read(key);
          if (readIndexRecord != null) {
            gid2ReadIndexMap[parts[1]] = readIndexRecord;
          }
        }
      });

      if (gid2ReadIndexMap.isNotEmpty) {
        List<LocalConfigCompanion> localConfigs = gid2ReadIndexMap.entries.map((entry) {
          return LocalConfigCompanion(
            configKey: Value(ConfigEnum.readIndexRecord.key),
            subConfigKey: Value(entry.key),
            value: Value(entry.value.toString()),
            utime: Value(DateTime.now().toString()),
          );
        }).toList();

        for (List<LocalConfigCompanion> localConfigCompanions in localConfigs.partition(200)) {
          await localConfigService.batchWrite(localConfigCompanions);
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    Map? map = storageService.read(ConfigEnum.quickSearch.key);
    if (map != null) {
      Map<String, SearchConfig> quickSearchConfigs = LinkedHashMap.from(map.map((key, value) => MapEntry(key, SearchConfig.fromJson(value))));
      await localConfigService.write(configKey: ConfigEnum.quickSearch, value: jsonEncode(quickSearchConfigs));
    }

    List? searchHistories = storageService.read(ConfigEnum.searchHistory.key);
    if (searchHistories != null) {
      await localConfigService.write(configKey: ConfigEnum.searchHistory, value: jsonEncode(searchHistories));
    }

    await localConfigService.write(configKey: ConfigEnum.migrateStorageConfig, value: 'true');
  }
}
