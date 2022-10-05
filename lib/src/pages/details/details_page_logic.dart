import 'dart:convert';

import 'package:clipboard/clipboard.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_cache_interceptor.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/widget/eh_gallery_torrents_dialog.dart';
import 'package:jhentai/src/widget/eh_archive_dialog.dart';
import 'package:jhentai/src/widget/eh_favorite_dialog.dart';
import 'package:jhentai/src/widget/eh_rating_dialog.dart';
import 'package:jhentai/src/widget/eh_gallery_stat_dialog.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:share_plus/share_plus.dart';

import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/update_global_gallery_status_logic_mixin.dart';
import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../service/history_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/process_util.dart';
import '../../utils/route_util.dart';
import '../../utils/search_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/eh_download_dialog.dart';
import '../layout/desktop/desktop_layout_page_logic.dart';
import 'details_page_state.dart';

class DetailsPageLogic extends GetxController with LoginRequiredMixin, Scroll2TopLogicMixin, UpdateGlobalGalleryStatusLogicMixin {
  static const String thumbnailsId = 'thumbnailsId';
  static const String thumbnailId = 'thumbnailId';
  static const String loadingStateId = 'loadingStateId';
  static const String loadingThumbnailsStateId = 'loadingThumbnailsStateId';
  static const String addFavoriteStateId = 'addFavoriteStateId';
  static const String ratingStateId = 'ratingStateId';

  /// there may be more than one DetailsPages in route stack at same time, eg: tag a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  String tag;
  static final List<DetailsPageLogic> _stack = <DetailsPageLogic>[];

  static DetailsPageLogic? get current => _stack.isEmpty ? null : _stack.last;

  @override
  final DetailsPageState state = DetailsPageState();

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();
  final StorageService storageService = Get.find();
  final HistoryService historyService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  DetailsPageLogic(this.tag) {
    _stack.add(this);
  }

  @override
  void onInit() {
    if (Get.arguments is! Map) {
      return;
    }

    state.galleryUrl = Get.arguments['galleryUrl'];
    state.gallery = Get.arguments['gallery'];

    super.onInit();
  }

  @override
  void onReady() async {
    super.onReady();
    getDetails();
  }

  @override
  void onClose() {
    super.onClose();
    _stack.remove(this);
  }

  Future<void> getDetails({bool refresh = false}) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    if (!refresh) {
      updateSafely([loadingStateId]);
    }

    Log.info('Get gallery details:${state.galleryUrl}');

    Map<String, dynamic>? galleryAndDetailAndApikey;
    try {
      galleryAndDetailAndApikey = await _getDetailsWithRedirect(useCache: !refresh);
    } on DioError catch (e) {
      Log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      if (!refresh) {
        updateSafely([loadingStateId]);
      }
      return;
    }

    Gallery newGallery = galleryAndDetailAndApikey['gallery']!;

    state.gallery ??= newGallery;
    state.galleryDetails = galleryAndDetailAndApikey['galleryDetails'];
    state.apikey = galleryAndDetailAndApikey['apikey'];
    state.nextPageIndexToLoadThumbnails = 1;

    /// some field in [Gallery] sometimes is null
    state.gallery?.pageCount = newGallery.pageCount;
    state.gallery?.uploader = newGallery.uploader;
    state.gallery?.isFavorite = newGallery.isFavorite;
    state.gallery?.favoriteTagIndex = newGallery.favoriteTagIndex;
    state.gallery?.favoriteTagName = newGallery.favoriteTagName;
    state.gallery?.hasRated = newGallery.hasRated;
    state.gallery?.rating = newGallery.rating;

    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);
    historyService.record(state.gallery);

    state.loadingState = LoadingState.success;

    updateSafely();
  }

  Future<void> loadMoreThumbnails() async {
    if (state.loadingThumbnailsState == LoadingState.loading) {
      return;
    }

    /// no more thumbnails
    if (state.nextPageIndexToLoadThumbnails >= state.galleryDetails!.thumbnailsPageCount) {
      state.loadingThumbnailsState = LoadingState.noMore;
      updateSafely([loadingThumbnailsStateId]);
      return;
    }

    state.loadingThumbnailsState = LoadingState.loading;
    updateSafely([loadingThumbnailsStateId]);

    List<GalleryThumbnail> newThumbNails;
    try {
      newThumbNails = await EHRequest.requestDetailPage(
        galleryUrl: state.galleryUrl,
        thumbnailsPageIndex: state.nextPageIndexToLoadThumbnails,
        parser: EHSpiderParser.detailPage2Thumbnails,
      );
    } on DioError catch (e) {
      Log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingThumbnailsState = LoadingState.error;
      updateSafely([loadingThumbnailsStateId]);
      return;
    }

    state.galleryDetails!.thumbnails.addAll(newThumbNails);
    state.nextPageIndexToLoadThumbnails++;

    state.loadingThumbnailsState = LoadingState.idle;
    updateSafely([thumbnailsId]);
  }

  Future<void> handleRefresh() async {
    return getDetails(refresh: true);
  }

  Future<void> handleTapDownload() async {
    Gallery gallery = state.gallery!;
    GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
    GalleryDownloadedData? galleryDownloadedData = downloadService.gallerys.singleWhereOrNull((g) => g.gid == gallery.gid);
    GalleryDownloadProgress? downloadProgress = downloadService.galleryDownloadInfos[gallery.gid]?.downloadProgress;

    /// new download
    if (galleryDownloadedData == null || downloadProgress == null) {
      Map<String, dynamic>? result = await Get.dialog(
        EHDownloadDialog(
          title: 'chooseGroup'.tr,
          candidates: downloadService.allGroups,
          showDownloadOriginalImageCheckBox: true,
        ),
      );

      if (result == null) {
        return;
      }

      downloadService.downloadGallery(gallery.toGalleryDownloadedData(
        downloadOriginalImage: result['downloadOriginalImage'] ?? false,
        group: result['group'] ?? 'default'.tr,
      ));

      toast('${'beginToDownload'.tr}： ${gallery.gid}', isCenter: false);
      return;
    }

    if (downloadProgress.downloadStatus == DownloadStatus.paused) {
      downloadService.resumeDownloadGallery(galleryDownloadedData);
      toast('${'resume'.tr}： ${gallery.gid}', isCenter: false);
      return;
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloading) {
      downloadService.pauseDownloadGallery(galleryDownloadedData);
      toast('${'pause'.tr}： ${gallery.gid}', isCenter: false);
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloaded && state.galleryDetails?.newVersionGalleryUrl == null) {
      goToReadPage();
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloaded && state.galleryDetails?.newVersionGalleryUrl != null) {
      downloadService.updateGallery(galleryDownloadedData, state.galleryDetails!.newVersionGalleryUrl!);
      toast('${'update'.tr}： ${gallery.gid}', isCenter: false);
    }
  }

  Future<void> handleTapFavorite() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    if (state.favoriteState == LoadingState.loading) {
      return;
    }

    if (!FavoriteSetting.inited) {
      FavoriteSetting.refresh();
    }

    int? favIndex = await Get.dialog(EHFavoriteDialog(selectedIndex: state.gallery?.favoriteTagIndex));

    if (favIndex == null) {
      return;
    }

    Log.info('Favorite gallery: ${state.gallery!.gid}');

    state.favoriteState = LoadingState.loading;
    updateSafely([addFavoriteStateId]);

    try {
      if (favIndex == state.gallery?.favoriteTagIndex) {
        await EHRequest.requestRemoveFavorite(state.gallery!.gid, state.gallery!.token);
        FavoriteSetting.decrementFavByIndex(favIndex);
        state.gallery!
          ..isFavorite = false
          ..favoriteTagIndex = null
          ..favoriteTagName = null;
      } else {
        await EHRequest.requestAddFavorite(state.gallery!.gid, state.gallery!.token, favIndex);
        FavoriteSetting.incrementFavByIndex(favIndex);
        FavoriteSetting.decrementFavByIndex(state.gallery?.favoriteTagIndex);
        state.gallery!
          ..isFavorite = true
          ..favoriteTagIndex = favIndex
          ..favoriteTagName = FavoriteSetting.favoriteTagNames[favIndex];
      }

      FavoriteSetting.save();
    } on DioError catch (e) {
      Log.error('favoriteGalleryFailed'.tr, e.message);
      snack('favoriteGalleryFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.favoriteState = LoadingState.error;
      updateSafely([addFavoriteStateId]);
      return;
    }

    _removeCache();

    state.favoriteState = LoadingState.idle;
    updateSafely([addFavoriteStateId]);

    updateGlobalGalleryStatus();
  }

  Future<void> handleTapRating() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    double? rating = await Get.dialog(EHRatingDialog(
      rating: state.gallery!.rating,
      hasRated: state.gallery!.hasRated,
    ));

    if (rating == null) {
      return;
    }

    Log.info('Rate gallery: ${state.gallery!.gid}, rating: $rating');

    state.ratingState = LoadingState.loading;
    updateSafely([ratingStateId]);

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
      updateSafely([ratingStateId]);
      return;
    }

    /// eg: {"rating_avg":0.93000000000000005,"rating_usr":0.5,"rating_cnt":21,"rating_cls":"ir irr"}
    state.gallery!.hasRated = true;
    state.gallery!.rating = ratingInfo['rating_usr'];
    state.galleryDetails!.ratingCount = ratingInfo['rating_cnt'];
    state.galleryDetails!.realRating = ratingInfo['rating_avg'];

    _removeCache();

    state.ratingState = LoadingState.idle;
    updateSafely();

    updateGlobalGalleryStatus();
  }

  Future<void> handleTapArchive() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    ArchiveStatus? archiveStatus = archiveDownloadService.archiveDownloadInfos[state.gallery?.gid]?.archiveStatus;

    /// new download
    if (archiveStatus == null) {
      Map<String, dynamic>? result = await Get.dialog(EHArchiveDialog(
        archivePageUrl: state.galleryDetails!.archivePageUrl,
        candidates: archiveDownloadService.allGroups,
        currentGroup: 'default'.tr,
      ));
      if (result == null) {
        return;
      }

      ArchiveDownloadedData archive = state.gallery!.toArchiveDownloadedData(
        archivePageUrl: state.galleryDetails!.archivePageUrl,
        isOriginal: result['isOriginal'],
        size: result['size'],
        group: result['group'] ?? 'default'.tr,
      );

      archiveDownloadService.downloadArchive(archive);

      Log.info('${'beginToDownloadArchive'.tr}: ${archive.title}');
      toast('${'beginToDownloadArchive'.tr}:  ${archive.title}', isCenter: false);
      return;
    }

    ArchiveDownloadedData archive = archiveDownloadService.archives.firstWhere((a) => a.gid == state.gallery?.gid);
    if (ArchiveStatus.unlocking.index <= archiveStatus.index && archiveStatus.index < ArchiveStatus.downloaded.index) {
      return archiveDownloadService.pauseDownloadArchive(archive);
    }

    if (archiveStatus == ArchiveStatus.completed) {
      String storageKey = 'readIndexRecord::${archive.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;
      List<GalleryImage> images = archiveDownloadService.getUnpackedImages(archive);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
          currentIndex: readIndexRecord,
          pageCount: images.length,
          isOriginal: archive.isOriginal,
          readProgressRecordStorageKey: storageKey,
          images: images,
        ),
      );
    }
  }

  void searchSimilar() {
    newSearch(state.galleryDetails!.rawTitle.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|{.*?}'), '').trim());
  }

  void searchUploader() {
    newSearch('uploader:"${state.gallery!.uploader!}"');
  }

  Future<void> handleTapTorrent() async {
    Get.dialog(EHGalleryTorrentsDialog(gid: state.gallery!.gid, token: state.gallery!.token));
  }

  Future<bool?> handleVotingComment(int commentId, bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return null;
    }

    Log.info('Vote for comment:${state.gallery!.gid}-$commentId}');

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
      updateSafely();
    }).catchError((error) {
      Log.error('voteCommentFailed'.tr, (error as DioError).message);
      snack('voteCommentFailed'.tr, error.message);
    });

    return true;
  }

  Future<void> handleTapStatistic() async {
    Get.dialog(EHGalleryStatDialog(gid: state.gallery!.gid, token: state.gallery!.token));
  }

  Future<void> shareGallery() async {
    Log.info('Share gallery:${state.galleryUrl}');

    if (GetPlatform.isDesktop) {
      await FlutterClipboard.copy(state.galleryUrl);
      toast('hasCopiedToClipboard'.tr);
      return;
    }

    Share.share(
      state.galleryUrl,
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
    );
  }

  void goToReadPage([int? forceIndex]) {
    String storageKey = 'readIndexRecord::${state.gallery!.gid}';
    int readIndexRecord = storageService.read(storageKey) ?? 0;

    /// online
    if (galleryDownloadService.galleryDownloadInfos[state.gallery!.gid]?.downloadProgress == null) {
      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.online,
          gid: state.gallery!.gid,
          galleryUrl: state.galleryUrl,
          initialIndex: forceIndex ?? readIndexRecord,
          currentIndex: forceIndex ?? readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: state.gallery!.pageCount!,
        ),
      );
      return;
    }

    if (ReadSetting.useThirdPartyViewer.isTrue && ReadSetting.thirdPartyViewerPath.value != null) {
      /// use GalleryDownloadedData's title, because it's more accurate. Title in [state.gallery] may be English title and the one we downloaded may be in Japanese
      GalleryDownloadedData gallery = galleryDownloadService.gallerys.firstWhere((g) => g.gid == state.gallery!.gid);
      openThirdPartyViewer(galleryDownloadService.computeGalleryDownloadPath(gallery.title, gallery.gid));
      return;
    }

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.downloaded,
        gid: state.gallery!.gid,
        galleryUrl: state.galleryUrl,
        initialIndex: forceIndex ?? readIndexRecord,
        currentIndex: forceIndex ?? readIndexRecord,
        readProgressRecordStorageKey: storageKey,
        pageCount: state.gallery!.pageCount!,
      ),
    );
  }

  int getReadIndexRecord() {
    return storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0;
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

  Future<Map<String, dynamic>> _getDetailsWithRedirect({bool useCache = true}) async {
    /// try EH site
    if (state.galleryUrl.contains(EHConsts.EXIndex) && EHSetting.redirect2Eh.isTrue) {
      try {
        Map<String, dynamic> galleryAndDetailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
          galleryUrl: state.galleryUrl.replaceFirst(EHConsts.EXIndex, EHConsts.EHIndex),
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
          useCacheIfAvailable: useCache,
        );
        Log.verbose('Try redirect to EH success, url: ${state.galleryUrl}');
        state.galleryUrl = state.galleryUrl.replaceFirst(EHConsts.EXIndex, EHConsts.EHIndex);
        state.gallery?.galleryUrl = state.galleryUrl.replaceFirst(EHConsts.EXIndex, EHConsts.EHIndex);
        return galleryAndDetailAndApikey;
      } on DioError catch (e) {
        if (e.response?.statusCode != 404) {
          rethrow;
        }
        Log.verbose('Try redirect to EH failed, url: ${state.galleryUrl}');
      }
    }

    return EHRequest.requestDetailPage<Map<String, dynamic>>(
      galleryUrl: state.galleryUrl,
      parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
      useCacheIfAvailable: useCache,
    );
  }

  void _removeCache() {
    Get.find<EHCacheInterceptor>().removeCacheByUrl('${state.galleryUrl}?p=0');
  }
}
