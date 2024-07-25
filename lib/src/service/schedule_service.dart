import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:extended_image/extended_image.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';
import 'package:jhentai/src/database/dao/archive_dao.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../model/gallery_metadata.dart';
import '../utils/file_util.dart';
import '../utils/log.dart';

class ScheduleService extends GetxService {
  static void init() {
    Get.put(ScheduleService(), permanent: true);
    Log.debug('init ScheduleService success', false);
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    Timer(const Duration(seconds: 10), refreshGalleryTags);
    Timer(const Duration(seconds: 10), refreshArchiveTags);
    Timer(const Duration(seconds: 5), clearOutdatedImageCache);
  }

  Future<void> refreshGalleryTags() async {
    int pageNo = 1;
    List<GalleryDownloadedData> gallerys = await GalleryDao.selectGallerysForTagRefresh(pageNo, 25);
    while (gallerys.isNotEmpty) {
      try {
        List<GalleryMetadata> metadatas = await EHRequest.requestGalleryMetadatas<List<GalleryMetadata>>(
          list: gallerys.map((a) => (gid: a.gid, token: a.token)).toList(),
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
        Log.trace('refreshGalleryTags success, pageNo: $pageNo, archives: ${gallerys.map((a) => a.gid).toList()}');
      } catch (e) {
        Log.warning('refreshGalleryTags error, gallerys: $gallerys', e);
      }

      pageNo++;
      gallerys = await GalleryDao.selectGallerysForTagRefresh(pageNo, 25);
    }
  }

  Future<void> refreshArchiveTags() async {
    int pageNo = 1;
    List<ArchiveDownloadedData> archives = await ArchiveDao.selectArchivesForTagRefresh(pageNo, 25);
    while (archives.isNotEmpty) {
      try {
        List<GalleryMetadata> metadatas = await EHRequest.requestGalleryMetadatas<List<GalleryMetadata>>(
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
        Log.trace('refreshArchiveTags success, pageNo: $pageNo, archives: ${archives.map((a) => a.gid).toList()}');
      } catch (e) {
        Log.warning('refreshArchiveTags error, archives: $archives', e);
      }

      pageNo++;
      archives = await ArchiveDao.selectArchivesForTagRefresh(pageNo, 25);
    }
  }

  Future<void> clearOutdatedImageCache() async {
    Directory cacheImageDirectory = Directory(join((await getTemporaryDirectory()).path, cacheImageFolderName));

    int count = 0;
    cacheImageDirectory.list().forEach((FileSystemEntity entity) {
      if (entity is File && DateTime.now().difference(entity.lastModifiedSync()) > NetworkSetting.cacheImageExpireDuration.value) {
        entity.delete();
        count++;
      }
    }).then((_) => Log.info('Clear outdated image cache success, count: $count'));
  }
}
