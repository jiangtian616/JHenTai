import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/database/dao/archive_dao.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../database/database.dart';
import '../enum/config_enum.dart';
import '../model/archive_bot_response/archive_bot_response.dart';
import '../model/gallery_metadata.dart';
import '../network/archive_bot_request.dart';
import '../setting/advanced_setting.dart';
import '../utils/version_util.dart';
import '../widget/update_dialog.dart';
import 'jh_service.dart';
import 'local_config_service.dart';
import 'log.dart';
import 'path_service.dart';

ScheduleService scheduleService = ScheduleService();

class ScheduleService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  /// Galleries/archives whose tags were refreshed within this window are
  /// skipped by [refreshGalleryTags] / [refreshArchiveTags].
  static const Duration _tagRefreshStaleThreshold = Duration(days: 7);

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {
    Timer(const Duration(seconds: 3), _checkUpdate);
    Timer(const Duration(seconds: 10), refreshGalleryTags);
    Timer(const Duration(seconds: 10), refreshArchiveTags);
    Timer(const Duration(seconds: 5), clearOutdatedImageCache);
    Timer(const Duration(seconds: 1), _clearOutdatedGalleryImageHashCache);

    Timer(const Duration(seconds: 5), checkEHEvent);
    Timer.periodic(const Duration(minutes: 5), (_) => checkEHEvent());

    if (archiveBotSetting.botType.value.supportsCheckIn) {
      Timer(const Duration(seconds: 5), checkInArchiveBot);
      Timer.periodic(const Duration(minutes: 5), (_) => checkInArchiveBot());
    }
  }

  Future<void> _checkUpdate() async {
    if (advancedSetting.enableCheckUpdate.isFalse) {
      return;
    }

    String url = 'https://api.github.com/repos/jiangtian616/JHenTai/releases';
    String latestVersion;

    try {
      latestVersion =
          (await retry(
            () => ehRequest.get(
              url: url,
              parser: EHSpiderParser.githubReleasePage2LatestVersion,
            ),
            maxAttempts: 3,
            delayFactor: const Duration(milliseconds: 500),
          )).trim().split('+')[0];
    } on Exception catch (_) {
      log.info('check update failed');
      return;
    }

    String? dismissVersion = await localConfigService.read(
      configKey: ConfigEnum.dismissVersion,
    );
    if (dismissVersion == latestVersion) {
      return;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = 'v${packageInfo.version}'.trim();
    log.info(
      'Latest version:[$latestVersion], current version: [$currentVersion], current build: [${packageInfo.buildNumber}]',
    );

    if (compareVersion(currentVersion, latestVersion) >= 0) {
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        UpdateDialog(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
        ),
      );
    });
  }

  Future<void> refreshGalleryTags() async {
    final DateTime threshold = DateTime.now().subtract(
      _tagRefreshStaleThreshold,
    );
    int pageNo = 1;
    List<GalleryDownloadedData> galleries =
        await GalleryDao.selectGalleriesForTagRefresh(pageNo, 25, threshold);
    while (galleries.isNotEmpty) {
      bool refreshed = false;
      try {
        List<GalleryMetadata> metadatas = await ehRequest.requestGalleryMetadatas<List<GalleryMetadata>>(
          list: galleries.map((a) => (gid: a.gid, token: a.token)).toList(),
          parser: EHSpiderParser.galleryMetadataJson2GalleryMetadatas,
        );

        await GalleryDao.batchUpdateGallery(
          metadatas
              .map(
                (m) => GalleryDownloadedCompanion(
                  gid: Value(m.galleryUrl.gid),
                  tags: Value(tagMap2TagString(m.tags)),
                  tagRefreshTime: Value(DateTime.now().toString()),
                ),
              )
              .toList(),
        );
        refreshed = true;
        log.trace('refreshGalleryTags success, pageNo: $pageNo, galleries: ${galleries.map((a) => a.gid).toList()}');
      } catch (e) {
        log.warning('refreshGalleryTags error, galleries: ${galleries.map((a) => (gid: a.gid, token: a.token)).toList()}', e, true);
      }

      // A successful batch no longer matches the stale query, so start from
      // the first page again. Advancing here would skip the next 25 rows after
      // the result set shrinks. On failure, advance to avoid retrying the same
      // broken batch forever during this run.
      pageNo = refreshed ? 1 : pageNo + 1;
      galleries = await GalleryDao.selectGalleriesForTagRefresh(
        pageNo,
        25,
        threshold,
      );
    }
  }

  Future<void> refreshArchiveTags() async {
    final DateTime threshold = DateTime.now().subtract(
      _tagRefreshStaleThreshold,
    );
    int pageNo = 1;
    List<ArchiveDownloadedData> archives =
        await ArchiveDao.selectArchivesForTagRefresh(pageNo, 25, threshold);
    while (archives.isNotEmpty) {
      bool refreshed = false;
      try {
        List<GalleryMetadata> metadatas = await ehRequest
            .requestGalleryMetadatas<List<GalleryMetadata>>(
              list: archives.map((a) => (gid: a.gid, token: a.token)).toList(),
              parser: EHSpiderParser.galleryMetadataJson2GalleryMetadatas,
            );

        await ArchiveDao.batchUpdateArchive(
          metadatas
              .map(
                (m) => ArchiveDownloadedCompanion(
                  gid: Value(m.galleryUrl.gid),
                  tags: Value(tagMap2TagString(m.tags)),
                  tagRefreshTime: Value(DateTime.now().toString()),
                ),
              )
              .toList(),
        );
        refreshed = true;
        log.trace(
          'refreshArchiveTags success, pageNo: $pageNo, archives: ${archives.map((a) => a.gid).toList()}',
        );
      } catch (e) {
        log.warning(
          'refreshArchiveTags error, archives: ${archives.map((a) => a.gid).toList()}',
          e,
          true,
        );
      }

      pageNo = refreshed ? 1 : pageNo + 1;
      archives = await ArchiveDao.selectArchivesForTagRefresh(
        pageNo,
        25,
        threshold,
      );
    }
  }

  Future<void> clearOutdatedImageCache() async {
    /// Only sendable values may cross into the spawned isolate; directory IO
    /// (stat + delete) is done there so the UI isolate never blocks on syscalls.
    final String dirPath = join(
      pathService.tempDir.path,
      PathService.smartCacheFolderName,
    );
    final Duration expireDuration =
        networkSetting.effectiveCacheImageExpireDuration;

    if (networkSetting.isSmartCacheRetentionUnlimited) {
      log.info('Skip outdated image cache cleanup: retention is unlimited.');
      return;
    }

    final int count = await Isolate.run(() {
      final Directory cacheImageDirectory = Directory(dirPath);
      if (!cacheImageDirectory.existsSync()) {
        return 0;
      }

      final DateTime now = DateTime.now();
      int removed = 0;
      for (final FileSystemEntity entity in cacheImageDirectory.listSync()) {
        if (entity is File &&
            now.difference(entity.lastAccessedSync()) > expireDuration) {
          entity.deleteSync();
          removed++;
        }
      }
      return removed;
    });

    log.info('Clear outdated image cache success, count: $count');
  }

  Future<void> _clearOutdatedGalleryImageHashCache() async {
    DateTime thresholdTime = DateTime.now().subtract(const Duration(days: 3));
    String thresholdTimeStr = thresholdTime.toString();

    return appDb.managers.localConfig
        .filter(
          (config) =>
              config.configKey.equals(ConfigEnum.galleryImageHash.key) &
              config.utime.column.isSmallerThanValue(thresholdTimeStr),
        )
        .delete()
        .then((value) => value > 0);
  }

  Future<void> checkEHEvent() async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    if (preferenceSetting.showHVInfo.isFalse &&
        preferenceSetting.showDawnInfo.isFalse) {
      return;
    }

    ({String? dawnInfo, String? hvUrl}) eventInfo;
    try {
      eventInfo = await retry(
        () => ehRequest.requestNews(EHSpiderParser.newsPage2Event),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
        delayFactor: const Duration(milliseconds: 500),
      );
    } catch (e) {
      log.warning('ScheduleService checkDawn failed', e);
      return;
    }

    if (preferenceSetting.showDawnInfo.isTrue && eventInfo.dawnInfo != null) {
      log.info('Check dawn success: ${eventInfo.dawnInfo}');
      snack('dawnOfaNewDay'.tr, eventInfo.dawnInfo!, isShort: false);
    }

    if (preferenceSetting.showHVInfo.isTrue && eventInfo.hvUrl != null) {
      log.info('Encounter a monster: ${eventInfo.hvUrl}');
      snack(
        'encounterMonster'.tr,
        'encounterMonsterHint'.tr,
        onPressed:
            () => launchUrlString(
              eventInfo.hvUrl!,
              mode: LaunchMode.externalApplication,
            ),
        isShort: false,
      );
    }
  }

  Future<void> checkInArchiveBot() async {
    if (!archiveBotSetting.isReady) {
      return;
    }
    if (!archiveBotSetting.botType.value.supportsCheckIn) {
      return;
    }

    try {
      ArchiveBotResponse response = await archiveBotRequest.requestCheckIn(
        botType: archiveBotSetting.botType.value,
        apiAddress: archiveBotSetting.apiAddress.value!,
        apiKey: archiveBotSetting.apiKey.value!,
      );
      log.debug('Auto Checkin response: $response');
      if (response.isSuccess) {
        final checkInVO = archiveBotSetting.botType.value.parseCheckIn(
          response.data,
        );
        snack(
          'checkInSuccess'.tr,
          'checkInSuccessHint'.trArgs([
            checkInVO.getGP.toString(),
            checkInVO.currentGP.toString(),
          ]),
        );
      }
    } on DioException catch (e) {
      log.error('Failed to auto checkin', e.errorMsg, e.stackTrace);
    } catch (e) {
      log.error('Failed to auto checkin', e.toString(), StackTrace.current);
    }
  }
}
