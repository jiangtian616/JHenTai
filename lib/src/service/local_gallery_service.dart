import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:path/path.dart';

import '../model/gallery_image.dart';
import '../setting/download_setting.dart';
import '../utils/log.dart';
import 'archive_download_service.dart';

class LocalGallery {
  String title;
  String path;
  GalleryImage cover;

  bool isFromEHViewer;
  int? gid;
  String? token;

  String? get galleryUrl => isFromEHViewer ? '${UserSetting.hasLoggedIn() ? EHConsts.EXIndex : EHConsts.EHIndex}/g/$gid/$token' : null;

  LocalGallery({
    required this.title,
    required this.path,
    required this.cover,
    required this.isFromEHViewer,
    this.gid,
    this.token,
  });
}

class LocalGalleryParseResult {
  /// has images
  bool isLegalGalleryDir = false;

  /// has subDirectory that has images
  bool isLegalNestedGalleryDir = false;
}

/// Load galleries in download directory but is not downloaded by JHenTai
class LocalGalleryService extends GetxController {
  static const String galleryCountChangedId = 'galleryCountChangedId';
  static const String rootPath = '';

  List<LocalGallery> allGallerys = [];
  Map<String, List<LocalGallery>> path2GalleryDir = {};
  Map<String, List<String>> path2SubDir = {};

  Map<int, LocalGallery> gid2EHViewerGallery = {};

  List<String> get rootDirectories => path2SubDir[rootPath] ?? [];

  static void init() {
    Get.put(LocalGalleryService(), permanent: true);
  }

  Future<int> refreshLocalGallerys() {
    int preCount = allGallerys.length;

    allGallerys.clear();
    path2GalleryDir.clear();
    path2SubDir.clear();

    DateTime start = DateTime.now();

    return _loadGalleriesFromDisk().then((_) {
      Log.info(
        'Refresh local gallerys, preCount:$preCount, newCount: ${allGallerys.length}, timeCost: ${DateTime.now().difference(start).inMilliseconds}ms',
      );
      return allGallerys.length - preCount;
    });
  }

  List<GalleryImage> getGalleryImages(LocalGallery gallery) {
    List<File> imageFiles = Directory(gallery.path).listSync().whereType<File>().where((image) => FileUtil.isImageExtension(image.path)).toList()
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

    Directory dir = Directory(gallery.path);

    List<File> otherFiles = dir.listSync().whereType<File>().where((image) => !FileUtil.isImageExtension(image.path)).toList();
    if (otherFiles.isEmpty) {
      dir.delete(recursive: true).catchError((e) {
        Log.error('Delete local gallery error!', e);
        Log.upload(e);
      });
    } else {
      for (File file in otherFiles) {
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

  Future<void> _loadGalleriesFromDisk() {
    List<Future> futures = DownloadSetting.extraGalleryScanPath.map((path) => _parseDirectory(Directory(path), true)).toList();

    return Future.wait(futures);
  }

  Future<LocalGalleryParseResult> _parseDirectory(Directory directory, bool isRootDir) {
    Completer<LocalGalleryParseResult> completer = Completer();
    LocalGalleryParseResult result = LocalGalleryParseResult();

    Future<bool> future = directory.exists();

    /// skip if it is JHenTai gallery directory -> metadata file exists
    future = future.then<bool>((success) {
      if (success) {
        return File(join(directory.path, GalleryDownloadService.metadataFileName)).exists().then((value) => !value);
      } else {
        completer.isCompleted ? null : completer.complete(result);
        return false;
      }
    }).catchError((e, stack) {
      completer.isCompleted ? null : completer.completeError(e, stack);
      return false;
    });

    future = future.then<bool>((success) {
      if (success) {
        return File(join(directory.path, ArchiveDownloadService.metadataFileName)).exists().then((value) => !value);
      } else {
        completer.isCompleted ? null : completer.complete(result);
        return false;
      }
    }).catchError((e, stack) {
      completer.isCompleted ? null : completer.completeError(e, stack);
      return false;
    });

    /// recursively list all files in directory
    future = future.then<bool>((success) {
      if (success) {
        List<Future> subFutures = [];

        String parentPath = isRootDir ? rootPath : directory.parent.path;
        directory.list().listen(
          (entity) {
            if (entity is File && FileUtil.isImageExtension(entity.path) && result.isLegalGalleryDir == false) {
              result.isLegalGalleryDir = true;
              subFutures.add(_initGalleryInfoInMemory(directory, entity, parentPath));
            } else if (entity is Directory) {
              subFutures.add(
                _parseDirectory(entity, false).then((subResult) {
                  if (subResult.isLegalGalleryDir || subResult.isLegalNestedGalleryDir) {
                    result.isLegalNestedGalleryDir = true;
                    (path2SubDir[parentPath] ??= []).addIfNotExists(directory.path);
                  }
                }),
              );
            }
          },
          onDone: () {
            Future.wait(subFutures).then((_) {
              completer.isCompleted ? null : completer.complete(result);
            });
          },
          onError: completer.completeError,
        );
      } else {
        completer.isCompleted ? null : completer.complete(result);
      }
      return success;
    }).catchError((e, stack) {
      completer.isCompleted ? null : completer.completeError(e, stack);
      return false;
    });

    return completer.future;
  }

  Future<void> _initGalleryInfoInMemory(Directory galleryDir, File coverImage, String parentPath) {
    /// if the gallery is downloaded by ehviewer, read its metadata file to gain gallery url
    File ehvMetadata = File(join(galleryDir.path, '.ehviewer'));
    int? gid;
    String? token;

    return ehvMetadata.exists().then((success) {
      if (success) {
        return ehvMetadata.readAsLines().then((lines) {
          gid = int.tryParse(lines[2]);
          token = lines[3];
        });
      }
    }).then((_) {
      LocalGallery gallery = LocalGallery(
        title: basename(galleryDir.path.split('-').sublist(1).join('-')),
        path: galleryDir.path,
        cover: GalleryImage(
          url: 'localImage',
          path: coverImage.path,
          downloadStatus: DownloadStatus.downloaded,
        ),
        isFromEHViewer: gid != null && token != null,
        gid: gid,
        token: token,
      );

      allGallerys.add(gallery);
      (path2GalleryDir[parentPath] ??= []).add(gallery);
      if (gallery.isFromEHViewer) {
        gid2EHViewerGallery[gid!] = gallery;
      }
    }).catchError((e) {
      Log.error('Parse gallery url from ehv metadata failed!', e);
      Log.upload(e, extraInfos: {'ehvMetadata': ehvMetadata});
      return null;
    });
  }
}
