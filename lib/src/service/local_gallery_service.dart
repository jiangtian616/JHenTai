import 'dart:io' as io;

import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:path/path.dart';

import '../model/gallery_image.dart';
import '../setting/download_setting.dart';
import '../utils/log.dart';
import '../utils/recorder_util.dart';
import 'archive_download_service.dart';

class LocalGallery {
  String title;
  String path;
  GalleryImage cover;
  int pageCount;
  DateTime time;
  String? galleryUrl;

  LocalGallery({
    required this.title,
    required this.path,
    required this.cover,
    required this.pageCount,
    required this.time,
    this.galleryUrl,
  });
}

class LocalGalleryParseResult {
  /// has images
  bool isLegalGalleryDir = false;

  /// has subDirectory that has images
  bool isLegalNestedGalleryDir = false;

  int imageCount = 0;
}

/// Load galleries in download directory but is not downloaded by JHenTai
class LocalGalleryService extends GetxController {
  static const String galleryCountChangedId = 'galleryCountChangedId';

  List<LocalGallery> allGallerys = [];
  List<String> rootDirectories = [];
  Map<String, List<LocalGallery>> path2GalleryDir = {};
  Map<String, List<String>> path2SubDir = {};

  static Future<void> init() async {
    Get.put(LocalGalleryService(), permanent: true);
  }

  @override
  onInit() async {
    await recordTimeCost(
      'init LocalGalleryService',
      () async {
        int count = await _loadGalleriesFromDisk();

        Log.debug('Init LocalGalleryService success. Galleries count: $count');

        super.onInit();
      },
    );
  }

  Future<int> refreshLocalGallerys() async {
    int preCount = allGallerys.length;

    allGallerys.clear();
    rootDirectories.clear();
    path2GalleryDir.clear();
    path2SubDir.clear();
    int newCount = await _loadGalleriesFromDisk();

    Log.info('Refresh local gallerys, preCount:$preCount, newCount: $newCount');

    return newCount - preCount;
  }

  List<GalleryImage> getGalleryImages(LocalGallery gallery) {
    List<io.File> imageFiles = io.Directory(gallery.path)
        .listSync()
        .whereType<io.File>()
        .where((image) => FileUtil.isImageExtension(image.path))
        .toList()
      ..sort((a, b) => basename(a.path).compareTo(basename(b.path)));

    return imageFiles
        .map(
          (file) => GalleryImage(
            url: 'localImage',
            path: file.path,
            downloadStatus: DownloadStatus.downloaded,
          ),
        )
        .toList();
  }

  void deleteGallery(LocalGallery gallery, String parentPath) {
    Log.info('Delete local gallery: ${gallery.title}');

    io.Directory dir = io.Directory(gallery.path);

    List<io.File> otherFiles = dir.listSync().whereType<io.File>().where((image) => !FileUtil.isImageExtension(image.path)).toList();
    if (otherFiles.isEmpty) {
      dir.delete(recursive: true).catchError((e) {
        Log.error('Delete local gallery error!', e);
        Log.upload(e);
      });
    } else {
      for (io.File file in otherFiles) {
        file.delete().catchError((e) {
          Log.error('Delete local gallery error!', e);
          Log.upload(e);
        });
      }
    }

    allGallerys.removeWhere((g) => g.title == gallery.title);
    path2GalleryDir[parentPath]?.removeWhere((g) => g.title == gallery.title);

    update([galleryCountChangedId]);
  }

  Future<int> _loadGalleriesFromDisk() async {
    for (String path in DownloadSetting.extraGalleryScanPath) {
      LocalGalleryParseResult extraPathResult = _parseDirectory(io.Directory(path));
      if (extraPathResult.isLegalGalleryDir) {
        rootDirectories.add(io.Directory(path).parent.path);
      } else if (extraPathResult.isLegalNestedGalleryDir) {
        rootDirectories.add(path);
      }
    }

    return allGallerys.length;
  }

  LocalGalleryParseResult _parseDirectory(io.Directory directory) {
    LocalGalleryParseResult result = LocalGalleryParseResult();
    if (!directory.existsSync()) {
      return result;
    }

    /// has metadata => downloaded by JHenTai, continue
    if (io.File(join(directory.path, GalleryDownloadService.metadataFileName)).existsSync()) {
      return result;
    }
    if (io.File(join(directory.path, ArchiveDownloadService.metadataFileName)).existsSync()) {
      return result;
    }

    /// list all files
    List<io.FileSystemEntity> entities;
    try {
      entities = directory.listSync();
    } on Exception catch (e) {
      Log.error('List directory error!', e);
      Log.upload(Exception('List directory error!'), extraInfos: {'path': directory.path});
      return result;
    }

    String parentPath = directory.parent.path;

    /// load images
    List<io.File> imageFiles = entities.whereType<io.File>().where((image) => FileUtil.isImageExtension(image.path)).toList();
    result.isLegalGalleryDir = imageFiles.isNotEmpty;
    result.imageCount = imageFiles.length;
    if (result.isLegalGalleryDir) {
      _initGalleryInfoInMemory(directory, imageFiles, parentPath);
    }

    /// parse sub directories
    List<io.Directory> subDirectories = entities.whereType<io.Directory>().toList();
    for (io.Directory subDir in subDirectories) {
      LocalGalleryParseResult subResult = _parseDirectory(subDir);
      if (subResult.isLegalGalleryDir || subResult.isLegalNestedGalleryDir) {
        result.isLegalNestedGalleryDir = true;
      }
    }
    if (result.isLegalNestedGalleryDir) {
      (path2SubDir[parentPath] ??= []).add(directory.path);
    }

    return result;
  }

  void _initGalleryInfoInMemory(io.Directory galleryDir, List<io.File> imageFiles, String parentPath) {
    io.File ehvMetadata = io.File(join(galleryDir.path, '.ehviewer'));
    String? galleryUrl;
    if (ehvMetadata.existsSync()) {
      galleryUrl = _parseGalleryUrlFromEHVMetadata(ehvMetadata);
    }

    LocalGallery gallery = LocalGallery(
      title: basename(galleryDir.path),
      path: galleryDir.path,
      cover: GalleryImage(
        url: 'localImage',
        path: imageFiles.first.path,
        downloadStatus: DownloadStatus.downloaded,
      ),
      pageCount: imageFiles.length,
      time: galleryDir.statSync().modified,
      galleryUrl: galleryUrl,
    );

    allGallerys.add(gallery);
    (path2GalleryDir[parentPath] ??= []).add(gallery);
  }

  String? _parseGalleryUrlFromEHVMetadata(io.File ehvMetadata) {
    try {
      List<String> lines = ehvMetadata.readAsLinesSync();
      String gid = lines[2];
      String token = lines[3];
      return '${UserSetting.hasLoggedIn() ? EHConsts.EXIndex : EHConsts.EHIndex}/g/$gid/$token';
    } on Exception catch (e) {
      Log.error('Parse gallery url from ehv metadata failed!', e);
      Log.upload(e, extraInfos: {'ehvMetadata': ehvMetadata});
      return null;
    }
  }
}
