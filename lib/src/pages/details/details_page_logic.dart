import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/widget/favorite_dialog.dart';
import 'package:jhentai/src/pages/details/widget/torrent_dialog.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:jhentai/src/pages/details/widget/rating_dialog.dart';

import '../../consts/eh_consts.dart';
import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../service/download_service.dart';
import '../../service/storage_service.dart';
import '../../utils/cookie_util.dart';
import '../home/tab_view/gallerys/gallerys_view_logic.dart';
import 'details_page_state.dart';

class DetailsPageLogic extends GetxController {
  final DetailsPageState state = DetailsPageState();
  final DownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  DetailsPageLogic() {
    currentStackDepth++;
  }

  /// there may be more than one DetailsPages in route stack at same time, eg: tag a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  /// when a DetailsPageLogic is created, currentStackDepth++, when a DetailsPageLogic is disposed, currentStackDepth--.
  static int currentStackDepth = 0;

  static DetailsPageLogic get currentDetailsPageLogic =>
      Get.find<DetailsPageLogic>(tag: DetailsPageLogic.currentStackDepth.toString());

  @override
  void onInit() async {
    super.onInit();

    dynamic arg = Get.arguments;

    /// enter from galleryPage
    if (arg is Gallery) {
      state.gallery = arg;
      state.thumbnailsPageCount = arg.pageCount ~/ 40;
      getDetails();
      return;
    }

    /// enter from downloadPage or url
    if (arg is String) {
      Map<String, dynamic> galleryAndDetailsAndApikey = await EHRequest.getGalleryAndDetailsByUrl(arg);
      state.gallery = galleryAndDetailsAndApikey['gallery']!;
      state.galleryDetails = galleryAndDetailsAndApikey['galleryDetails']!;
      state.apikey = galleryAndDetailsAndApikey['apikey']!;
      state.thumbnailsPageCount = state.gallery!.pageCount ~/ 40;
      state.loadingDetailsState = LoadingState.success;
      state.loadingThumbnailsState = LoadingState.success;

      await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
      update();
      return;
    }

    /// enter from ranklist view
    if (arg is List) {
      state.gallery = arg[0];
      state.galleryDetails = arg[1];
      state.apikey = arg[2];
      state.thumbnailsPageCount = state.gallery!.pageCount ~/ 40;
      state.loadingDetailsState = LoadingState.success;
      state.loadingThumbnailsState = LoadingState.idle;
      update();
      return;
    }
  }

  @override
  void onReady() {
    /// record history
    List<String> historyUrls = storageService.read<List>('history')?.map((e) => e as String).toList() ?? <String>[];
    String curUrl;

    if (Get.arguments is Gallery) {
      curUrl = (Get.arguments as Gallery).galleryUrl;
    } else if (Get.arguments is String) {
      curUrl = Get.arguments;
    } else {
      curUrl = (Get.arguments[0] as Gallery).galleryUrl;
    }

    historyUrls.removeWhere((historyUrl) => historyUrl == curUrl);
    historyUrls.insert(0, curUrl);
    storageService.write('history', historyUrls);
    super.onReady();
  }

  @override
  void onClose() {
    currentStackDepth--;
    super.onClose();
  }

  void showLoginSnack() {
    Get.snackbar('operationFailed'.tr, 'needLoginToOperate'.tr);
  }

  Future<void> getDetails() async {
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
      Log.error('Get Gallery Detail Failed', e.message);
      Get.snackbar('getGalleryDetailFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.loadingDetailsState = LoadingState.error;
      update();
      return;
    }
    state.galleryDetails = galleryDetailsAndApikey['galleryDetails'];
    state.apikey = galleryDetailsAndApikey['apikey'];
    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
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
    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    update();
  }

  Future<void> loadMoreThumbnails() async {
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

  Future<void> handleTapFavorite() async {
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

  Future<void> handleTapRating() async {
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

  Future<void> handleTapTorrent() async {
    if (state.galleryDetails!.torrentCount == '0') {
      return;
    }
    Get.dialog(TorrentDialog());
  }

  Future<bool?> handleVotingComment(int commentId, bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      Get.snackbar('operationFailed'.tr, 'needLoginToOperate'.tr);
      return null;
    }

    EHRequest.voteComment(
      state.gallery!.gid,
      state.gallery!.token,
      UserSetting.ipbMemberId.value!,
      state.apikey,
      commentId,
      isVotingUp,
    ).then((result) {
      int score = jsonDecode(result)['comment_score'];
      state.galleryDetails!.comments.firstWhere((comment) => comment.id == commentId).score =
          score >= 0 ? '+' + score.toString() : score.toString();
      update();
    }).catchError((error) {
      Log.error('vote comment failed', (error as DioError).message);
      Get.snackbar('vote comment failed', error.message);
    });

    return true;
  }

  Future<void> handleTapArchive() async {
    List<Cookie> cookies = await EHRequest.getCookie(Uri.parse(EHConsts.EIndex));
    Get.toNamed(
      Routes.webview,
      arguments: state.galleryDetails!.archivePageUrl,
      parameters: {'cookies': CookieUtil.parse2String(cookies)},
    );
  }

  void goToReadPage([int? index]) {
    if (downloadService.gid2downloadProgress[state.gallery!.gid] != null) {
      Get.toNamed(
        Routes.read,
        arguments: state.gallery!.toGalleryDownloadedData(),
        parameters: {
          'type': 'local',
          'gid': state.gallery!.gid.toString(),
          'initialIndex': (index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0).toString(),
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
          'initialIndex': (index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0).toString(),
          'pageCount': state.gallery!.pageCount.toString(),
          'galleryUrl': state.gallery!.galleryUrl,
        },
      );
    }
  }
}
