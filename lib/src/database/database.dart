import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as p;

import '../model/gallery.dart';
import '../service/storage_service.dart';

part 'database.g.dart';

@DriftDatabase(include: {'gallery_downloaded.drift', 'archive_downloaded.drift', 'tag.drift', 'gallery_history.drift'})
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (Migrator m, int from, int to) async {
        Log.warning('Database version: $from -> $to');
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
          if (from < 5) {
            await _updateArchive(m);
          }
          if (from < 6) {
            await _updateHistory(m);
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
          await appDb.updateArchive(a.archiveStatusIndex + 1, a.downloadPageUrl, a.downloadUrl, a.gid, a.isOriginal);
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = io.File(p.join(PathSetting.appSupportDir.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

AppDb appDb = AppDb();
