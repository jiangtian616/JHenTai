import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:executor/executor.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/snack_util.dart';
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
  Map<int, List<Rxn<GalleryImage>>> gid2Images = <int, List<Rxn<GalleryImage>>>{};

  Map<int, SpeedComputer> gid2SpeedComputer = {};

  static const int downloadRetryTimes = 3;

  static late final downloadPath;

  static const String _metadata = 'metadata';

  static Future<void> init() async {
    downloadPath = path.join(PathSetting.getVisibleDir().path, 'download');
    await io.Directory(downloadPath).create(recursive: true);
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
        _updateGalleryDownloadStatusInDatabase(gid, DownloadStatus.downloaded);
      }
    });

    /// resume if status is [downloading]
    for (GalleryDownloadedData g in gallerys) {
      if (g.downloadStatusIndex == DownloadStatus.downloading.index) {
        downloadGallery(g, isFirstDownload: false);
      }
    }
    Log.verbose('init DownloadService success, download task count: ${gallerys.length}', false);
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
      int success = await _saveNewGalleryDownloadInfoInDatabase(gallery);
      if (success < 0) {
        return;
      }
      _initGalleryDownloadInfoInMemory(gallery);
      if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
        _saveGalleryDownloadInfoInDisk(gallery);
      }
    }

    /// resume
    if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
      await resumeDownloadGallery(gallery);
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

      String imageAbsolutePath = _getImageDownloadAbsolutePath(gallery, serialNo);
      String imageRelativePath = _getImageDownloadRelativePath(gallery, serialNo);

      /// no parsed url, parse from page first
      if (gid2Images[gallery.gid]![serialNo].value == null) {
        await _getGalleryImageUrl(gallery, serialNo, imageRelativePath);
      }

      if (gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
        return;
      }

      _downloadGalleryImage(gallery, serialNo, imageAbsolutePath);
    }
  }

  Future<void> pauseAllDownloadGallery() async {
    await Future.wait(gallerys.map((g) => pauseDownloadGallery(g)).toList());
  }

  Future<void> pauseDownloadGallery(GalleryDownloadedData gallery) async {
    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.paused);
    gid2downloadProgress[gallery.gid]!.update((progress) {
      progress?.downloadStatus = DownloadStatus.paused;
    });
    gid2CancelToken[gallery.gid]!.cancel();
    gid2SpeedComputer[gallery.gid]!.pause();
    Log.info('pause download gallery: ${gallery.gid}', false);
  }

  Future<void> resumeDownloadGallery(GalleryDownloadedData gallery) async {
    await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloading);
    gid2downloadProgress[gallery.gid]!.update((progress) {
      progress?.downloadStatus = DownloadStatus.downloading;
    });
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
  }

  Future<void> deleteGallery(GalleryDownloadedData gallery) async {
    await pauseDownloadGallery(gallery);
    await _clearGalleryDownloadInfoInDatabase(gallery.gid);
    await _clearDownloadedImageInDisk(gallery);
    _clearGalleryDownloadInfoInMemory(gallery);
    Log.info('delete download gallery: ${gallery.gid}', false);
  }

  /// use meta in each gallery folder to restore download status, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restore() async {
    io.Directory downloadDir = io.Directory(downloadPath);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    List<io.FileSystemEntity> galleryDirs = downloadDir.listSync();
    for (io.FileSystemEntity galleryDir in galleryDirs) {
      io.File metadataFile = io.File(path.join(galleryDir.path, _metadata));
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());
      GalleryDownloadedData gallery = GalleryDownloadedData.fromJson(metadata['gallery']);
      List<GalleryImage?> images = (jsonDecode(metadata['images']) as List)
          .map((_map) => _map == null ? null : GalleryImage.fromJson(_map))
          .toList();

      /// skip if exists
      if (gid2Images.containsKey(gallery.gid)) {
        continue;
      }

      int success = await _restoreDownloadInfoDatabase(gallery, images);
      if (success < 0) {
        deleteGallery(gallery);
        continue;
      }
      _restoreDownloadInfoInMemory(gallery, images);
      restoredCount++;
    }

    return restoredCount;
  }

  Future<void> _getGalleryImageHref(GalleryDownloadedData gallery, int serialNo) async {
    List<GalleryThumbnail> newThumbnails;

    try {
      newThumbnails = await retry(
        () => executor.scheduleTask(
          () => EHRequest.requestDetailPage(
            galleryUrl: gallery.galleryUrl,
            thumbnailsPageNo: serialNo ~/ SiteSetting.thumbnailsCountPerPage.value,
            cancelToken: gid2CancelToken[gallery.gid],
            parser: EHSpiderParser.detailPage2Thumbnails,
          ),
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) {
          Log.error('getMoreThumbnails failed, retry', (e as DioError).message);
        },
        maxAttempts: downloadRetryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      await _getGalleryImageHref(gallery, serialNo);
      return;
    }

    int from = serialNo ~/ SiteSetting.thumbnailsCountPerPage.value * SiteSetting.thumbnailsCountPerPage.value;
    for (int i = 0; i < newThumbnails.length; i++) {
      gid2ImageHrefs[gallery.gid]![from + i].value = newThumbnails[i];
    }
    Log.verbose('getMoreThumbnails success', false);
  }

  Future<void> _getGalleryImageUrl(GalleryDownloadedData gallery, int serialNo, String imagePath,
      [bool useCache = true]) async {
    GalleryImage image;

    try {
      image = await retry(
        () => executor.scheduleTask(
          () => EHRequest.requestImagePage(
            gid2ImageHrefs[gallery.gid]![serialNo].value!.href,
            cancelToken: gid2CancelToken[gallery.gid],
            useCacheIfAvailable: useCache,
            parser: EHSpiderParser.imagePage2GalleryImage,
          ),
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) {
          Log.error('parseImageUrl failed, retry', (e as DioError).message);
        },
        maxAttempts: downloadRetryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        await pauseAllDownloadGallery();
        return;
      }
      await _getGalleryImageUrl(gallery, serialNo, imagePath, useCache);
      return;
    }

    Log.verbose('parseImageUrl: $serialNo success', false);
    image.downloadStatus = DownloadStatus.downloading;
    image.path = imagePath;
    gid2Images[gallery.gid]![serialNo].value = image;
    await _saveNewImageInfoInDatabase(image, serialNo, gallery.gid);
  }

  Future<void> _downloadGalleryImage(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    try {
      await retry(
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
            },
          ),
        ),
        maxAttempts: downloadRetryTimes,
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) async {
          Log.error('downloadImage: $serialNo failed, retry. url:${gid2Images[gallery.gid]![serialNo].value!.url}',
              (e as DioError).message);
          gid2SpeedComputer[gallery.gid]!.allImageDownloadedBytes -=
              gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value;
          gid2SpeedComputer[gallery.gid]!.imageDownloadedBytes[serialNo].value = 0;
        },
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.error is EHException) {
        Log.error('Download Error', e.error.msg);
        snack('error'.tr, e.error.msg, longDuration: true, closeBefore: true);
        pauseAllDownloadGallery();
        return;
      }
      Log.error(
          'downloadImage: $serialNo failed $downloadRetryTimes times, try re-parse. url:${gid2Images[gallery.gid]![serialNo].value!.url}');
      _reParseImageUrlAndDownload(gallery, serialNo, downloadPath);
      return;
    }

    Log.verbose('downloadImage: $serialNo success', false);
    gid2downloadProgress[gallery.gid]!.update((progress) {
      progress?.curCount++;
      progress?.hasDownloaded[serialNo] = true;
    });
    gid2Images[gallery.gid]![serialNo].update((image) {
      image?.downloadStatus = DownloadStatus.downloaded;
    });

    await _updateImageDownloadStatusInDatabase(gid2Images[gallery.gid]![serialNo].value!.url);

    /// all image has been downloaded
    if (gid2downloadProgress[gallery.gid]!.value.curCount == gid2downloadProgress[gallery.gid]!.value.totalCount) {
      gid2downloadProgress[gallery.gid]!.update((progress) {
        progress?.downloadStatus = DownloadStatus.downloaded;
      });
      await _updateGalleryDownloadStatusInDatabase(gallery.gid, DownloadStatus.downloaded);
      gid2SpeedComputer[gallery.gid]!.dispose();
    }

    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(gallery);
    }
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(GalleryDownloadedData gallery, int serialNo, String downloadPath) async {
    await appDb.deleteImage(gid2Images[gallery.gid]![serialNo].value!.url);
    await _getGalleryImageUrl(gallery, serialNo, downloadPath, false);
    _downloadGalleryImage(gallery, serialNo, downloadPath);
  }

  String _getGalleryDownloadPath(GalleryDownloadedData gallery) {
    return path.join(
      downloadPath,
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
    );
  }

  String _getImageDownloadRelativePath(GalleryDownloadedData gallery, int serialNo) {
    return path.relative(
      path.join(
        downloadPath,
        '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
        '$serialNo.jpg',
      ),
      from: PathSetting.getVisibleDir().path,
    );
  }

  String _getImageDownloadAbsolutePath(GalleryDownloadedData gallery, int serialNo) {
    return path.join(
      downloadPath,
      '${gallery.gid} - ${gallery.title}'.replaceAll(RegExp(r'[/|?,:*"<>]'), ' '),
      '$serialNo.jpg',
    );
  }

  /// init memory info
  void _initGalleryDownloadInfoInMemory(GalleryDownloadedData gallery) {
    gallerys.insert(0, gallery);
    gid2CancelToken[gallery.gid] = CancelToken();
    gid2downloadProgress[gallery.gid] = DownloadProgress(totalCount: gallery.pageCount).obs;
    gid2Images[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn<GalleryImage>(null)).obs;
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn(null));
    gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
  }

  void _clearGalleryDownloadInfoInMemory(GalleryDownloadedData gallery) {
    gallerys.remove(gallery);
    gid2downloadProgress.remove(gallery.gid);
    gid2Images.remove(gallery.gid);
    gid2ImageHrefs.remove(gallery.gid);
    gid2SpeedComputer[gallery.gid]!.dispose();
    gid2SpeedComputer.remove(gallery.gid);
  }

  Future<void> _clearDownloadedImageInDisk(GalleryDownloadedData gallery) async {
    io.Directory directory = io.Directory(_getGalleryDownloadPath(gallery));
    if (!directory.existsSync()) {
      return;
    }
    directory.deleteSync(recursive: true);
  }

  /// clear table row in database
  Future<void> _clearGalleryDownloadInfoInDatabase(int gid) {
    return appDb.transaction(() async {
      await appDb.deleteImagesWithGid(gid);
      await appDb.deleteGallery(gid);
    });
  }

  /// record a new download task
  Future<int> _saveNewGalleryDownloadInfoInDatabase(GalleryDownloadedData gallery) async {
    return await appDb.insertGallery(
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

  void _saveGalleryDownloadInfoInDisk(GalleryDownloadedData gallery) {
    io.File file = io.File(path.join(_getGalleryDownloadPath(gallery), _metadata));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    Map<String, Object> metadata = {
      'gallery': gallery.toJson(),
      'images': jsonEncode(gid2Images[gallery.gid]!),
    };

    file.writeAsStringSync(jsonEncode(metadata));
  }

  /// parse a image's url successfully, need to record its info and with its status beginning at 'downloading'
  Future<int> _saveNewImageInfoInDatabase(GalleryImage image, int serialNo, int gid) {
    return appDb.insertImage(
      image.url,
      serialNo,
      gid,
      image.height,
      image.width,
      image.path!,
      image.downloadStatus.index,
    );
  }

  /// update gallery status
  Future<int> _updateGalleryDownloadStatusInDatabase(int gid, DownloadStatus downloadStatus) {
    return appDb.updateGallery(downloadStatus.index, gid);
  }

  /// a image has been downloaded successfully, update its status
  Future<int> _updateImageDownloadStatusInDatabase(String url) {
    return appDb.updateImage(DownloadStatus.downloaded.index, url);
  }

  /// restore
  Future<int> _restoreDownloadInfoDatabase(GalleryDownloadedData gallery, List<GalleryImage?> images) async {
    gallery = gallery.copyWith(downloadStatusIndex: DownloadStatus.paused.index);
    int success = await _saveNewGalleryDownloadInfoInDatabase(gallery);
    if (success <= 0) {
      return success;
    }

    List<int> successes = await Future.wait(
      images.mapIndexed((index, image) {
        if (image == null) {
          return Future.value(1);
        }
        return _saveNewImageInfoInDatabase(image, index, gallery.gid);
      }).toList(),
    );

    return successes.any((e) => e <= 0) ? -1 : 1;
  }

  /// restore
  void _restoreDownloadInfoInMemory(GalleryDownloadedData gallery, List<GalleryImage?> images) {
    gallerys.insert(0, gallery);
    gid2CancelToken[gallery.gid] = CancelToken();
    List<bool> hasDownloaded =
        images.map((image) => image?.downloadStatus == DownloadStatus.downloaded ? true : false).toList();
    gid2downloadProgress[gallery.gid] = DownloadProgress(
      downloadStatus: DownloadStatus.paused,
      totalCount: gallery.pageCount,
      hasDownloaded: hasDownloaded,
    ).obs;
    gid2Images[gallery.gid] = images.map((e) => Rxn(e)).toList();
    gid2ImageHrefs[gallery.gid] = List.generate(gallery.pageCount, (index) => Rxn(null));
    gid2SpeedComputer[gallery.gid] = SpeedComputer(gid2downloadProgress[gallery.gid]!.value);
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
