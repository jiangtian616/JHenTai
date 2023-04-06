import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/extension/directory_extension.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as p;

import '../model/gallery.dart';
import '../service/storage_service.dart';

part 'database.g.dart';

@DriftDatabase(include: {
  'gallery_downloaded.drift',
  'archive_downloaded.drift',
  'tag.drift',
  'gallery_history.drift',
  'tag_browse_progress.drift',
  'super_resolution_info.drift'
})
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (Migrator m, int from, int to) async {
        Log.warning('Database version: $from -> $to');
        if (from > to) {
          return;
        }

        try {
          if (from < 2) {
            await m.alterTable(TableMigration(image));
          }
          if (from < 3) {
            await m.addColumn(galleryDownloaded, galleryDownloaded.downloadOriginalImage);
          }
          if (from < 4) {
            await m.addColumn(galleryDownloaded, galleryDownloaded.priority);
          }
          if (from < 11) {
            await m.addColumn(galleryDownloaded, galleryDownloaded.sortOrder);
            await m.addColumn(galleryGroup, galleryGroup.sortOrder);
            await m.addColumn(archiveDownloaded, archiveDownloaded.sortOrder);
            await m.addColumn(archiveGroup, archiveGroup.sortOrder);
          }
          if (from < 5) {
            await m.addColumn(galleryDownloaded, galleryDownloaded.groupName);
            await m.addColumn(archiveDownloaded, archiveDownloaded.groupName);
            await _updateArchive(m);
          }
          if (from < 6) {
            await _updateHistory(m);
          }
          if (5 <= from && from < 7) {
            await m.addColumn(galleryDownloaded, galleryDownloaded.groupName);
            await m.addColumn(archiveDownloaded, archiveDownloaded.groupName);
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
          if (from < 12) {
            await m.createTable(tagBrowseProgress);
          }
          if (from < 13) {
            await m.createTable(superResolutionInfo);
          }
        } on Exception catch (e) {
          Log.error(e);
          Log.upload(e, extraInfos: {'from': from, 'to': to});
          throw NotUploadException(e);
        }
      },
    );
  }

  Future<void> _updateArchive(Migrator m) async {
    try {
      List<ArchiveDownloadedData> archives = await appDb.selectArchives().get();

      await appDb.transaction(() async {
        for (ArchiveDownloadedData a in archives) {
          await appDb.updateArchive(a.archiveStatusIndex + 1, a.downloadPageUrl, a.downloadUrl, a.sortOrder, a.groupName, a.gid, a.isOriginal);
        }
      });
    } on Exception catch (e) {
      Log.error('Update archive failed!', e);
      Log.upload(e);
    }
  }

  Future<void> _updateHistory(Migrator m) async {
    try {
      await m.createTable(galleryHistory);

      if (Get.isRegistered<StorageService>()) {
        List<Gallery>? gallerys = Get.find<StorageService>().read<List>('history')?.map((e) => Gallery.fromJson(e)).toList();

        if (gallerys != null) {
          await appDb.transaction(() async {
            for (Gallery g in gallerys.reversed) {
              await appDb.insertHistory(g.gid, json.encode(g), DateTime.now().toString());
            }
          });
        }

        Get.find<StorageService>().remove('history');
      }
    } on Exception catch (e) {
      Log.error('Update history failed!', e);
      Log.upload(e);
    }
  }

  Future<void> _createGroupTable(Migrator m) async {
    try {
      await m.createTable(galleryGroup);
      await m.createTable(archiveGroup);

      Set<String> galleryGroups = (await appDb.selectGallerys().get()).map((g) => g.groupName ?? 'default'.tr).toSet();
      Set<String> archiveGroups = (await appDb.selectArchives().get()).map((g) => g.groupName ?? 'default'.tr).toSet();

      Log.info('Migrate gallery groups: $galleryGroups');
      Log.info('Migrate archive groups: $archiveGroups');

      await appDb.transaction(() async {
        for (String groupName in galleryGroups) {
          await appDb.insertGalleryGroup(groupName);
        }
        for (String groupName in archiveGroups) {
          await appDb.insertArchiveGroup(groupName);
        }
      });
    } on Exception catch (e) {
      Log.error('Create Group Table failed!', e);
      Log.upload(e);
    }
  }

  /// copy files
  Future<void> _updateConfigFileLocation() async {
    await PathSetting.appSupportDir?.copy(PathSetting.getVisibleDir().path);
  }

  Future<void> _deleteImageSizeColumn(Migrator m) async {
    await m.alterTable(TableMigration(archiveDownloaded));
    await m.alterTable(TableMigration(image));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = io.File(p.join(PathSetting.getVisibleDir().path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

AppDb appDb = AppDb();
