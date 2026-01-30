import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/database/dao/gallery_group_dao.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/dao/super_resolution_info_dao.dart';
import 'package:jhentai/src/database/table/archive_downloaded.dart';
import 'package:jhentai/src/database/table/archive_group.dart';
import 'package:jhentai/src/database/table/block_rule.dart';
import 'package:jhentai/src/database/table/dio_cache.dart';
import 'package:jhentai/src/database/table/gallery_downloaded.dart';
import 'package:jhentai/src/database/table/gallery_group.dart';
import 'package:jhentai/src/database/table/gallery_history.dart';
import 'package:jhentai/src/database/table/image.dart';
import 'package:jhentai/src/database/table/local_config.dart';
import 'package:jhentai/src/database/table/super_resolution_info.dart';
import 'package:jhentai/src/database/table/tag.dart';
import 'package:jhentai/src/database/table/tag_count.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/extension/directory_extension.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:path/path.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import '../model/gallery.dart';
import '../model/gallery_history_model.dart';
import '../service/archive_download_service.dart';
import '../service/storage_service.dart';
import 'dao/archive_dao.dart';
import 'dao/archive_group_dao.dart';
import 'dao/gallery_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    OldSuperResolutionInfo,
    SuperResolutionInfo,
    Tag,
    ArchiveDownloaded,
    ArchiveDownloadedOld,
    ArchiveGroup,
    GalleryDownloaded,
    GalleryDownloadedOld,
    GalleryGroup,
    Image,
    GalleryHistory,
    GalleryHistoryV2,
    TagCount,
    DioCache,
    BlockRule,
    LocalConfig,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (OpeningDetails details) async {
        log.info('Database version before: ${details.versionBefore}, now: ${details.versionNow}');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        log.warning('Database version: $from -> $to');
        if (from > to) {
          return;
        }

        try {
          await transaction(() async {
            if (from < 2) {
              await m.alterTable(TableMigration(image));
            }
            if (from < 3) {
              await m.addColumn(galleryDownloadedOld, galleryDownloadedOld.downloadOriginalImage);
            }
            if (from < 4) {
              await m.addColumn(galleryDownloadedOld, galleryDownloadedOld.priority);
            }
            if (from < 5) {
              await m.addColumn(galleryDownloadedOld, galleryDownloadedOld.groupName);
              await m.addColumn(archiveDownloadedOld, archiveDownloadedOld.groupName);
              await _updateArchive(m);
            }
            if (from < 6) {
              await _updateHistory(m);
            }
            if (5 <= from && from < 7) {
              await m.addColumn(galleryDownloadedOld, galleryDownloadedOld.groupName);
              await m.addColumn(archiveDownloadedOld, archiveDownloadedOld.groupName);
            }
            if (from < 8) {
              await _createGroupTable(m);
            }
            if (from < 9) {
              await _updateConfigFileLocation();
            }
            if (from < 10) {
              await _deleteImageSizeColumn(m);
            }
            if (from < 11) {
              await m.addColumn(galleryDownloadedOld, galleryDownloadedOld.sortOrder);
              await m.addColumn(galleryGroup, galleryGroup.sortOrder);
              await m.addColumn(archiveDownloadedOld, archiveDownloadedOld.sortOrder);
              await m.addColumn(archiveGroup, archiveGroup.sortOrder);
            }
            if (from < 13) {
              await m.createTable(superResolutionInfo);
            }
            if (from < 14) {
              await m.createTable(tagCount);
              await m.createTable(dioCache);
              await m.createIndex(idxExpireDate).ignoreDuplicateIndex();
              await m.createIndex(idxUrl).ignoreDuplicateIndex();
            }
            if (from < 15) {
              await _migrateSuperResolutionInfo(m);
            }
            if (from < 16) {
              await m.createIndex(idxKey).ignoreDuplicateIndex();
              await m.createIndex(idxTagName).ignoreDuplicateIndex();
            }
            if (from < 17) {
              await _migrateDownloadedInfo(m);
            }
            if (from < 18) {
              await m.createIndex(idxLastReadTime).ignoreDuplicateIndex();
            }
            if (from < 19) {
              await _migrateArchiveStatus(m);
            }
            if (from < 20) {
              await m.createTable(blockRule);
            }
            if (17 <= from && from < 21) {
              await m.alterTable(TableMigration(galleryDownloaded, newColumns: [galleryDownloaded.tags, galleryDownloaded.tagRefreshTime]));
              await m.alterTable(TableMigration(archiveDownloaded, newColumns: [archiveDownloaded.tags, archiveDownloaded.tagRefreshTime]));
            }
            if (from < 21) {
              await m.createIndex(gIdxTagRefreshTime).ignoreDuplicateIndex();
              await m.createIndex(aIdxTagRefreshTime).ignoreDuplicateIndex();
              await m.createTable(galleryHistoryV2);
            }
            if (from < 22) {
              await m.createTable(localConfig);
            }
            if (17 <= from && from < 23) {
              await m.alterTable(TableMigration(archiveDownloaded, newColumns: [archiveDownloaded.parseSource]));
            }
            if (from < 24) {
              // Add size column to dio_cache for cache management
              // Use raw SQL with IF NOT EXISTS pattern to handle re-runs
              try {
                await customStatement('ALTER TABLE dio_cache ADD COLUMN size INTEGER NOT NULL DEFAULT 0');
              } catch (_) {
                // Column already exists, ignore
              }
              // Populate size for existing entries based on content length
              await customStatement('UPDATE dio_cache SET size = LENGTH(content) WHERE size = 0');
              // Create index for size-based queries
              await customStatement('CREATE INDEX IF NOT EXISTS idx_size ON dio_cache (size)');
            }
          });
        } on Exception catch (e) {
          log.error(e);
          log.uploadError(e, extraInfos: {'from': from, 'to': to});
          throw NotUploadException(e);
        }
      },
    );
  }

  Future<void> _updateArchive(Migrator m) async {
    try {
      List<ArchiveDownloadedOldData> archives = await ArchiveDao.selectOldArchives();

      await appDb.transaction(() async {
        for (ArchiveDownloadedOldData a in archives) {
          await ArchiveDao.updateOldArchive(
            ArchiveDownloadedOldCompanion(
              gid: Value(a.gid),
              archiveStatusIndex: Value(a.archiveStatusIndex + 1),
            ),
          );
        }
      });
    } on Exception catch (e) {
      log.error('Update archive failed!', e);
      rethrow;
    }
  }

  Future<void> _updateHistory(Migrator m) async {
    try {
      await m.createTable(galleryHistory);

      if (Get.isRegistered<StorageService>()) {
        List<Gallery>? gallerys = storageService.read<List>(ConfigEnum.oldGalleryHistory.key)?.map((e) => Gallery.fromJson(e)).toList();

        List<GalleryHistoryModel>? historyModels = gallerys
            ?.map(
              (g) => GalleryHistoryModel(
                galleryUrl: g.galleryUrl,
                title: g.title,
                category: g.category,
                coverUrl: g.cover.url,
                pageCount: g.pageCount ?? 0,
                rating: g.rating,
                language: g.language ?? '',
                uploader: g.uploader ?? '',
                publishTime: g.publishTime,
                isExpunged: g.isExpunged,
                tags: g.tags.values.flattened.map((tag) => '${tag.tagData.namespace}:${tag.tagData.key}').toList(),
              ),
            )
            .toList();

        List<GalleryHistoryV2Data>? historyV2Datas = historyModels
            ?.map(
              (h) => GalleryHistoryV2Data(
                gid: h.galleryUrl.gid,
                jsonBody: jsonEncode(h),
                lastReadTime: DateTime.now().toString(),
              ),
            )
            .toList();

        if (historyV2Datas != null) {
          await GalleryHistoryDao.batchReplaceHistory(historyV2Datas);
        }

        storageService.remove(ConfigEnum.oldGalleryHistory.key);
      }
    } on Exception catch (e) {
      log.error('Update history failed!', e);
      log.uploadError(e);
      rethrow;
    }
  }

  Future<void> _createGroupTable(Migrator m) async {
    try {
      await m.createTable(galleryGroup);
      await m.createTable(archiveGroup);

      Set<String> galleryGroups = (await GalleryDao.selectOldGallerys()).map((g) => g.groupName ?? 'default'.tr).toSet();
      Set<String> archiveGroups = (await ArchiveDao.selectOldArchives()).map((g) => g.groupName ?? 'default'.tr).toSet();

      log.info('Migrate gallery groups: $galleryGroups');
      log.info('Migrate archive groups: $archiveGroups');

      await appDb.transaction(() async {
        for (String groupName in galleryGroups) {
          await GalleryGroupDao.insertGalleryGroup(GalleryGroupData(groupName: groupName, sortOrder: 0));
        }
        for (String groupName in archiveGroups) {
          await ArchiveGroupDao.insertArchiveGroup(ArchiveGroupData(groupName: groupName, sortOrder: 0));
        }
      });
    } on Exception catch (e) {
      log.error('Create Group Table failed!', e);
      log.uploadError(e);
      rethrow;
    }
  }

  /// copy files
  Future<void> _updateConfigFileLocation() async {
    await pathService.appSupportDir?.copy(pathService.getVisibleDir().path);
  }

  Future<void> _deleteImageSizeColumn(Migrator m) async {
    await m.alterTable(TableMigration(archiveDownloaded));
    await m.alterTable(TableMigration(image));
  }

  Future<void> _migrateSuperResolutionInfo(Migrator m) async {
    try {
      await m.createTable(superResolutionInfo);

      List<OldSuperResolutionInfoData> oldSuperResolutionInfo = await SuperResolutionInfoDao.selectAllOldSuperResolutionInfo();

      await appDb.transaction(() async {
        for (OldSuperResolutionInfoData old in oldSuperResolutionInfo) {
          await SuperResolutionInfoDao.insertSuperResolutionInfo(
            SuperResolutionInfoData(
              gid: old.gid,
              type: old.type,
              status: old.status,
              imageStatuses: old.imageStatuses,
            ),
          );
        }
      });
    } on Exception catch (e) {
      log.error('Migrate super resolution info failed!', e);
      log.uploadError(e);
      rethrow;
    }
  }

  Future<void> _migrateDownloadedInfo(Migrator m) async {
    try {
      await m.createTable(galleryDownloaded);
      await m.createTable(archiveDownloaded);

      List<GalleryDownloadedOldData> gallerys = await GalleryDao.selectOldGallerys();
      await appDb.transaction(() async {
        for (GalleryDownloadedOldData g in gallerys) {
          await GalleryDao.insertGallery(
            GalleryDownloadedCompanion.insert(
              gid: Value(g.gid),
              token: g.token,
              title: g.title,
              category: g.category,
              pageCount: g.pageCount,
              galleryUrl: g.galleryUrl,
              oldVersionGalleryUrl: Value(g.oldVersionGalleryUrl),
              uploader: Value(g.uploader),
              publishTime: g.publishTime,
              downloadStatusIndex: g.downloadStatusIndex,
              insertTime: g.insertTime!,
              downloadOriginalImage: Value(g.downloadOriginalImage),
              priority: g.priority ?? 0,
              sortOrder: Value(g.sortOrder),
              groupName: g.groupName!,
              tagRefreshTime: Value(DateTime.now().toString()),
            ),
          );
        }
      });

      List<ArchiveDownloadedOldData> archives = await ArchiveDao.selectOldArchives();
      await appDb.transaction(() async {
        for (ArchiveDownloadedOldData a in archives) {
          await ArchiveDao.insertArchive(
            ArchiveDownloadedCompanion.insert(
              gid: Value(a.gid),
              token: a.token,
              title: a.title,
              category: a.category,
              pageCount: a.pageCount,
              galleryUrl: a.galleryUrl,
              coverUrl: a.coverUrl,
              uploader: Value(a.uploader),
              size: a.size,
              publishTime: a.publishTime,
              archiveStatusCode: a.archiveStatusIndex,
              archivePageUrl: a.archivePageUrl,
              downloadPageUrl: Value(a.downloadPageUrl),
              downloadUrl: Value(a.downloadUrl),
              isOriginal: a.isOriginal,
              insertTime: a.insertTime!,
              sortOrder: Value(a.sortOrder),
              groupName: a.groupName!,
              tagRefreshTime: Value(DateTime.now().toString()),
              parseSource: Value(ArchiveParseSource.official.code),
            ),
          );
        }
      });
    } catch (e) {
      log.error('Migrate downloaded info failed!', e);
      log.uploadError(e);
      rethrow;
    }
  }

  Future<void> _migrateArchiveStatus(Migrator m) async {
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.none.index, ArchiveStatus.unlocking.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.needReUnlock.index, ArchiveStatus.needReUnlock.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.paused.index, ArchiveStatus.paused.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.unlocking.index, ArchiveStatus.unlocking.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.parsingDownloadPageUrl.index, ArchiveStatus.parsingDownloadPageUrl.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.parsingDownloadUrl.index, ArchiveStatus.parsingDownloadUrl.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.downloading.index, ArchiveStatus.downloading.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.downloaded.index, ArchiveStatus.downloaded.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.unpacking.index, ArchiveStatus.unpacking.code);
    await ArchiveDao.updateArchiveStatus(OldArchiveStatus.completed.index, ArchiveStatus.completed.code);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = io.File(join(pathService.getVisibleDir().path, 'db.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    sqlite3.tempDirectory = pathService.tempDir.path;

    return NativeDatabase(file);
  });
}

AppDb appDb = AppDb();

extension _MigragateDuplicateIndexErrorCache on Future<void> {
  Future<void> ignoreDuplicateIndex() async {
    try {
      await this;
    } on SqliteException catch (e) {
      if (e.resultCode == SqlError.SQLITE_ERROR && RegExp(r'index \S+ already exists').hasMatch(e.message)) {
        log.warning('Ignore duplicate index error: ${e.message}');
      } else {
        rethrow;
      }
    }
  }
}
