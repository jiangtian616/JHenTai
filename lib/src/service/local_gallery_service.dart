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

    int count = 0;
    for (io.FileSystemEntity galleryDir in downloadDir.listSync()) {
      if (galleryDir is! io.Directory) {
        continue;
      }

      /// has metadata => downloaded by JHenTai, continue
      if (io.File(join(galleryDir.path, GalleryDownloadService.metadataFileName)).existsSync()) {
        continue;
      }
      if (io.File(join(galleryDir.path, ArchiveDownloadService.metadataFileName)).existsSync()) {
        continue;
      }

      /// is not gallery directory
      if (!_checkLegalGalleryDir(galleryDir)) {
        continue;
      }

      _initGalleryInfoInMemory(galleryDir);

      count++;
    }

    return count;
  }

  /// has at least one image
  bool _checkLegalGalleryDir(io.Directory galleryDir) {
    List<io.FileSystemEntity> images = galleryDir.listSync();

    if (images.isEmpty) {
      return false;
    }

    for (io.FileSystemEntity image in images) {
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
    List<io.FileSystemEntity> files = galleryDir.listSync();
    files.sort((a, b) => basename(a.path).compareTo(basename(b.path)));
    files = files.where((image) => RegExp('.jpg|.png|.gif|.jpeg').firstMatch(extension(image.path)) != null).toList();

    List<GalleryImage> images = [];
    for (io.FileSystemEntity file in files) {
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
