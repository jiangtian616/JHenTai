import 'dart:async';
import 'dart:core';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:retry/retry.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/download_progress.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';
import '../utils/eh_spider_parser.dart';

/// responsible for local images meta-data and download all images of a gallery
class DownloadService extends GetxService {
  final executor = Executor(concurrency: DownloadSetting.downloadTaskConcurrency.value);

  RxList<GalleryDownloadedData> gallerys = <GalleryDownloadedData>[].obs;
  RxMap<int, Rx<DownloadProgress>> gid2downloadProgress = <int, Rx<DownloadProgress>>{}.obs;
  Map<int, CancelToken> gid2CancelToken = {};
  Map<int, List<Rxn<GalleryThumbnail>>> gid2ImageHrefs = {};
  Map<int, RxList<Rxn<GalleryImage>>> gid2Images = <int, RxList<Rxn<GalleryImage>>>{}.obs;

  Map<int, SpeedComputer> gid2SpeedComputer = {};

  static const int downloadRetryTimes = 3;

  static Future<void> init() async {
    await io.Directory(path.join(PathSetting.getVisibleDir().path, 'download')).create(recursive: true);
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
        downloadStatusIndex: result.galleryDownloadStatusIndex,
        insertTime: result.insertTime,
      );

      if (gallerys.isEmpty || gallerys.last.gid != gallery.gid) {
        gallerys.add(gallery);
        gid2CancelToken[gallery.gid] = CancelToken();
        gid2downloadProgress[gallery.gid] = DownloadProgress(
          totalCount: gallery.pageCount,
          downloadStatus: DownloadStatus.values[result.galleryDownloadStatusIndex],
        ).obs;
        gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn<GalleryImage>(null)).obs;
        gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn(null));
        gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
      }

      /// no image in this gallery has been downloaded
      if (result.url == null) {
        continue;
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

    /// when successfully download last image of a gallery, and app exit before we updateDownloadedGalleryStatus,
    /// then the gallery's status remains [downloading] with all its images downloaded. so everytime app launches,
    /// we check it.
    gid2downloadProgress.forEach((gid, progress) {
      if (progress.value.curCount == progress.value.totalCount &&
          progress.value.downloadStatus != DownloadStatus.downloaded) {
        _updateGalleryStatus(gid, DownloadStatus.downloaded);
      }
    });

    /// resume if status is [downloading]
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        downloadGallery(g, isFirstDownload: false);
      }
    }
    Log.info('init DownloadService success, download task count: ${gallerys.length}', false);
  }

  /// begin or resume downloading all images of a gallery
  /// step 1: get image href from its thumbnail, if thumbnail haven't been parsed, parse thumbnail first.
  /// step 2: get image url by parsing page (with href parsed last step)
  /// step 3: download image
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

    /// resume
    if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
      await resumeDownloadGalleryStatus(gallery);
    }

    gid2SpeedComputer[gallery.gid]!.start();
    for (int serialNo = 0; serialNo < gid2downloadProgress[gallery.gid]!.value.totalCount; serialNo++) {
      /// user has paused
      if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
        return;
      }

      /// has downloaded this image
      if (gid2Images[gallery.gid]![serialNo].value != null &&
          gid2Images[gallery.gid]![serialNo].value!.downloadStatus == DownloadStatus.downloaded) {
        continue;
      }

      /// no parsed href, parse from thumbnails first
      if (gid2ImageHrefs[gallery.gid]![serialNo].value == null) {
        await _getGalleryImageHref(gallery, serialNo);
      }

      if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
        return;
      }

      String downloadPath = _generateDownloadPath(gallery, serialNo);

      /// no parsed url, parse from page first
      if (gid2Images[gallery.gid]![serialNo].value == null) {
        await _getGalleryImageUrl(gallery, serialNo, downloadPath);
      }

      if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
        return;
      }

      _downloadGalleryImage(gallery, serialNo, downloadPath);
    }
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    await _updateGalleryStatus(gallery.gid, DownloadStatus.paused);
    gid2downloadProgress[gallery.gid]!.update((progress) {
      progress?.downloadStatus = DownloadStatus.paused;
    });
    gid2CancelToken[gallery.gid]!.cancel();
    gid2SpeedComputer[gallery.gid]!.pause();
    Log.info('pause download gallery: ${gallery.gid}', false);
  }

  Future<void> resumeDownloadGalleryStatus(GalleryDownloadedData gallery) async {
    await _updateGalleryStatus(gallery.gid, DownloadStatus.downloading);
    gid2downloadProgress[gallery.gid]!.update((progress) {
      progress?.downloadStatus = DownloadStatus.downloading;
    });
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery) async {
    await pauseDownloadGallery(gallery);
    await _clearGalleryInDatabase(gallery.gid);
    if (gid2downloadProgress[gallery.gid]!.value.curCount > 0) {
      await _clearDownloadedImage(gallery);
    }
    _clearGalleryDownloadInfo(gallery);
    Log.info('delete download gallery: ${gallery.gid}', false);
  }

  Future<void> _getGalleryImageHref(GalleryDownloadedData gallery, int serialNo) async {
    return retry(
      () => executor
          .scheduleTask(
        () => EHRequest.requestDetailPage(
          galleryUrl: gallery.galleryUrl,
          thumbnailsPageNo: serialNo ~/ SiteSetting.thumbnailsCountPerPage.value,
          cancelToken: gid2CancelToken[gallery.gid],
          parser: EHSpiderParser.detailPage2Thumbnails,
        ),
      )
          .then((newThumbnails) {
        Log.info('getMoreThumbnails success', false);
        int from = serialNo ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
        for (int i = 0; i < newThumbnails.length; i++) {
          gid2ImageHrefs[gallery.gid]![from + i].value = newThumbnails[i];
        }
      }),
      retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
      onRetry: (e) {
        Log.error('getMoreThumbnails failed, retry', (e as DioError).message);
      },
    ).catchError((error, stack) {
      if (error is! DioError) {
        throw error;
      }
      if (error.type == DioErrorType.cancel) {
        return;
      }
    });
  }

  Future<void> _getGalleryImageUrl(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    return retry(
      () => executor
          .scheduleTask(
        () => EHRequest.requestImagePage(
          gid2ImageHrefs[gallery.gid]![serialNo].value!.href,
          cancelToken: gid2CancelToken[gallery.gid],
          parser: EHSpiderParser.imagePage2GalleryImage,
        ),
      )
          .then((image) async {
        Log.info('parseImageUrl: $serialNo success', false);
        image.downloadStatus = DownloadStatus.downloading;
        image.path = downloadPath;
        gid2Images[gallery.gid]![serialNo].value = image;
        await _saveNewImage(image, serialNo, gallery.gid);
      }),
      retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
      onRetry: (e) {
        Log.error('parseImageUrl failed, retry', (e as DioError).message);
      },
    ).catchError((error, stack) {
      if (error is! DioError) {
        throw error;
      }
      if (error.type == DioErrorType.cancel) {
        return;
      }
    });
  }

  String _generateDownloadPath(GalleryDownloadedData gallery, int serialNo) {
    return path.join(
      PathSetting.getVisibleDir().path,
      'download',
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
      '$serialNo.jpg',
    );
  }

  Future<void> _downloadGalleryImage(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    retry(
      () => executor.scheduleTask(
        () => EHRequest.download(
            url: gid2Images[gallery.gid]![serialNo].value!.url,
            path: downloadPath,
            cancelToken: gid2CancelToken[gallery.gid],
            onReceiveProgress: (int count, int total) {
              gid2SpeedComputer[gallery.gid]!.imageTotalBytes[serialNo].value = total;
              gid2SpeedComputer[gallery.gid]!.allImageDownloadedBytes -=
                  gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value;
              gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value = count;
              gid2SpeedComputer[gallery.gid]!.allImageDownloadedBytes += count;
            }).then((success) async {
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
            await _updateGalleryStatus(gallery.gid, DownloadStatus.downloaded);
          }
        }),
      ),
      maxAttempts: downloadRetryTimes,
      retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
      onRetry: (e) async {
        Log.error('downloadImage: $serialNo failed, retry. url:${gid2Images[gallery.gid]![serialNo].value!.url}',
            (e as DioError).message);
        gid2SpeedComputer[gallery.gid]!.allImageDownloadedBytes -=
            gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value;
        gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value = 0;
      },
    ).catchError((error, stack) {
      if (error is! DioError) {
        throw error;
      }
      if (error.type == DioErrorType.cancel) {
        return;
      }
      Log.error(
          'downloadImage: $serialNo failed $downloadRetryTimes times, try re-parse. url:${gid2Images[gallery.gid]![serialNo].value!.url}');
      _reParseImageUrlAndDownload(gallery, serialNo, downloadPath);
    });
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    await appDb.deleteImage(gid2Images[gallery.gid]![serialNo].value!.url);
    await _getGalleryImageUrl(gallery, serialNo, downloadPath);
    _downloadGalleryImage(gallery, serialNo, downloadPath);
  }

  /// init memory info
  void _initGalleryDownloadInfo(GalleryDownloadedData gallery) {
    gallerys.insert(0, gallery);
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2downloadProgress[gallery.gid] = DownloadProgress(totalCount: gallery.pageCount).obs;
    gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn<GalleryImage>(null)).obs;
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn(null));
    gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
  }

  /// clear memory info
  void _clearGalleryDownloadInfo(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    gid2downloadProgress.remove(gallery.gid);
    gid2Images.remove(gallery.gid);
    gid2ImageHrefs.remove(gallery.gid);
    gid2SpeedComputer[gallery.gid]!.dispose();
    gid2SpeedComputer.remove(gallery.gid);
  }

  /// clear images in disk
  Future<io.FileSystemEntity> _clearDownloadedImage(GalleryDownloadedData gallery) {
    String directoryPath = path.join(
      PathSetting.getVisibleDir().path,
      'download',
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
    );

    io.File directory = io.File(directoryPath);
    return directory.delete(recursive: true);
  }

  /// clear table row in database
  Future<void> _clearGalleryInDatabase(int gid) {
    return appDb.transaction(() async {
      await appDb.deleteImagesWithGid(gid);
      await appDb.deleteGallery(gid);
    });
  }

  /// record a new download task
  Future<int> _saveNewGallery(GalleryDownloadedData gallery) {
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
      DateTime.now().toString(),
    );
  }

  /// parse a image's url successfully, need to record its info and with its status beginning at 'downloading'
  Future<int> _saveNewImage(GalleryImage image, int serialNo, int gid) {
    return appDb.insertImage(
        image.url, serialNo, gid, image.height, image.width, image.path!, image.downloadStatus.index);
  }

  /// update gallery status
  Future<int> _updateGalleryStatus(int gid, DownloadStatus downloadStatus) {
    return appDb.updateGallery(downloadStatus.index, gid);
  }

  /// a image has been downloaded successfully, update its status
  Future<int> _updateDownloadedImageStatus(String url) {
    return appDb.updateImage(DownloadStatus.downloaded.index, url);
  }
}

/// compute download speed during last period every second
class SpeedComputer {
  Timer? timer;
  final DownloadProgress downloadProgress;

  RxString speed = '0 B/s'.obs;

  late List<RxInt> imageDownloadedBytes;
  late List<RxInt> imageTotalBytes;

  int allImageDownloadedBytesLastTime = 0;
  int allImageDownloadedBytes = 0;

  SpeedComputer(this.downloadProgress)
      : imageDownloadedBytes = List.generate(downloadProgress.hasDownloaded.length, (index) => 0.obs),
        imageTotalBytes = List.generate(downloadProgress.hasDownloaded.length, (index) => 1.obs);

  void start() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int prevDownloadedBytesLast = allImageDownloadedBytesLastTime;
      allImageDownloadedBytesLastTime = allImageDownloadedBytes;

      double difference = 0.0 + allImageDownloadedBytes - prevDownloadedBytesLast;
      if (difference <= 0) {
        speed.value = '0 B/s';
        return;
      }
      if (difference < 1024) {
        speed.value = '${difference.toStringAsFixed(2)} B/s';
        return;
      }
      difference /= 1024;
      if (difference < 1024) {
        speed.value = '${difference.toStringAsFixed(2)} KB/s';
        return;
      }
      difference /= 1024;
      if (difference < 1024) {
        speed.value = '${difference.toStringAsFixed(2)} MB/s';
        return;
      }
      difference /= 1024;
      speed.value = '${difference.toStringAsFixed(2)} GB/s';
    });
  }

  void pause() {
    timer?.cancel();
    speed.value = '0 KB/s';
  }

  void dispose() {
    timer?.cancel();
  }
}
