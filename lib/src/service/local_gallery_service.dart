import 'dart:io' as io;

import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:path/path.dart';

import '../model/gallery_image.dart';
import '../setting/download_setting.dart';
import '../utils/log.dart';

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
  static const String refreshId = 'refreshId';

  List<LocalGallery> gallerys = [];

  static Future<void> init() async {
    Get.put(LocalGalleryService(), permanent: true);
  }

  @override
  onInit() async {
    int count = await _loadGalleriesFromDisk();

    Log.info('Init LocalGalleryService success. Galleries count: $count');

    super.onInit();
  }

  void deleteGallery(LocalGallery gallery) {
    Log.info('Delete local gallery: ${gallery.title}');

    io.Directory dir = io.Directory(gallery.path);
    dir.deleteSync(recursive: true);
    gallerys.removeWhere((g) => g.title == gallery.title);
    update([refreshId]);
  }

  Future<int> refreshLocalGallerys() async {
    int preCount = gallerys.length;

    gallerys.clear();
    int newCount = await _loadGalleriesFromDisk();

    Log.info('Refresh local gallerys, preCount:$preCount, newCount: $newCount');

    update([refreshId]);
    return newCount - preCount;
  }

  Future<int> _loadGalleriesFromDisk() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    List<io.Directory> galleryDirs = downloadDir
        .listSync(
          recursive: true,
        )
        .whereType<io.Directory>()
        .where((dir) => _checkLegalGalleryDir(dir))
        .toList();

    for (io.Directory galleryDir in galleryDirs) {
      _initGalleryInfoInMemory(galleryDir);
    }

    return galleryDirs.length;
  }

  bool _checkLegalGalleryDir(io.Directory galleryDir) {
    /// has metadata => downloaded by JHenTai, continue
    if (io.File(join(galleryDir.path, GalleryDownloadService.metadataFileName)).existsSync()) {
      return false;
    }
    if (io.File(join(galleryDir.path, ArchiveDownloadService.metadataFileName)).existsSync()) {
      return false;
    }

    List<io.FileSystemEntity> entities = galleryDir.listSync();

    /// has at least one image
    for (io.FileSystemEntity image in entities) {
      if (image is! io.File) {
        continue;
      }

      String ext = extension(image.path);
      if (ext == '.jpg' || ext == '.png' || ext == '.gif' || ext == '.jpeg') {
        return true;
      }
    }

    return false;
  }

  void _initGalleryInfoInMemory(io.Directory galleryDir) {
    List<io.File> imageFiles = galleryDir
        .listSync()
        .whereType<io.File>()
        .where((image) => RegExp('.jpg|.png|.gif|.jpeg').firstMatch(extension(image.path)) != null)
        .toList();
    imageFiles.sort((a, b) => basename(a.path).compareTo(basename(b.path)));

    List<GalleryImage> images = [];
    for (io.FileSystemEntity file in imageFiles) {
      Size size;
      try {
        size = ImageSizeGetter.getSize(FileInput(file as io.File));
      } on Exception catch (e) {
        Log.error("Parse local images failed!", e);
        Log.upload(e, extraInfos: {'file': file.path});
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

    gallerys.add(LocalGallery(
      title: basename(galleryDir.path),
      path: galleryDir.path,
      pageCount: images.length,
      images: images,
      time: galleryDir.statSync().modified,
    ));
  }
}
