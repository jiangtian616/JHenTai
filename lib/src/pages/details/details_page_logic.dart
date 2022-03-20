import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/widget/favorite_dialog.dart';
import 'package:jhentai/src/pages/home/navigation_view/gallerys/gallerys_view_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:jhentai/src/pages/details/widget/rating_dialog.dart';

import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../service/download_service.dart';
import 'details_page_state.dart';

class DetailsPageLogic extends GetxController {
  final DetailsPageState state = DetailsPageState();

  @override
  void onInit() {
    Gallery gallery = (Get.arguments as Gallery);
    state.gallery = gallery;
    state.thumbnailsPageCount = gallery.pageCount ~/ 40;
    getDetails();
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
      galleryDetailsAndApikey = await EHRequest.getGalleryDetailsAndApikey(galleryUrl: state.gallery!.galleryUrl);
    } on DioError catch (e) {
      Get.snackbar('error', '获取画廊详情错误', snackPosition: SnackPosition.BOTTOM);
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
    }
    downloadService.pauseDownloadGallery(gallery.toGalleryDownloadedData());
  }

  void goToReadPage(int index) {
    Get.toNamed(
      Routes.read,

      /// parsed thumbnails, don't need to parse again
      arguments: state.galleryDetails?.thumbnails,
      parameters: {
        'initialIndex': index.toString(),
        'pageCount': state.gallery!.pageCount.toString(),
        'galleryUrl': state.gallery!.galleryUrl,
      },
    );
  }
}
