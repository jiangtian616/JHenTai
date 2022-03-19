import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:collection/collection.dart';
import 'package:executor/executor.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:retry/retry.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/download_progress.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxService {
  final AppDb appDb = AppDb();
  final executor = Executor(concurrency: 4);

  RxList<GalleryDownloadedData> gallerys = <GalleryDownloadedData>[].obs;
  LinkedHashMap<int, Rx<DownloadProgress>> gid2downloadProgress = LinkedHashMap();

  LinkedHashMap<int, List<String?>> gid2ImageHrefs = LinkedHashMap();
  LinkedHashMap<int, RxList<Rxn<GalleryImage>>> gid2Images = LinkedHashMap();

  static Future<void> init() async {
    await Directory(path.join(PathSetting.getVisiblePath().path, 'download')).create(recursive: true);
    Get.put(DownloadService(), permanent: true);
  }

  @override
  onInit() async {
    /// get download info from database
    List<SelectGallerysWithImagesResult> selectGallerysWithImagesResults = await appDb.selectGallerysWithImages().get();

    for (SelectGallerysWithImagesResult result in selectGallerysWithImagesResults) {
      GalleryDownloadedData gallery = GalleryDownloadedData(
          gid: result.gid,
          token: result.token,
          title: result.title,
          category: result.category,
          pageCount: result.pageCount,
          galleryUrl: result.galleryUrl,
          uploader: result.uploader,
          publishTime: result.publishTime,
          downloadStatusIndex: result.galleryDownloadStatusIndex);

      if (gallerys.isEmpty || gallerys.last.gid != gallery.gid) {
        gallerys.add(gallery);
        gid2downloadProgress[gallery.gid] = DownloadProgress(
          totalCount: gallery.pageCount,
          curCount: 0,
          speed: '0 KB/s',
        ).obs;
        gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn<GalleryImage>(null)).obs;
        gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
      }

      /// no image in this gallery has been downloaded
      if (result.url == null) {
        return;
      }

      GalleryImage image = GalleryImage(
        url: result.url!,
        height: result.height!,
        width: result.width!,
        path: result.path!,
        downloadStatus: DownloadStatus.values[result.imageDownloadStatusIndex!],
      );
      int serialNo = result.serialNo!;

      gid2Images[gallery.gid]![serialNo].value = image;

      if (image.downloadStatus == DownloadStatus.downloaded) {
        gid2downloadProgress[gallery.gid]!.value.curCount++;
        gid2downloadProgress[gallery.gid]!.value.hasDownloaded[serialNo] = true;
      }
    }

    /// resume if status is [downloading]
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        downloadGallery(g, isFirstDownload: false);
      }
    }
    Log.info('DownloadService init success, download task count: ${gallerys.length}', false);
  }

  /// begin or resume downloading all images of a gallery
  Future<void> downloadGallery(GalleryDownloadedData gallery,
      {bool isFirstDownload = true, ProgressCallback? onReceiveProgress, CancelToken? cancelToken}) async {
    if (isFirstDownload && gid2downloadProgress.containsKey(gallery.gid)) {
      return;
    }

    Log.info('begin to download gallery: ${gallery.gid}', false);

    /// record downloaded gallery first if it's first download
    if (isFirstDownload) {
      int success = await _saveNewGallery(gallery);
      if (success < 0) {
        return;
      }
      _initGalleryDownloadInfo(gallery);
    }

    for (int serialNo = 0; serialNo < min(gid2downloadProgress[gallery.gid]!.value.totalCount, 30); serialNo++) {
      if (gid2ImageHrefs[gallery.gid]![serialNo] == null) {
        await _getGalleryImageHrefs(gallery, serialNo);
      }

      String downloadPath = _generateDownloadPath(gallery, serialNo);

      if (gid2Images[gallery.gid]![serialNo].value == null) {
        await _getGalleryImageUrls(gallery, serialNo, downloadPath);
      }

      /// this image has been downloaded (may be true at init stage)
      if (gid2Images[gallery.gid]![serialNo].value?.downloadStatus == DownloadStatus.downloaded) {
        /// last image has been downloaded
        if (serialNo == gid2downloadProgress[gallery.gid]!.value.totalCount) {
          await _updateDownloadedGalleryStatus(gallery.gid);
        }
        continue;
      }

      _downloadGalleryImage(gallery, serialNo, downloadPath);
    }
  }

  Future<void> _getGalleryImageHrefs(GalleryDownloadedData gallery, int serialNo) async {
    return retry(
      () => executor
          .scheduleTask(
        () => EHRequest.getGalleryDetailsThumbnailByPageNo(
          galleryUrl: gallery.galleryUrl,
          thumbnailsPageNo: serialNo ~/ 40,
        ),
      )
          .then((newThumbnails) {
        Log.info('getMoreThumbnails success', false);
        List<String> imageHrefs = newThumbnails.map((thumbnail) => thumbnail.href).toList();
        gid2ImageHrefs[gallery.gid]!.replaceRange(serialNo * 40, serialNo * 40 + imageHrefs.length, imageHrefs);
      }),
      retryIf: (e) => e is DioError,
      onRetry: (e) {
        Log.error('getMoreThumbnails failed, retry', (e as DioError).message);
      },
    );
  }

  Future<void> _getGalleryImageUrls(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    return retry(
      () => executor
          .scheduleTask(
        () => executor.scheduleTask(() => EHRequest.getGalleryImage(gid2ImageHrefs[gallery.gid]![serialNo]!)),
      )
          .then((image) async {
        Log.info('parseImageUrl: $serialNo success', false);
        image.downloadStatus = DownloadStatus.downloading;
        image.path = downloadPath;
        gid2Images[gallery.gid]![serialNo].value = image;
        await _saveNewImage(image, serialNo, gallery.gid);
      }),
      retryIf: (e) => e is DioError,
      onRetry: (e) {
        Log.error('parseImageUrl failed, retry', (e as DioError).message);
      },
    );
  }

  String _generateDownloadPath(GalleryDownloadedData gallery, int serialNo) {
    return path.join(
      PathSetting.getVisiblePath().path,
      'download',
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
      '$serialNo.jpg',
    );
  }

  Future<void> _downloadGalleryImage(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    retry(
      () => executor.scheduleTask(
        () => EHRequest.downloadGalleryImage(
          url: gid2Images[gallery.gid]![serialNo].value!.url,
          path: downloadPath,
        ).then((success) async {
          Log.info('downloadImage: $serialNo success', false);
          gid2downloadProgress[gallery.gid]!.update((progress) {
            progress?.curCount++;
            progress?.hasDownloaded[serialNo] = true;
          });
          gid2Images[gallery.gid]![serialNo].update((image) {
            image?.downloadStatus = DownloadStatus.downloaded;
          });

          await _updateDownloadedImageStatus(gid2Images[gallery.gid]![serialNo].value!.url);

          /// all image has been downloaded
          if (gid2downloadProgress[gallery.gid]!.value.curCount ==
              gid2downloadProgress[gallery.gid]!.value.totalCount) {
            gid2downloadProgress[gallery.gid]!.update((progress) {
              progress?.downloadStatus = DownloadStatus.downloaded;
            });
            await _updateDownloadedGalleryStatus(gallery.gid);
          }
        }),
      ),
      maxAttempts: 4,
      retryIf: (e) => e is DioError,
      onRetry: (e) async {
        Log.error('downloadImage: $serialNo failed, retry. url:${gid2Images[gallery.gid]![serialNo].value!.url}',
            (e as DioError).message);
      },
    ).catchError((error) {
      Log.error(
          'downloadImage: $serialNo failed 4 times, try re-parse. url:${gid2Images[gallery.gid]![serialNo].value!.url}');
      _reParseImageUrlAndDownload(gallery, serialNo, downloadPath);
    });
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    await appDb.deleteImage(gid2Images[gallery.gid]![serialNo].value!.url);
    await _getGalleryImageUrls(gallery, serialNo, downloadPath);
    _downloadGalleryImage(gallery, serialNo, downloadPath);
  }

  /// init memory info
  void _initGalleryDownloadInfo(GalleryDownloadedData gallery) {
    gallerys.add(gallery);
    gid2downloadProgress[gallery.gid] = DownloadProgress(
      totalCount: gallery.pageCount,
      curCount: 0,
      speed: '0 KB/s',
    ).obs;
    gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn<GalleryImage>(null)).obs;
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => null);
  }

  /// clear memory info
  void _clearGalleryDownloadInfo(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    gid2downloadProgress.remove(gallery.gid);
    gid2Images.remove(gallery.gid);
    gid2ImageHrefs.remove(gallery.gid);
  }

  /// clear images in disk
  void _clearDownloadedImage(GalleryDownloadedData gallery) {}

  /// clear table row in database
  void _clearGalleryInDatabase(GalleryDownloadedData gallery) {}

  /// record a new download task
  Future<int> _saveNewGallery(GalleryDownloadedData gallery) async {
    return appDb.insertGallery(
      gallery.gid,
      gallery.token,
      gallery.title,
      gallery.category,
      gallery.pageCount,
      gallery.galleryUrl,
      gallery.uploader,
      gallery.publishTime,
      gallery.downloadStatusIndex,
    );
  }

  /// parse a image's url successfully, need to record its info and with its status beginning at 'downloading'
  Future<int> _saveNewImage(GalleryImage image, int serialNo, int gid) async {
    return appDb.insertImage(
        image.url, serialNo, gid, image.height, image.width, image.path!, image.downloadStatus.index);
  }

  /// all images has been downloaded successfully, update its status
  Future<int> _updateDownloadedGalleryStatus(int gid) {
    return appDb.updateGallery(DownloadStatus.downloaded.index, gid);
  }

  /// a image has been downloaded successfully, update its status
  Future<int> _updateDownloadedImageStatus(String url) {
    return appDb.updateImage(DownloadStatus.downloaded.index, url);
  }
}
