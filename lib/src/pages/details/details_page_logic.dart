import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_cache_interceptor.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/widget/archive_dialog.dart';
import 'package:jhentai/src/pages/details/widget/favorite_dialog.dart';
import 'package:jhentai/src/pages/details/widget/rating_dialog.dart';
import 'package:jhentai/src/pages/details/widget/stat_dialog.dart';
import 'package:jhentai/src/pages/details/widget/torrent_dialog.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/search/desktop/desktop_search_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/download_original_image_dialog.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:share_plus/share_plus.dart';

import '../../model/gallery.dart';
import '../../service/history_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/site_setting.dart';
import '../../utils/route_util.dart';
import '../../utils/search_util.dart';
import '../../utils/toast_util.dart';
import '../gallerys/nested/nested_gallerys_page_logic.dart' as g;
import '../layout/desktop/desktop_layout_page_logic.dart';
import '../search/mobile/search_page_logic.dart';
import 'details_page_state.dart';

String bodyId = 'bodyId';
String loadingStateId = 'loadingStateId';
String addFavoriteStateId = 'addFavoriteStateId';
String ratingStateId = 'ratingStateId';
String thumbnailsId = 'thumbnailsId';

class DetailsPageLogic extends GetxController {
  /// there may be more than one DetailsPages in route stack at same time, eg: tag a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  String tag;

  final DetailsPageState state = DetailsPageState();
  final GalleryDownloadService downloadService = Get.find();
  final StorageService storageService = Get.find();
  final HistoryService historyService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  static final List<DetailsPageLogic> _stack = <DetailsPageLogic>[];

  static DetailsPageLogic? get current => _stack.isEmpty ? null : _stack.last;

  DetailsPageLogic(this.tag) {
    _stack.add(this);
  }

  @override
  void onInit() async {
    super.onInit();

    dynamic arg = Get.arguments;

    /// enter from galleryPage
    if (arg is Gallery) {
      state.gallery = arg;
      getDetails().then((_) => historyService.record(state.gallery));
      return;
    }

    /// enter from downloadPage or url or clipboard
    if (arg is String) {
      getFullPage().then((_) => historyService.record(state.gallery));
    }
  }

  @override
  void onClose() {
    _stack.remove(this);
    state.scrollController.dispose();
    super.onClose();
  }

  void showLoginSnack() {
    snack('operationFailed'.tr, 'needLoginToOperate'.tr);
  }

  Future<void> getFullPage() async {
    state.loadingPageState = LoadingState.loading;
    update([loadingStateId]);

    Map<String, dynamic> galleryAndDetailAndApikey;
    try {
      galleryAndDetailAndApikey = await EHRequest.requestDetailPage(
        galleryUrl: Get.arguments,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        Log.error('404', e.message);
        snack('invisible2User'.tr, 'invisibleHints'.tr, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      } else {
        Log.error('getGalleryDetailFailed'.tr, e.message);
        snack('getGalleryDetailFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      }
      state.loadingPageState = LoadingState.error;
      update([bodyId]);
      return;
    }
    state.gallery = galleryAndDetailAndApikey['gallery']!;
    state.galleryDetails = galleryAndDetailAndApikey['galleryDetails']!;
    state.apikey = galleryAndDetailAndApikey['apikey']!;
    state.gallery!.pageCount = (galleryAndDetailAndApikey['gallery'] as Gallery).pageCount;
    state.thumbnailsPageCount = ((galleryAndDetailAndApikey['gallery'] as Gallery).pageCount! / SiteSetting.thumbnailsCountPerPage.value).ceil();

    state.loadingPageState = LoadingState.success;
    state.loadingDetailsState = LoadingState.success;

    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    update([bodyId]);
    return;
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
    Map<String, dynamic> galleryAndDetailAndApikey;
    try {
      galleryAndDetailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
        galleryUrl: state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
      );
    } on DioError catch (e) {
      Log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingDetailsState = LoadingState.error;
      update([loadingStateId]);
      return;
    }
    state.galleryDetails = galleryAndDetailAndApikey['galleryDetails'];
    state.apikey = galleryAndDetailAndApikey['apikey'];
    state.gallery!.pageCount = (galleryAndDetailAndApikey['gallery'] as Gallery).pageCount;
    state.gallery!.uploader = (galleryAndDetailAndApikey['gallery'] as Gallery).uploader;
    state.gallery!.isFavorite = (galleryAndDetailAndApikey['gallery'] as Gallery).isFavorite;
    state.gallery!.favoriteTagIndex = (galleryAndDetailAndApikey['gallery'] as Gallery).favoriteTagIndex;
    state.gallery!.favoriteTagName = (galleryAndDetailAndApikey['gallery'] as Gallery).favoriteTagName;
    state.gallery!.hasRated = (galleryAndDetailAndApikey['gallery'] as Gallery).hasRated;
    state.gallery!.rating = (galleryAndDetailAndApikey['gallery'] as Gallery).rating;
    state.thumbnailsPageCount = ((galleryAndDetailAndApikey['gallery'] as Gallery).pageCount! / SiteSetting.thumbnailsCountPerPage.value).ceil();

    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    state.loadingDetailsState = LoadingState.success;

    /// Attention! If enter into detail page and exit very quickly, [update] will cause
    /// an fatal exception because this [logic] has been destroyed, in order to avoid it,
    /// I check if this [logic] has called [disposed]
    if (_stack.contains(this)) {
      update([bodyId]);
    }
  }

  Future<void> handleRefresh() async {
    Log.info('refresh gallery details', false);

    Map<String, dynamic> galleryAndDetailAndApikey;
    try {
      galleryAndDetailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
        galleryUrl: state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      snack('refreshGalleryDetailsFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      Log.error('refreshGalleryDetailsFailed'.tr, e.message);
      return;
    }

    state.refresh();
    state.galleryDetails = galleryAndDetailAndApikey['galleryDetails'];
    state.apikey = galleryAndDetailAndApikey['apikey'];
    state.gallery!.pageCount = (galleryAndDetailAndApikey['gallery'] as Gallery).pageCount;
    state.gallery!.uploader = (galleryAndDetailAndApikey['gallery'] as Gallery).uploader;
    state.gallery!.isFavorite = (galleryAndDetailAndApikey['gallery'] as Gallery).isFavorite;
    state.gallery!.favoriteTagIndex = (galleryAndDetailAndApikey['gallery'] as Gallery).favoriteTagIndex;
    state.gallery!.favoriteTagName = (galleryAndDetailAndApikey['gallery'] as Gallery).favoriteTagName;
    state.gallery!.hasRated = (galleryAndDetailAndApikey['gallery'] as Gallery).hasRated;
    state.gallery!.rating = (galleryAndDetailAndApikey['gallery'] as Gallery).rating;
    state.thumbnailsPageCount = ((galleryAndDetailAndApikey['gallery'] as Gallery).pageCount! / SiteSetting.thumbnailsCountPerPage.value).ceil();

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
        thumbnailsPageIndex: state.nextPageIndexToLoadThumbnails,
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

  Future<void> shareGallery() async {
    Log.verbose('Share gallery:${state.gallery!.galleryUrl}');

    if (GetPlatform.isDesktop) {
      await FlutterClipboard.copy(state.gallery!.galleryUrl);
      toast('hasCopiedToClipboard'.tr);
      return;
    }

    Share.share(
      state.gallery!.galleryUrl,
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
    );
  }

  Future<void> handleTapFavorite() async {
    if (state.favoriteState == LoadingState.loading) {
      return;
    }
    if (!FavoriteSetting.inited) {
      FavoriteSetting.refresh();
    }

    int? favIndex = await Get.dialog(FavoriteDialog());

    /// not selected
    if (favIndex == null) {
      return;
    }

    Log.verbose('Favorite gallery:${state.gallery!.gid}');

    state.favoriteState = LoadingState.loading;
    update([addFavoriteStateId]);
    try {
      if (favIndex == state.gallery?.favoriteTagIndex) {
        await EHRequest.requestRemoveFavorite(state.gallery!.gid, state.gallery!.token);
        FavoriteSetting.decrementFavByIndex(favIndex);
        state.gallery!.removeFavorite();
      } else {
        await EHRequest.requestAddFavorite(state.gallery!.gid, state.gallery!.token, favIndex);
        FavoriteSetting.incrementFavByIndex(favIndex);
        FavoriteSetting.decrementFavByIndex(state.gallery?.favoriteTagIndex);
        state.gallery!.addFavorite(favIndex, FavoriteSetting.favoriteTagNames[favIndex]);
      }
      FavoriteSetting.save();
    } on DioError catch (e) {
      Log.error('favoriteGalleryFailed'.tr, e.message);
      snack('favoriteGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.favoriteState = LoadingState.error;
      update([addFavoriteStateId]);
      return;
    }

    _removeCache();

    state.favoriteState = LoadingState.idle;
    update([addFavoriteStateId]);

    /// update homePage and searchPage status
    if (Get.isRegistered<g.NestedGallerysPageLogic>()) {
      Get.find<g.NestedGallerysPageLogic>().update([g.bodyId]);
    }
    if (Get.isRegistered<GallerysPageLogic>()) {
      Get.find<GallerysPageLogic>().updateBody();
    }
    SearchPageLogic.current?.update([bodyId]);
    if (Get.isRegistered<DesktopSearchPageLogic>()) {
      Get.find<DesktopSearchPageLogic>().updateBody();
    }
  }

  Future<void> searchUploader(String author) async {
    String keyword = 'uploader:"$author"';
    newSearch(keyword);
  }

  Future<void> searchSimilar() async {
    /// r'\[[^\]]*\]|\([[^\)]*\)|{[^\}]*}'
    String title = '"${state.galleryDetails!.rawTitle.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|{.*?}'), '').trim()}"';
    newSearch(title);
  }

  Future<void> handleTapRating() async {
    double? rating = await Get.dialog(
      const RatingDialog(),
      barrierColor: Colors.black38,
    );

    /// not selected
    if (rating == null) {
      return;
    }

    Log.verbose('Rate gallery:${state.gallery!.gid}');

    state.ratingState = LoadingState.loading;
    update([ratingStateId]);

    Map<String, dynamic> ratingInfo;
    try {
      ratingInfo = await EHRequest.requestSubmitRating(
        state.gallery!.gid,
        state.gallery!.token,
        UserSetting.ipbMemberId.value!,
        state.apikey,
        (rating * 2).toInt(),
        parser: EHSpiderParser.galleryRatingResponse2RatingInfo,
      );
    } on DioError catch (e) {
      Log.error('ratingFailed'.tr, e.message);
      snack('ratingFailed'.tr, e.message, snackPosition: SnackPosition.BOTTOM);
      state.ratingState = LoadingState.error;
      update([ratingStateId]);
      return;
    }

    /// eg: {"rating_avg":0.93000000000000005,"rating_usr":0.5,"rating_cnt":21,"rating_cls":"ir irr"}
    state.gallery!.hasRated = true;
    state.gallery!.rating = ratingInfo['rating_usr'];
    state.galleryDetails!.ratingCount = ratingInfo['rating_cnt'];
    state.galleryDetails!.realRating = ratingInfo['rating_avg'];

    state.ratingState = LoadingState.idle;

    _removeCache();

    update([bodyId]);
    if (Get.isRegistered<g.NestedGallerysPageLogic>()) {
      Get.find<g.NestedGallerysPageLogic>().update([g.bodyId]);
    }
    if (Get.isRegistered<GallerysPageLogic>()) {
      Get.find<GallerysPageLogic>().updateBody();
    }
  }

  Future<void> handleTapDownload() async {
    GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
    Gallery gallery = state.gallery!;
    GalleryDownloadProgress? downloadProgress = downloadService.galleryDownloadInfos[gallery.gid]?.downloadProgress;

    if (downloadProgress == null) {
      if (DownloadSetting.downloadOriginalImage.value == DownloadOriginalImageMode.always) {
        downloadService.downloadGallery(gallery.toGalleryDownloadedData(downloadOriginalImage: true));
        toast('${'beginToDownload'.tr}： ${gallery.gid}', isCenter: false);
        return;
      }
      if (DownloadSetting.downloadOriginalImage.value == DownloadOriginalImageMode.never) {
        downloadService.downloadGallery(gallery.toGalleryDownloadedData(downloadOriginalImage: false));
        toast('${'beginToDownload'.tr}： ${gallery.gid}', isCenter: false);
        return;
      }
      if (DownloadSetting.downloadOriginalImage.value == DownloadOriginalImageMode.manual) {
        bool? downloadOriginalImage = await Get.dialog(const DownloadOriginalImageDialog());
        if (downloadOriginalImage == null) {
          return;
        }
        downloadService.downloadGallery(gallery.toGalleryDownloadedData(downloadOriginalImage: downloadOriginalImage));
        toast('${'beginToDownload'.tr}： ${gallery.gid}', isCenter: false);
      }
      return;
    }

    if (downloadProgress.downloadStatus == DownloadStatus.paused) {
      downloadService.resumeDownloadGallery(gallery.toGalleryDownloadedData());
      toast('${'resume'.tr}： ${gallery.gid}', isCenter: false);
      return;
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloading) {
      downloadService.pauseDownloadGallery(gallery.toGalleryDownloadedData());
      toast('${'pause'.tr}： ${gallery.gid}', isCenter: false);
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloaded && state.galleryDetails?.newVersionGalleryUrl != null) {
      downloadService.updateGallery(gallery.toGalleryDownloadedData(), state.galleryDetails!.newVersionGalleryUrl!);
      toast('${'update'.tr}： ${gallery.gid}', isCenter: false);
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

    Log.verbose('Vote for comment:${state.gallery!.gid}-$commentId}');

    EHRequest.voteComment(
      state.gallery!.gid,
      state.gallery!.token,
      UserSetting.ipbMemberId.value!,
      state.apikey,
      commentId,
      isVotingUp,
    ).then((result) {
      int score = jsonDecode(result)['comment_score'];
      state.galleryDetails!.comments.firstWhere((comment) => comment.id == commentId).score = score >= 0 ? '+' + score.toString() : score.toString();
      update([bodyId]);
    }).catchError((error) {
      Log.error('voteCommentFailed'.tr, (error as DioError).message);
      snack('voteCommentFailed'.tr, error.message);
    });

    return true;
  }

  Future<void> handleTapArchive() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginSnack();
      return;
    }
    Get.dialog(const ArchiveDialog());
  }

  Future<void> handleTapStatistic() async {
    Get.dialog(const StatDialog());
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (!Get.isRegistered<DesktopLayoutPageLogic>()) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      Get.find<DesktopLayoutPageLogic>().state.leftColumnFocusScopeNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp && state.scrollController.hasClients) {
      state.scrollController.animateTo(
        state.scrollController.offset - 300,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && state.scrollController.hasClients) {
      state.scrollController.animateTo(
        state.scrollController.offset + 300,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      );
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      goToReadPage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void goToReadPage([int? index]) {
    /// downloading
    if (downloadService.galleryDownloadInfos[state.gallery!.gid]?.downloadProgress != null) {
      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.local,
          gid: state.gallery!.gid,
          galleryUrl: state.gallery!.galleryUrl,
          initialIndex: index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0,
          currentIndex: index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0,
          pageCount: state.gallery!.pageCount!,
        ),
      );
    }

    /// online
    else {
      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.online,
          gid: state.gallery!.gid,
          galleryUrl: state.gallery!.galleryUrl,
          initialIndex: index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0,
          currentIndex: index ?? storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0,
          pageCount: state.gallery!.pageCount!,
        ),
      );
    }
  }

  void scroll2Top() {
    if (state.scrollController.hasClients) {
      state.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.ease,
      );
    }
  }

  void _removeCache() {
    Get.find<EHCacheInterceptor>().removeCacheByUrl('${state.gallery!.galleryUrl}?p=0');
  }
}
