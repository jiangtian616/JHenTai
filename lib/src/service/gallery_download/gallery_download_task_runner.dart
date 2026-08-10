part of 'gallery_download_service.dart';

/// Orchestrates the per-gallery download pipeline: parse hrefs → parse urls →
/// download bytes, with retry, re-parse, and upgrade-migration shortcuts.
///
/// Each instance is bound to a single [GalleryDownloadInfo] but is stateless
/// across calls — runners are created on demand by [GalleryDownloadService].
/// State mutation (status, progress, queue submission) is delegated back to
/// the service via its library-private aliases.
class _GalleryDownloadTaskRunner {
  static const int _maxRetryTimes = 5;
  static const int _maxRetryTimes4FetchImageHashes = 3;

  final GalleryDownloadService _service;
  final GalleryDownloadInfo gallery;

  _GalleryDownloadTaskRunner(this._service, this.gallery);

  AsyncTask<void> downloadGalleryTask() {
    return () async {
      if (_service._taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      /// If this is a update from old gallery, try to fetch image hashes from JHenTai Server
      if (gallery.oldVersionGalleryUrl != null && downloadSetting.useJH2UpdateGallery.isTrue) {
        List<String> imageHashes = await fetchImageHashesFromJHenTaiServer();

        if (imageHashes.length == gallery.pageCount) {
          await _service._upgradeMigrator.copyImageInfosFromImageHashes(gallery, imageHashes);
        } else {
          log.error('Image hashes count mismatch, gid: ${gallery.gid}, expected: ${gallery.pageCount}, actual: ${imageHashes.length}');
        }
      }

      for (int serialNo = 0; serialNo < gallery.pageCount; serialNo++) {
        processImage(serialNo);
      }
    };
  }

  Future<List<String>> fetchImageHashesFromJHenTaiServer() async {
    if (_service._taskHasBeenPausedOrRemoved(gallery)) {
      return [];
    }

    String? cachedImageHashes = await localConfigService.read(configKey: ConfigEnum.galleryImageHash, subConfigKey: gallery.gid.toString());
    if (cachedImageHashes != null) {
      return jsonDecode(cachedImageHashes).cast<String>();
    }

    GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;

    try {
      JHResponse response = await retry(
        () => jhRequest.requestGalleryImageHashes(
          gid: gallery.gid,
          token: gallery.token,
          cancelToken: galleryDownloadInfo.cancelToken,
          parser: JHResponseParser.commonParse,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => log.download('Failed to fetch image hashes, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _maxRetryTimes4FetchImageHashes,
      );

      log.debug('Fetch image hashes response: $response');
      if (response.isSuccess) {
        FetchImageHashesVO fetchImageHashesVO = FetchImageHashesVO.fromResponse(response.data);
        localConfigService.write(configKey: ConfigEnum.galleryImageHash, subConfigKey: gallery.gid.toString(), value: jsonEncode(fetchImageHashesVO.hashes));
        return fetchImageHashesVO.hashes;
      } else {
        return [];
      }
    } on DioException catch (e) {
      log.error('Failed to fetch image hashes', e.errorMsg, e.stackTrace);
      return [];
    } catch (e) {
      log.error('Failed to fetch image hashes', e.toString(), StackTrace.current);
      return [];
    }
  }

  Future<void> processImage(int serialNo) async {
    if (_service._taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;

    /// has downloaded this image => nothing to do
    if (galleryDownloadInfo.imageAtSync(serialNo)?.downloadStatus == DownloadStatus.downloaded) {
      return;
    }

    /// step 3: url has been parsed (DB row exists) => download directly
    if (galleryDownloadInfo.imageAtSync(serialNo) != null) {
      return _service._submitImageTask(gallery, serialNo, () => downloadImageTask(serialNo));
    }

    /// step 2: has parsed href => parse url
    if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
      return _service._submitImageTask(gallery, serialNo, () => parseImageUrlTask(serialNo));
    }

    /// step 1: has not parsed href => parse href
    _service._submitImageTask(gallery, serialNo, () => parseImageHrefTask(serialNo));
  }

  AsyncTask<void> parseImageHrefTask(int serialNo) {
    return () async {
      if (_service._taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;
      int requestPageIndex = serialNo ~/ galleryDownloadInfo.thumbnailsCountPerPage;

      DetailPageInfo detailPageInfo;
      try {
        detailPageInfo = await retry(
          () => ehRequest.requestDetailPage(
            galleryUrl: gallery.galleryUrl,
            thumbnailsPageIndex: requestPageIndex,
            cancelToken: galleryDownloadInfo.cancelToken,
            parser: EHSpiderParser.detailPage2RangeAndThumbnails,
          ),
          retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download('Parse image hrefs failed, retry. Reason: ${(e as DioException).toString()}'),
          maxAttempts: _maxRetryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        return _service._submitImageTask(gallery, serialNo, () => parseImageHrefTask(serialNo));
      } on EHSiteException catch (e) {
        log.download('Parse image href error, reason: ${e.message}, gallery url: ${gallery.galleryUrl}');
        await _service._pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message);
        return;
      }

      /// some gallery's [thumbnailsCountPerPage] is not equal to default setting, we need to compute and update it.
      /// For example, default setting is 40, but some galleries' thumbnails has only high quality thumbnails, which results in 20.
      bool thumbnailsCountPerPageChanged = galleryDownloadInfo.thumbnailsCountPerPage != detailPageInfo.thumbnailsCountPerPage;
      galleryDownloadInfo.thumbnailsCountPerPage = detailPageInfo.thumbnailsCountPerPage;

      for (int i = detailPageInfo.imageNoFrom; i <= detailPageInfo.imageNoTo; i++) {
        galleryDownloadInfo.imageHrefs[i] = detailPageInfo.thumbnails[i - detailPageInfo.imageNoFrom];
      }

      /// if gallery's [thumbnailsCountPerPage] is not equal to default setting, we probably can't get target thumbnails this turn
      /// because the [thumbnailsPageIndex] we computed before is wrong, so we need to parse again
      if (galleryDownloadInfo.imageHrefs[serialNo] == null) {
        log.download(
          'Parse image hrefs error, thumbnails count per page is not equal to default setting, parse again. Thumbnails count per page: ${detailPageInfo.thumbnailsCountPerPage}, changed: $thumbnailsCountPerPageChanged',
        );
        await ehRequest.removeCacheByGalleryUrlAndPage(gallery.galleryUrl, requestPageIndex);
        return _service._submitImageTask(gallery, serialNo, () => parseImageHrefTask(serialNo));
      }

      /// Next step: parse image url
      _service._submitImageTask(gallery, serialNo, () => parseImageUrlTask(serialNo));
    };
  }

  AsyncTask<void> parseImageUrlTask(int serialNo, {bool reParse = false, String? reloadKey}) {
    return () async {
      if (_service._taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;

      /// If this is a update from old gallery, try to copy from existing old image first
      if (gallery.oldVersionGalleryUrl != null) {
        await _service._upgradeMigrator.tryCopyImageInfoFromHref(gallery.oldVersionGalleryUrl!, gallery, serialNo);

        if (galleryDownloadInfo.imageAtSync(serialNo) != null) {
          return;
        }
      }

      GalleryImage image;
      try {
        image = await retry(
          () => ehRequest.requestImagePage(
            galleryDownloadInfo.imageHrefs[serialNo]!.replacedMPVHref(serialNo + 1),
            reloadKey: reloadKey,
            cancelToken: galleryDownloadInfo.cancelToken,
            useCacheIfAvailable: !reParse,
            parser: EHSpiderParser.imagePage2GalleryImage,
          ),
          retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => log.download('Parse image url failed, retry. Reason: ${(e as DioException).errorMsg}'),
          maxAttempts: _maxRetryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        return _service._submitImageTask(gallery, serialNo, () => parseImageUrlTask(serialNo, reParse: true));
      } on EHParseException catch (e) {
        log.download('Parse image url error, reason: ${e.message.tr}');
        await _service._pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message.tr);

        ehRequest.removeCacheByUrl(galleryDownloadInfo.imageHrefs[serialNo]!.replacedMPVHref(serialNo + 1));

        return;
      } on EHSiteException catch (e) {
        log.download('Parse image url error, reason: ${e.message.tr}');
        await _service._pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message.tr);

        return;
      }

      /// Business layer: pick which URL to actually download from based on the
      /// gallery's `downloadOriginalImage` flag. The parser fills both `url`
      /// (regular) and `originalImageUrl` (original); the model itself has no
      /// opinion about which one to use.
      final String downloadUrl = _downloadUrlFor(gallery.toGalleryDownloadedData(), image);
      image.path = DownloadPathResolver.computeImageDownloadRelativePath(gallery.toGalleryDownloadedData(), downloadUrl, serialNo);
      image.downloadStatus = DownloadStatus.downloading;

      await _service._saveNewImageInfoInDatabase(image, serialNo, gallery.gid);

      galleryDownloadInfo.upsertImage(serialNo, image);

      /// Notify listeners (read page's local-mode builder watches this ID)
      /// that a freshly parsed image is now resident. Without this, a read
      /// page opened before this image was parsed would keep showing the
      /// "parsing url" placeholder even after the image is available.
      _service.update(['${_service.downloadImageId}::${gallery.gid}::$serialNo', '${_service.downloadImageUrlId}::${gallery.gid}::$serialNo']);

      log.download('Parse image url success, index: $serialNo, url: $downloadUrl');

      /// Next step: download image
      return _service._submitImageTask(gallery, serialNo, () => downloadImageTask(serialNo));
    };
  }

  AsyncTask<void> downloadImageTask(int serialNo) {
    return () async {
      if (_service._taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;
      /// Image may be cleared between the sync read and the async fallback by
      /// a concurrent `_reParseImageUrlAndDownload` (403 re-parse on the same
      /// serialNo calls `clearImage`). The `!` would NPE in that window.
      /// Re-check status after the await — if paused/removed or image gone,
      /// bail out; the re-parse path will re-submit when ready.
      final GalleryImage? image = galleryDownloadInfo.imageAtSync(serialNo) ?? await galleryDownloadInfo.imageAt(serialNo);
      if (image == null || _service._taskHasBeenPausedOrRemoved(gallery)) {
        return;
      }

      await _service._updateImageStatus(gallery, image, serialNo, DownloadStatus.downloading);

      /// If this is a update from old gallery, try to copy from existing old image first
      if (gallery.oldVersionGalleryUrl != null) {
        await _service._upgradeMigrator.tryCopyImageInfoFromImage(gallery.oldVersionGalleryUrl!, gallery, serialNo);

        if (image.downloadStatus == DownloadStatus.downloaded) {
          return;
        }
      }

      final String downloadUrl = _downloadUrlFor(gallery.toGalleryDownloadedData(), image);
      String path = DownloadPathResolver.computeImageDownloadAbsolutePath(gallery.toGalleryDownloadedData(), downloadUrl, serialNo);

      await tryLoadFromCacheInsteadDownload(image, downloadUrl, serialNo, path);
      if (image.downloadStatus == DownloadStatus.downloaded) {
        return;
      }

      Response response;
      try {
        response = await retry(
          () => ehRequest.download(
            url: downloadUrl,
            path: path,
            receiveTimeout: 3 * 60 * 1000,
            cancelToken: galleryDownloadInfo.cancelToken,
            onReceiveProgress: (int count, int total) => galleryDownloadInfo.speedComputer.updateProgress(count, total, serialNo),
          ),
          maxAttempts: _maxRetryTimes,

          /// 403 is due to broken H@H node, we should re-parse
          /// If we have not downloaded any bytes, we should re-parse because we might encounter a death H@H node
          retryIf: (e) =>
              e is DioException &&
              e.type != DioExceptionType.cancel &&
              (e.response == null || e.response!.statusCode != 403) &&
              galleryDownloadInfo.speedComputer.getImageDownloadedBytes(serialNo) > 0,
          onRetry: (e) {
            log.download('Download ${gallery.title} image: $serialNo failed, retry. Reason: ${(e as DioException).errorMsg}. Url:$downloadUrl');
            galleryDownloadInfo.speedComputer.resetProgress(serialNo);
          },
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }
        log.download('Download ${gallery.title} image: $serialNo failed, try re-parse. Reason: ${e.errorMsg}. Url:$downloadUrl');
        return _reParseImageUrlAndDownload(serialNo);
      } on EHSiteException catch (e) {
        log.download('Download Error, reason: ${e.message}');
        await _service._pauseOnSiteError(gallery: gallery, pauseAll: e.shouldPauseAllDownloadTasks, message: e.message);
        return;
      }

      /// what we downloaded is not an valid image
      if (!response.isRedirect && (response.headers[Headers.contentTypeHeader]?.contains("text/html; charset=UTF-8") ?? false)) {
        String data = io.File(path).readAsStringSync();

        EHImageException? exception = EHImageExceptionMatcher.match(data);
        log.error('Download ${gallery.title} image: $serialNo failed: $exception');

        if (exception != null) {
          if (exception.operation == EHImageExceptionAfterOperation.reParse) {
            return _reParseImageUrlAndDownload(serialNo);
          }
          return _service._pauseOnSiteError(
            gallery: gallery,
            pauseAll: exception.operation == EHImageExceptionAfterOperation.pauseAll,
            message: exception.message,
          );
        }
        return _service._pauseOnSiteError(gallery: gallery, pauseAll: false, message: 'downloadFailed'.tr);
      }

      log.download('Download ${gallery.title} image: $serialNo success');

      await _service._updateImageStatus(gallery, image, serialNo, DownloadStatus.downloaded);

      await _service._updateProgressAfterImageDownloaded(gallery, serialNo);
    };
  }

  /// the image's url may be invalid, try re-parse and then download
  Future<void> _reParseImageUrlAndDownload(int serialNo) async {
    if (_service._taskHasBeenPausedOrRemoved(gallery)) {
      return;
    }

    GalleryDownloadInfo galleryDownloadInfo = _service.galleryDownloadInfos[gallery.gid]!;

    String? reloadKey = galleryDownloadInfo.imageAtSync(serialNo)?.reloadKey;
    galleryDownloadInfo.clearImage(serialNo);
    await GalleryImageDao.deleteImage(gallery.gid, serialNo);

    /// has parsed href => parse url
    if (galleryDownloadInfo.imageHrefs[serialNo] != null) {
      return _service._submitImageTask(gallery, serialNo, () => parseImageUrlTask(serialNo, reParse: true, reloadKey: reloadKey));
    }

    /// has not parsed href => parse href
    return _service._submitImageTask(gallery, serialNo, () => parseImageHrefTask(serialNo));
  }

  Future<void> tryLoadFromCacheInsteadDownload(GalleryImage image, String downloadUrl, int serialNo, String path) async {
    io.File? cachedImageFile = await getCachedImageFile(downloadUrl);
    if (cachedImageFile != null && cachedImageFile.existsSync()) {
      log.debug('download image from cache, gallery: ${gallery.gid}, serialNo:$serialNo');
      await cachedImageFile.copy(path);
      await _service._updateImageStatus(gallery, image, serialNo, DownloadStatus.downloaded);
      await _service._updateProgressAfterImageDownloaded(gallery, serialNo);
    }
  }
}
