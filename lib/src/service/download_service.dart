import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:async_task/async_task.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/download_progress.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';

import '../model/gallery_image.dart';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxService {
  final StorageService _storageService = Get.find();
  final asyncExecutor = AsyncExecutor(
    parallelism: 2,
    taskTypeRegister: () => [_Task(_TaskParam())],
  )..logger.enabled = true;

  LinkedHashMap<int, Gallery> gid2gallery = LinkedHashMap();
  LinkedHashMap<int, DownloadProgress> gid2downloadProgress = LinkedHashMap();
  LinkedHashMap<int, List<String?>> gid2ImageHref = LinkedHashMap();
  LinkedHashMap<int, List<String?>> gid2ImageUrls = LinkedHashMap();

  static Future<void> init() async {
    Get.lazyPut<DownloadService>(() => DownloadService());
    await Directory(PathSetting.getVisiblePath().uri.toFilePath() + 'download').create();
    Log.info('DownloadService init success', false);
  }

  /// download all images of a gallery
  Future<void> downloadGallery(Gallery gallery, {ProgressCallback? onReceiveProgress, CancelToken? cancelToken}) async {
    // if (gid2downloadProgress.containsKey(gallery.gid)) {
    //   return;
    // }
    gid2gallery[gallery.gid] = gallery;
    DownloadProgress downloadProgress = DownloadProgress(totalCount: gallery.pageCount, curCount: 0, speed: '0 KB/s');
    gid2downloadProgress[gallery.gid] = downloadProgress;
    gid2ImageHref[gallery.gid] = [];
    gid2ImageUrls[gallery.gid] = [];
    await _saveDownloadProgress(gallery.gid, downloadProgress);

    for (int i = 0; i < downloadProgress.totalCount; i++) {
      if (gid2ImageHref[gallery.gid]!.isEmpty || gid2ImageHref[gallery.gid]!.length < i) {
        List<GalleryThumbnail> newThumbnails = await asyncExecutor.execute(
          _Task(
            _TaskParam(
              type: _TaskType.getMoreThumbnails,
              galleryUrl: gallery.galleryUrl,
              pageNo: i ~/ 40,
            ),
          ),
        ) as List<GalleryThumbnail>;

        Log.info('getMoreThumbnails success', false);
        List<String> imageHrefs = newThumbnails.map((thumbnail) => thumbnail.href).toList();
        gid2ImageHref[gallery.gid]!.addAll(imageHrefs);
      }

      if (gid2ImageUrls[gallery.gid]!.isEmpty || gid2ImageUrls[gallery.gid]!.length <= i) {
        GalleryImage image = await asyncExecutor.execute(
          _Task(
            _TaskParam(type: _TaskType.parseImageUrl, imageHref: gid2ImageHref[gallery.gid]![i]),
          ),
        ) as GalleryImage;
        Log.info('parseImageUrl: $i success', false);
        gid2ImageUrls[gallery.gid]!.add(image.url);
      }

      String downloadPath =
          '${PathSetting.getVisiblePath().uri.toFilePath()}download/${gallery.gid} - ${gallery.title}/$i.jpg';
      asyncExecutor
          .execute(
        _Task(
          _TaskParam(
            type: _TaskType.downloadImage,
            imageUrl: gid2ImageUrls[gallery.gid]![i],
            downloadPath: downloadPath,
          ),
        ),
      )
          .then((success) {
        Log.info('downloadImage: $i success', false);
        gid2downloadProgress[gallery.gid]!.hasDownloaded[i] = true;
      });
    }
  }

  Future<void> _saveDownloadProgress(int gid, DownloadProgress downloadProgress) async {
    String key = 'downloadProgress::$gid';
    await _storageService.write(key, downloadProgress.toMap());
  }
}

class _Task extends AsyncTask<_TaskParam, dynamic> {
  _TaskParam param;

  _Task(this.param);

  @override
  FutureOr<dynamic> run() async {
    try {
      if (!EHRequest.inited) {
        await EHRequest.initInIsolate();
      }

      if (param.type == _TaskType.getMoreThumbnails) {
        return EHRequest.getGalleryDetailsThumbnailByPageNo(
            galleryUrl: param.galleryUrl!, thumbnailsPageNo: param.pageNo!);
      } else if (param.type == _TaskType.parseImageUrl) {
        return EHRequest.getGalleryImage(param.imageHref!);
      } else {
        return EHRequest.downloadGalleryImage(url: param.imageUrl!, path: param.downloadPath!);
      }
    } on DioError catch (e) {
      Log.error('isolate task DioError', false);
      return null;
    } on Exception catch (e) {
      Log.error('isolate task failed', false);
      return null;
    }
  }

  @override
  AsyncTaskChannel? channelInstantiator() => AsyncTaskChannel();

  @override
  _Task instantiate(_TaskParam parameters, [Map<String, SharedData>? sharedData]) {
    return _Task(parameters);
  }

  @override
  _TaskParam parameters() {
    return param;
  }
}

enum _TaskType {
  getMoreThumbnails,
  parseImageUrl,
  downloadImage,
}

class _TaskParam {
  _TaskType type;

  /// used for getMoreThumbnails
  String? galleryUrl;
  int? pageNo;

  /// used for parseImageUrl
  String? imageHref;

  /// used for downloadImage
  String? imageUrl;
  String? downloadPath;

  _TaskParam({
    this.type = _TaskType.downloadImage,
    this.galleryUrl,
    this.pageNo,
    this.imageHref,
    this.imageUrl,
    this.downloadPath,
  });
}
