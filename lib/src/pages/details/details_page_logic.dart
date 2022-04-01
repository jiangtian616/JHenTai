import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/widget/favorite_dialog.dart';
import 'package:jhentai/src/pages/details/widget/torrent_dialog.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:jhentai/src/pages/details/widget/rating_dialog.dart';

import '../../consts/eh_consts.dart';
import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../service/download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/site_setting.dart';
import '../../utils/cookie_util.dart';
import '../../utils/route_util.dart';
import '../home/tab_view/gallerys/gallerys_view_logic.dart';
import 'details_page_state.dart';

String bodyId = 'bodyId';
String loadingStateId = 'loadingStateId';
String addFavoriteStateId = 'addFavoriteStateId';
String thumbnailsId = 'thumbnailsId';

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
      state.thumbnailsPageCount = (state.gallery!.pageCount / SiteSetting.thumbnailsCountPerPage.value).ceil();
      getDetails();
      return;
    }

    /// enter from downloadPage or url
    if (arg is String) {
      Map<String, dynamic> galleryAndDetailsAndApikey = await EHRequest.requestDetailPage(
        galleryUrl: arg,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
      );
      state.gallery = galleryAndDetailsAndApikey['gallery']!;
      state.galleryDetails = galleryAndDetailsAndApikey['galleryDetails']!;
      state.apikey = galleryAndDetailsAndApikey['apikey']!;
      state.thumbnailsPageCount = (state.gallery!.pageCount / SiteSetting.thumbnailsCountPerPage.value).ceil();
      state.loadingDetailsState = LoadingState.success;

      await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
      update([bodyId]);
      return;
    }

    /// enter from ranklist view
    if (arg is List) {
      state.gallery = arg[0];
      state.galleryDetails = arg[1];
      state.apikey = arg[2];
      state.thumbnailsPageCount = (state.gallery!.pageCount / SiteSetting.thumbnailsCountPerPage.value).ceil();
      state.loadingDetailsState = LoadingState.success;
      update([bodyId]);
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
    snack('operationFailed'.tr, 'needLoginToOperate'.tr);
  }

  Future<void> getDetails() async {
    if (state.loadingDetailsState == LoadingState.loading || state.loadingDetailsState == LoadingState.success) {
      return;
    }

    LoadingState prevState = state.loadingDetailsState;
    state.loadingDetailsState = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    Log.info('get gallery details', false);
    Map<String, dynamic> galleryDetailsAndApikey;
    try {
      galleryDetailsAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
        galleryUrl: state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2DetailAndApikey,
      );
    } on DioError catch (e) {
      Log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingDetailsState = LoadingState.error;
      update([loadingStateId]);
      return;
    }
    state.galleryDetails = galleryDetailsAndApikey['galleryDetails'];
    state.apikey = galleryDetailsAndApikey['apikey'];
    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    state.loadingDetailsState = LoadingState.success;
    update([bodyId]);
  }

  Future<void> handleRefresh() async {
    Log.info('refresh gallery details', false);

    Map<String, dynamic> detailAndApikey;
    try {
      detailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
        galleryUrl: state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2DetailAndApikey,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      snack('refreshGalleryDetailsFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      Log.error('refreshGalleryDetailsFailed'.tr, e.message);
      return;
    }

    state.refresh();
    state.galleryDetails = detailAndApikey['galleryDetails'];
    state.apikey = detailAndApikey['apikey'];
    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    update([bodyId]);
  }

  Future<void> loadMoreThumbnails() async {
    if (state.loadingThumbnailsState == LoadingState.loading) {
      return;
    }
    update([loadingStateId]);

    /// no more page
    if (state.nextPageIndexToLoadThumbnails >= state.thumbnailsPageCount) {
      state.loadingThumbnailsState = LoadingState.noMore;

      update([loadingStateId]);
      return;
    }

    LoadingState prevState = state.loadingThumbnailsState;
    state.loadingThumbnailsState = LoadingState.loading;
    if (prevState == LoadingState.error) {
      update([loadingStateId]);
    }

    List<GalleryThumbnail> newThumbNails;
    try {
      newThumbNails = await EHRequest.requestDetailPage(
        galleryUrl: state.gallery!.galleryUrl,
        thumbnailsPageNo: state.nextPageIndexToLoadThumbnails,
        parser: EHSpiderParser.detailPage2Thumbnails,
      );
    } on DioError catch (e) {
      Log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingThumbnailsState = LoadingState.error;
      update([loadingStateId]);
      return;
    }
    state.galleryDetails!.thumbnails.addAll(newThumbNails);

    /// a full page contains x thumbnails, if not, means there's no more data.
    if (newThumbNails.length % SiteSetting.thumbnailsCountPerPage.value != 0) {
      state.loadingThumbnailsState = LoadingState.noMore;
    }
    state.nextPageIndexToLoadThumbnails++;
    state.loadingThumbnailsState = LoadingState.idle;
    update([bodyId]);
  }

  Future<void> handleTapFavorite() async {
    if (state.addFavoriteState == LoadingState.loading) {
      return;
    }
    if (!FavoriteSetting.inited) {
      await FavoriteSetting.refresh();
    }

    int? favIndex = await Get.dialog(FavoriteDialog());

    /// not selected
    if (favIndex == null) {
      return;
    }

    state.addFavoriteState = LoadingState.loading;
    update([addFavoriteStateId]);
    try {
      if (favIndex == state.gallery?.favoriteTagIndex) {
        await EHRequest.requestRemoveFavorite(state.gallery!.gid, state.gallery!.token);
        state.gallery!.removeFavorite();
      } else {
        await EHRequest.requestAddFavorite(state.gallery!.gid, state.gallery!.token, favIndex);
        state.gallery!.addFavorite(favIndex, FavoriteSetting.favoriteTagNames[favIndex]);
      }
    } on DioError catch (e) {
      Log.error('favoriteGalleryFailed'.tr, e.message);
      snack('favoriteGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.addFavoriteState = LoadingState.error;
      update([addFavoriteStateId]);
      return;
    }
    state.addFavoriteState = LoadingState.idle;
    update([addFavoriteStateId]);

    /// update homePage status
    Get.find<GallerysViewLogic>().update([bodyId]);
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
      snack('beginToDownload'.tr, gallery.title);
      return;
    }

    if (downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.paused) {
      downloadService.downloadGallery(gallery.toGalleryDownloadedData(), isFirstDownload: false);
      snack('resume'.tr, gallery.title);
      return;
    } else if (downloadService.gid2downloadProgress[gallery.gid]!.value.downloadStatus == DownloadStatus.downloading) {
      downloadService.pauseDownloadGallery(gallery.toGalleryDownloadedData());
      snack('pause'.tr, gallery.title);
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
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
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
      update([bodyId]);
    }).catchError((error) {
      Log.error('voteCommentFailed'.tr, (error as DioError).message);
      snack('voteCommentFailed'.tr, error.message);
    });

    return true;
  }

  Future<void> handleTapArchive() async {
    List<Cookie> cookies = await EHRequest.getCookie(Uri.parse(EHConsts.EIndex));
    toNamed(
      Routes.webview,
      arguments: state.galleryDetails!.archivePageUrl,
      parameters: {'cookies': CookieUtil.parse2String(cookies)},
    );
  }

  Future<void> handleTapStatistic() async {
    List<Cookie> cookies = await EHRequest.getCookie(Uri.parse(EHConsts.EIndex));
    toNamed(
      Routes.webview,
      arguments: state.galleryDetails!.statisticPageUrl,
      parameters: {'cookies': CookieUtil.parse2String(cookies)},
    );
  }

  void goToReadPage([int? index]) {
    if (downloadService.gid2downloadProgress[state.gallery!.gid] != null) {
      toNamed(
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
      toNamed(
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
