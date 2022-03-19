import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:retry/retry.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/download_progress.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxService {
  final StorageService _storageService = Get.find();
  final executor = Executor(concurrency: 4);

  Rx<LinkedHashMap<int, Gallery>> gid2gallery = LinkedHashMap<int, Gallery>().obs;
  Rx<LinkedHashMap<int, DownloadProgress>> gid2downloadProgress = LinkedHashMap<int, DownloadProgress>().obs;
  Rx<LinkedHashMap<int, List<GalleryImage>>> gid2galleryImages = LinkedHashMap<int, List<GalleryImage>>().obs;
  Rx<LinkedHashMap<int, List<String>>> gid2ImageHref = LinkedHashMap<int, List<String>>().obs;
  Rx<LinkedHashMap<int, List<String>>> gid2ImageUrls = LinkedHashMap<int, List<String>>().obs;

  static Future<void> init() async {
    Get.lazyPut<DownloadService>(() => DownloadService());
    await Directory(path.join(PathSetting.getVisiblePath().path, 'download')).create(recursive: true);
    Log.info('DownloadService init success', false);
  }

  /// download all images of a gallery
  Future<void> downloadGallery(Gallery gallery, {ProgressCallback? onReceiveProgress, CancelToken? cancelToken}) async {
    if (gid2downloadProgress.value.containsKey(gallery.gid)) {
      return;
    }
    gid2gallery.value[gallery.gid] = gallery;
    DownloadProgress downloadProgress = DownloadProgress(totalCount: gallery.pageCount, curCount: 0, speed: '0 KB/s');
    gid2downloadProgress.value[gallery.gid] = downloadProgress;
    gid2galleryImages.value[gallery.gid] = [];
    gid2ImageHref.value[gallery.gid] = [];
    gid2ImageUrls.value[gallery.gid] = [];
    await _saveDownloadProgress(gallery.gid, downloadProgress);

    for (int i = 0; i < min(downloadProgress.totalCount, 10); i++) {
      if (gid2ImageHref.value[gallery.gid]!.length <= i) {
        await retry(
          () => executor
              .scheduleTask(
            () => EHRequest.getGalleryDetailsThumbnailByPageNo(
              galleryUrl: gallery.galleryUrl,
              thumbnailsPageNo: i ~/ 40,
            ),
          )
              .then((newThumbnails) {
            Log.info('getMoreThumbnails success', false);
            List<String> imageHrefs = newThumbnails.map((thumbnail) => thumbnail.href).toList();
            gid2ImageHref.value[gallery.gid]!.addAll(imageHrefs);
          }),
          retryIf: (e) => e is DioError,
          onRetry: (e) {
            Log.error('getMoreThumbnails: failed, retry', (e as DioError).message);
          },
        );
      }

      if (gid2ImageUrls.value[gallery.gid]!.length <= i) {
        await retry(
          () => executor
              .scheduleTask(
            () => executor.scheduleTask(() => EHRequest.getGalleryImage(gid2ImageHref.value[gallery.gid]![i])),
          )
              .then((image) {
            Log.info('parseImageUrl: $i success', false);
            gid2ImageUrls.value[gallery.gid]!.add(image.url);
            image.downloadStatus = DownloadStatus.downloading;
            gid2galleryImages.value[gallery.gid]!.add(image);
          }),
          retryIf: (e) => e is DioError,
          onRetry: (e) {
            Log.error('getMoreThumbnails: failed, retry', (e as DioError).message);
          },
        );
      }

      String downloadPath = path.join(
        PathSetting.getVisiblePath().path,
        'download',
        '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
        '$i.jpg',
      );

      retry(
        () => executor.scheduleTask(
          () => EHRequest.downloadGalleryImage(
            url: gid2ImageUrls.value[gallery.gid]![i],
            path: downloadPath,
          ).then((success) {
            Log.info('downloadImage: $i success', false);
            gid2downloadProgress.value[gallery.gid]!.curCount++;
            gid2downloadProgress.value[gallery.gid]!.hasDownloaded[i] = true;
          }),
        ),
        retryIf: (e) => e is DioError,
        onRetry: (e) async {
          Log.error(
              'downloadImage: $i failed, retry. url:${gid2ImageUrls.value[gallery.gid]![i]}', (e as DioError).message);
        },
      );
    }
  }

  Future<void> _saveDownloadProgress(int gid, DownloadProgress downloadProgress) async {
    String key = 'downloadProgress::$gid';
    await _storageService.write(key, downloadProgress.toMap());
  }
}
