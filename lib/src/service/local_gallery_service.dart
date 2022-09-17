import 'dart:io' as io;

import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:path/path.dart';

import '../model/gallery_image.dart';
import '../setting/download_setting.dart';
import '../utils/log.dart';
import 'archive_download_service.dart';

class LocalGallery {
  String title;
  String path;
  int pageCount;
  List<GalleryImage> images;
  DateTime time;

  LocalGallery({
    required this.title,
    required this.path,
    required this.pageCount,
    required this.images,
    required this.time,
  });
}

/// Load galleries in download directory but is not downloaded by JHenTai
class LocalGalleryService extends GetxController {
  static const String galleryCountChangedId = 'galleryCountChangedId';

  List<LocalGallery> allGallerys = [];
  Map<String, List<LocalGallery>> path2Gallerys = {};
  Map<String, List<String>> path2Directories = {};

  static Future<void> init() async {
    Get.put(LocalGalleryService(), permanent: true);
  }

  @override
  onInit() async {
    int count = await _loadGalleriesFromDisk();

    Log.debug('Init LocalGalleryService success. Galleries count: $count');

    super.onInit();
  }

  void deleteGallery(LocalGallery gallery, String parentPath) {
    Log.info('Delete local gallery: ${gallery.title}');

    io.Directory dir = io.Directory(gallery.path);
    dir.delete(recursive: true).catchError((e) {
      Log.error('Delete local gallery error!', e);
      Log.upload(e);
    });

    allGallerys.removeWhere((g) => g.title == gallery.title);
    path2Gallerys[parentPath]?.removeWhere((g) => g.title == gallery.title);

    update([galleryCountChangedId]);
  }

  Future<int> refreshLocalGallerys() async {
    int preCount = allGallerys.length;

    allGallerys.clear();
    path2Gallerys.clear();
    path2Directories.clear();
    int newCount = await _loadGalleriesFromDisk();

    Log.info('Refresh local gallerys, preCount:$preCount, newCount: $newCount');

    return newCount - preCount;
  }

  Future<int> _loadGalleriesFromDisk() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    _parseDirectory(downloadDir);

    return allGallerys.length;
  }

  void _parseDirectory(io.Directory directory) {
    String parentPath = directory.path;

    List<io.Directory> directories;
    try {
      directories = directory.listSync().whereType<io.Directory>().toList();
    } on Exception catch (e) {
      Log.error('List directory error!', e);
      Log.upload(e, extraInfos: {'path': directory.path});
      return;
    }

    List<io.Directory> gallerysInCurrentPath = directories.where((dir) => _checkLegalGalleryDir(dir)).toList();
    List<io.Directory> nestedDirectoriesInCurrentPath = directories.where((dir) => _checkLegalNestedDirectories(dir)).toList();

    for (io.Directory galleryDir in gallerysInCurrentPath) {
      _initGalleryInfoInMemory(galleryDir, parentPath);
    }

    for (io.Directory childDir in nestedDirectoriesInCurrentPath) {
      (path2Directories[parentPath] ??= []).add(childDir.path);
      _parseDirectory(childDir);
    }
  }

  /// has images
  bool _checkLegalGalleryDir(io.Directory galleryDir) {
    /// has metadata => downloaded by JHenTai, continue
    if (io.File(join(galleryDir.path, GalleryDownloadService.metadataFileName)).existsSync()) {
      return false;
    }
    if (io.File(join(galleryDir.path, ArchiveDownloadService.metadataFileName)).existsSync()) {
      return false;
    }

    List<io.FileSystemEntity> entities;
    try {
      entities = galleryDir.listSync();
    } on Exception catch (e) {
      Log.error('Check legal gallery directory error!', e);
      Log.upload(Exception('Check legal gallery directory error!'), extraInfos: {'path': galleryDir.path});
      return false;
    }

    /// has at least one image
    for (io.FileSystemEntity image in entities) {
      if (image is! io.File) {
        continue;
      }

      return FileUtil.isImageExtension(image.path);
    }

    return false;
  }

  /// has valid child directories
  bool _checkLegalNestedDirectories(io.Directory galleryDir) {
    /// has metadata => downloaded by JHenTai, continue
    if (io.File(join(galleryDir.path, GalleryDownloadService.metadataFileName)).existsSync()) {
      return false;
    }
    if (io.File(join(galleryDir.path, ArchiveDownloadService.metadataFileName)).existsSync()) {
      return false;
    }

    List<io.Directory> childDirs = galleryDir.listSync().whereType<io.Directory>().toList();
    if (childDirs.isEmpty) {
      return false;
    }

    for (io.Directory childDir in childDirs) {
      if (_checkLegalGalleryDir(childDir) || _checkLegalNestedDirectories(childDir)) {
        return true;
      }
    }

    return false;
  }

  void _initGalleryInfoInMemory(io.Directory galleryDir, String parentPath) {
    List<io.File> imageFiles = galleryDir
        .listSync()
        .whereType<io.File>()
        .where((image) => FileUtil.isImageExtension(image.path))
        .toList()
      ..sort((a, b) => basename(a.path).compareTo(basename(b.path)));

    List<GalleryImage> images = [];
    for (io.File file in imageFiles) {
      Size size;
      try {
        size = ImageSizeGetter.getSize(FileInput(file));
      } on Exception catch (e) {
        Log.error('Parse local images failed! Path: ${file.path}', e);
        Log.upload(e, extraInfos: {'path': file.path, 'stat': file.statSync()});
        continue;
      } on Error catch (e) {
        Log.error('Parse local images failed! Path: ${file.path}', e);
        Log.upload(e, extraInfos: {'path': file.path, 'stat': file.statSync()});
        continue;
      }

      images.add(GalleryImage(
        url: 'localImage',
        path: file.path,
        height: size.height.toDouble(),
        width: size.width.toDouble(),
        downloadStatus: DownloadStatus.downloaded,
      ));
    }

    LocalGallery gallery = LocalGallery(
      title: basename(galleryDir.path),
      path: galleryDir.path,
      pageCount: images.length,
      images: images,
      time: galleryDir.statSync().modified,
    );

    allGallerys.add(gallery);
    (path2Gallerys[parentPath] ??= []).add(gallery);
  }
}
