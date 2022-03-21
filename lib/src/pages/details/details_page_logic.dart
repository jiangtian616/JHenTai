import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/widget/favorite_dialog.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:jhentai/src/pages/details/widget/rating_dialog.dart';

import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../service/download_service.dart';
import '../../service/storage_service.dart';
import '../home/tab_view/gallerys/gallerys_view_logic.dart';
import 'details_page_state.dart';

class DetailsPageLogic extends GetxController {
  final DetailsPageState state = DetailsPageState();
  final DownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();

  DetailsPageLogic() {
    dynamic arg = Get.arguments;

    /// enter from galleryPage
    if (arg is Gallery) {
      state.gallery = arg;
      state.thumbnailsPageCount = arg.pageCount ~/ 40;
      getDetails();
    }
  }

  @override
  void onInit() async {
    /// enter from downloadPage
    dynamic arg = Get.arguments;

    if (arg is GalleryDownloadedData) {
      Map<String, dynamic> galleryAndDetailsAndApikey = await EHRequest.getGalleryAndDetailsByUrl(arg.galleryUrl);
      state.gallery = galleryAndDetailsAndApikey['gallery']!;
      state.galleryDetails = galleryAndDetailsAndApikey['galleryDetails']!;
      state.apikey = galleryAndDetailsAndApikey['apikey']!;
      state.thumbnailsPageCount = state.gallery!.pageCount ~/ 40;
      state.loadingDetailsState = LoadingState.success;
      update();
    }
  }

  void showLoginSnack() {
    Get.snackbar('operationFailed'.tr, 'needLoginToOperate'.tr);
  }

  void getDetails() async {
    if (state.loadingDetailsState == LoadingState.loading || state.loadingDetailsState == LoadingState.success) {
      return;
    }

    LoadingState prevState = state.loadingDetailsState;
    state.loadingDetailsState = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update();
    }

    Log.info('get gallery details', false);
    Map<String, dynamic> galleryDetailsAndApikey;
    try {
      galleryDetailsAndApikey = await EHRequest.getGalleryDetailsAndApikey(galleryUrl: state.gallery!.galleryUrl);
    } on DioError catch (e) {
      Get.snackbar('error', '获取画廊详情错误', snackPosition: SnackPosition.BOTTOM);
      state.loadingDetailsState = LoadingState.error;
      update();
      return;
    }
    state.galleryDetails = galleryDetailsAndApikey['galleryDetails'];
    state.apikey = galleryDetailsAndApikey['apikey'];
    state.loadingDetailsState = LoadingState.success;
    update();
  }

  Future<void> handleRefresh() async {
    Log.info('refresh gallery details', false);

    Map<String, dynamic> galleryDetailsAndApikey;
    try {
      galleryDetailsAndApikey = await EHRequest.getGalleryDetailsAndApikey(
        galleryUrl: state.gallery!.galleryUrl,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      Get.snackbar('get gallery details failed', e.message, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    state.refresh();
    state.galleryDetails = galleryDetailsAndApikey['galleryDetails'];
    state.apikey = galleryDetailsAndApikey['apikey'];
    update();
  }

  void loadMoreThumbnails() async {
    if (state.loadingThumbnailsState == LoadingState.loading) {
      return;
    }
    update();

    /// no more page
    if (state.nextPageNoToLoadThumbnails > state.thumbnailsPageCount!) {
      state.loadingThumbnailsState = LoadingState.noMore;

      update();
      return;
    }

    LoadingState prevState = state.loadingThumbnailsState;
    state.loadingThumbnailsState = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update();
    }

    List<GalleryThumbnail> newThumbNails;
    try {
      newThumbNails = await EHRequest.getGalleryDetailsThumbnailByPageNo(
        galleryUrl: state.gallery!.galleryUrl,
        thumbnailsPageNo: state.nextPageNoToLoadThumbnails,
      );
    } on DioError catch (e) {
      Get.snackbar('failToGetThumbnails'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.loadingThumbnailsState = LoadingState.error;
      update();
      return;
    }
    state.galleryDetails!.thumbnails.addAll(newThumbNails);

    /// a full page contains 40 thumbnails, if not, means there's no more data.
    if (newThumbNails.length % 40 != 0) {
      state.loadingThumbnailsState = LoadingState.noMore;
    }
    state.nextPageNoToLoadThumbnails++;
    state.loadingThumbnailsState = LoadingState.idle;
    update();
  }

  void handleTapFavorite() async {
    if (state.addFavoriteState == LoadingState.loading) {
      return;
    }
    if (!FavoriteSetting.inited) {
      await FavoriteSetting.init();
    }

    int? favIndex = await Get.dialog(FavoriteDialog());

    /// not selected
    if (favIndex == null) {
      return;
    }

    state.addFavoriteState = LoadingState.loading;
    update();
    try {
      if (favIndex == state.gallery?.favoriteTagIndex) {
        await EHRequest.removeFavorite(state.gallery!.gid, state.gallery!.token);
        state.gallery!.removeFavorite();
      } else {
        await EHRequest.addFavorite(state.gallery!.gid, state.gallery!.token, favIndex);
        state.gallery!.addFavorite(favIndex, FavoriteSetting.favoriteTagNames![favIndex]);
      }
    } on DioError catch (e) {
      Get.snackbar('收藏画廊错误', e.message, snackPosition: SnackPosition.BOTTOM);
      state.addFavoriteState = LoadingState.error;
      update();
      return;
    }
    state.addFavoriteState = LoadingState.idle;
    update();

    /// update homePage status
    Get.find<GallerysViewLogic>().update();
  }

  void handleTapRating() async {
    Get.dialog(
      const RatingDialog(),
      barrierColor: Colors.black38,
    );
  }

  void handleTapDownload() {
    DownloadService downloadService = Get.find<DownloadService>();
    Gallery gallery = state.gallery!;

    if (downloadService.gid2downloadProgress[gallery.gid] == null) {
      downloadService.downloadGallery(gallery.toGalleryDownloadedData());
      return;
    }

    if (downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
      downloadService.downloadGallery(gallery.toGalleryDownloadedData(), isFirstDownload: false);
      return;
    } else if (downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.downloading) {
      downloadService.pauseDownloadGallery(gallery.toGalleryDownloadedData());
    }
  }

  void goToReadPage(int index) {
    if (downloadService.gid2downloadProgress[state.gallery!.gid] != null) {
      Get.toNamed(
        Routes.read,
        arguments: state.gallery!.toGalleryDownloadedData(),
        parameters: {
          'type': 'local',
          'gid': state.gallery!.gid.toString(),
          'initialIndex': (storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0).toString(),
          'pageCount': state.gallery!.pageCount.toString(),
          'galleryUrl': state.gallery!.galleryUrl,
        },
      );
    } else {
      Get.toNamed(
        Routes.read,

        /// parsed thumbnails, don't need to parse again
        arguments: state.galleryDetails?.thumbnails,
        parameters: {
          'type': 'online',
          'gid': state.gallery!.gid.toString(),
          'initialIndex': (storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0).toString(),
          'pageCount': state.gallery!.pageCount.toString(),
          'galleryUrl': state.gallery!.galleryUrl,
        },
      );
    }
  }
}
