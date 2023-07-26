import 'dart:async';
import 'dart:collection';

import 'package:clipboard/clipboard.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_cache_interceptor.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/widget/eh_add_tag_dialog.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
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

import '../../exception/eh_exception.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
import '../../mixin/update_global_gallery_status_logic_mixin.dart';
import '../../model/gallery.dart';
import '../../model/gallery_image.dart';
import '../../model/tag_set.dart';
import '../../service/history_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/storage_service.dart';
import '../../setting/read_setting.dart';
import '../../utils/process_util.dart';
import '../../utils/route_util.dart';
import '../../utils/search_util.dart';
import '../../utils/toast_util.dart';
import '../../widget/eh_download_dialog.dart';
import '../../widget/eh_download_hh_dialog.dart';
import '../../widget/jump_page_dialog.dart';
import '../download/list/local/local_gallery_list_page_logic.dart';
import 'details_page_state.dart';

class DetailsPageLogic extends GetxController with LoginRequiredMixin, Scroll2TopLogicMixin, UpdateGlobalGalleryStatusLogicMixin {
  static const String galleryId = 'galleryId';
  static const String uploaderId = 'uploaderId';
  static const String detailsId = 'detailsId';
  static const String pageCountId = 'pageCountId';
  static const String ratingId = 'ratingId';
  static const String favoriteId = 'favoriteId';
  static const String readButtonId = 'readButtonId';
  static const String thumbnailsId = 'thumbnailsId';
  static const String thumbnailId = 'thumbnailId';
  static const String loadingStateId = 'fullPageLoadingStateId';
  static const String loadingThumbnailsStateId = 'loadingThumbnailsStateId';
  static const String addFavoriteStateId = 'addFavoriteStateId';
  static const String ratingStateId = 'ratingStateId';

  /// there may be more than one DetailsPages in route stack at same time, eg: tap a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  static final List<DetailsPageLogic> _stack = <DetailsPageLogic>[];

  static DetailsPageLogic? get current => _stack.isEmpty ? null : _stack.last;

  final DetailsPageState state = DetailsPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();
  final LocalGalleryService localGalleryService = Get.find();
  final SuperResolutionService superResolutionService = Get.find();
  final LocalGalleryListPageLogic localGalleryPageLogic = Get.find();
  final StorageService storageService = Get.find();
  final HistoryService historyService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();

  DetailsPageLogic() {
    _stack.add(this);
  }

  DetailsPageLogic.preview();

  @override
  void onInit() {
    if (Get.arguments is! Map) {
      return;
    }

    state.gid = Get.arguments['gid'];
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
      galleryAndDetailAndApikey = await _getDetailsWithRedirectAndFallback(useCache: !refresh);
    } on DioError catch (e) {
      Log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      if (!refresh) {
        updateSafely([loadingStateId]);
      }
      return;
    } on EHException catch (e) {
      Log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      if (!refresh) {
        updateSafely([loadingStateId]);
      }
      return;
    }

    state.galleryDetails = galleryAndDetailAndApikey['galleryDetails'];
    state.apikey = galleryAndDetailAndApikey['apikey'];
    state.nextPageIndexToLoadThumbnails = 1;

    await tagTranslationService.translateGalleryDetailTagsIfNeeded(state.galleryDetails!);

    _addColor2WatchedTags(state.galleryDetails!.fullTags);

    state.loadingState = LoadingState.success;
    List<Object> updateIds = [detailsId, loadingStateId];
    _dealWithMissingField(updateIds, galleryAndDetailAndApikey['gallery']! as Gallery);
    updateSafely(updateIds);

    SchedulerBinding.instance.scheduleTask(() => historyService.record(state.gallery), Priority.animation);
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
      snack('failToGetThumbnails'.tr, e.message, longDuration: true);
      state.loadingThumbnailsState = LoadingState.error;
      updateSafely([loadingThumbnailsStateId]);
      return;
    } on EHException catch (e) {
      Log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, longDuration: true);
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
    LocalGallery? localGallery = localGalleryService.gid2EHViewerGallery[state.gallery!.gid];

    /// local ehviewer gallery
    if (localGallery != null) {
      localGalleryPageLogic.goToReadPage(localGallery);
      return;
    }

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

  Future<void> handleTapFavorite({required bool useDefault}) async {
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

    int favIndex;
    if (useDefault && UserSetting.defaultFavoriteIndex.value != null) {
      favIndex = UserSetting.defaultFavoriteIndex.value!;
    } else {
      ({int favIndex, bool remember})? result = await Get.dialog(EHFavoriteDialog(selectedIndex: state.gallery?.favoriteTagIndex));
      if (result == null) {
        return;
      }
      if (result.remember == true) {
        UserSetting.saveDefaultFavoriteIndex(result.favIndex);
      }
      favIndex = result.favIndex;
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
      snack('favoriteGalleryFailed'.tr, e.message, longDuration: true);
      state.favoriteState = LoadingState.error;
      updateSafely([addFavoriteStateId]);
      return;
    } on EHException catch (e) {
      Log.error('favoriteGalleryFailed'.tr, e.message);
      snack('favoriteGalleryFailed'.tr, e.message, longDuration: true);
      state.favoriteState = LoadingState.error;
      updateSafely([addFavoriteStateId]);
      return;
    }

    _removeCache();

    state.favoriteState = LoadingState.idle;
    updateSafely([addFavoriteStateId]);

    updateGlobalGalleryStatus();

    toast('favoriteGallerySuccess'.tr, isCenter: false);
  }

  Future<void> handleTapRating() async {
    if (state.apikey == null) {
      return;
    }

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
        state.apikey!,
        (rating * 2).toInt(),
        EHSpiderParser.galleryRatingResponse2RatingInfo,
      );
    } on DioError catch (e) {
      Log.error('ratingFailed'.tr, e.message);
      snack('ratingFailed'.tr, e.message);
      state.ratingState = LoadingState.error;
      updateSafely([ratingStateId]);
      return;
    } on EHException catch (e) {
      Log.error('ratingFailed'.tr, e.message);
      snack('ratingFailed'.tr, e.message);
      state.ratingState = LoadingState.error;
      updateSafely([ratingStateId]);
      return;
    } on FormatException catch (_) {
      /// expired apikey
      await DetailsPageLogic.current!.handleRefresh();
      return handleTapRating();
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

    toast('ratingSuccess'.tr, isCenter: false);
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

    if (archiveStatus == ArchiveStatus.paused) {
      return archiveDownloadService.resumeDownloadArchive(archive);
    }

    if (ArchiveStatus.unlocking.index <= archiveStatus.index && archiveStatus.index < ArchiveStatus.downloaded.index) {
      return archiveDownloadService.pauseDownloadArchive(archive);
    }

    if (archiveStatus == ArchiveStatus.completed) {
      String storageKey = 'readIndexRecord::${archive.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;
      List<GalleryImage> images = archiveDownloadService.getUnpackedImages(archive.gid);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          galleryTitle: archive.title,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
          currentImageIndex: readIndexRecord,
          pageCount: images.length,
          isOriginal: archive.isOriginal,
          readProgressRecordStorageKey: storageKey,
          images: images,
          useSuperResolution: superResolutionService.get(archive.gid, SuperResolutionType.archive) != null,
        ),
      );
    }
  }

  Future<void> handleTapHH() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    String? resolution = await Get.dialog(EHDownloadHHDialog(archivePageUrl: state.galleryDetails!.archivePageUrl));
    if (resolution == null) {
      return;
    }

    Log.info('HH Download: ${state.gallery!.gid}, resolution: $resolution');

    String result;
    try {
      result = await EHRequest.requestHHDownload(
        url: state.galleryDetails!.archivePageUrl,
        resolution: resolution,
        parser: EHSpiderParser.downloadHHPage2Result,
      );
    } on DioError catch (e) {
      Log.error('H@H download error', e.message);
      snack('failed'.tr, e.message);
      return;
    } on EHException catch (e) {
      Log.error('H@H download error', e.message);
      snack('failed'.tr, e.message);
      return;
    }

    toast(result, isShort: false);
  }

  void searchSimilar() {
    if (state.galleryDetails == null) {
      return;
    }
    newSearch('title:"${state.galleryDetails!.rawTitle.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|{.*?}'), '').trim()}"', true);
  }

  void searchUploader() {
    newSearch('uploader:"${state.gallery!.uploader!}"', true);
  }

  Future<void> handleTapTorrent() async {
    Get.dialog(EHGalleryTorrentsDialog(gid: state.gallery!.gid, token: state.gallery!.token));
  }

  Future<void> handleTapStatistic() async {
    Get.dialog(EHGalleryStatDialog(gid: state.gallery!.gid, token: state.gallery!.token));
  }

  Future<void> handleTapJumpButton() async {
    if (state.galleryDetails == null) {
      return;
    }

    int? pageIndex = await Get.dialog(
      JumpPageDialog(
        totalPageNo: state.galleryDetails!.thumbnailsPageCount,
        currentNo: 1,
      ),
    );

    if (pageIndex != null) {
      toRoute(Routes.thumbnails, arguments: pageIndex);
    }
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

  Future<void> handleTapDeleteDownload(BuildContext context, int gid, DownloadPageGalleryType downloadPageGalleryType) async {
    bool? result = await showDialog(
      context: context,
      builder: (_) => EHDialog(title: 'delete'.tr + '?'),
    );

    if (result == null || !result) {
      return;
    }

    if (downloadPageGalleryType == DownloadPageGalleryType.download) {
      galleryDownloadService.deleteGalleryByGid(gid);
    }

    if (downloadPageGalleryType == DownloadPageGalleryType.archive) {
      archiveDownloadService.deleteArchiveByGid(gid);
    }
  }

  Future<void> handleAddTag(BuildContext context) async {
    if (state.galleryDetails == null) {
      return;
    }

    if (!checkLogin()) {
      return;
    }

    String? newTag = await showDialog(context: context, builder: (_) => EHAddTagDialog());
    if (newTag == null) {
      return;
    }

    Log.info('Add tag:$newTag');

    toast('${'addTag'.tr}: $newTag');

    String? errMsg;
    try {
      errMsg = await EHRequest.voteTag(
        state.gallery!.gid,
        state.gallery!.token,
        UserSetting.ipbMemberId.value!,
        state.apikey!,
        newTag,
        true,
        parser: EHSpiderParser.voteTagResponse2ErrorMessage,
      );
    } on DioError catch (e) {
      Log.error('addTagFailed'.tr, e.message);
      snack('addTagFailed'.tr, e.message);
      return;
    } on EHException catch (e) {
      Log.error('addTagFailed'.tr, e.message);
      snack('addTagFailed'.tr, e.message);
      return;
    }

    if (!isEmptyOrNull(errMsg)) {
      snack('addTagFailed'.tr, errMsg!, longDuration: true);
      return;
    } else {
      toast('addTagSuccess'.tr);
      _removeCache();
    }
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
          galleryTitle: state.gallery!.title,
          galleryUrl: state.galleryUrl,
          initialIndex: forceIndex ?? readIndexRecord,
          currentImageIndex: forceIndex ?? readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: state.gallery!.pageCount!,
          useSuperResolution: false,
        ),
      )?.then((_) => updateSafely([readButtonId]));
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
        galleryTitle: state.gallery!.title,
        galleryUrl: state.galleryUrl,
        initialIndex: forceIndex ?? readIndexRecord,
        currentImageIndex: forceIndex ?? readIndexRecord,
        readProgressRecordStorageKey: storageKey,
        pageCount: state.gallery!.pageCount!,
        useSuperResolution: superResolutionService.get(state.gallery!.gid, SuperResolutionType.gallery) != null,
      ),
    )?.then((_) => updateSafely([readButtonId]));
  }

  int getReadIndexRecord() {
    if (state.gallery == null) {
      return 0;
    }
    return storageService.read('readIndexRecord::${state.gallery!.gid}') ?? 0;
  }

  Future<Map<String, dynamic>> _getDetailsWithRedirectAndFallback({bool useCache = true}) async {
    final String? firstLink;
    final String? secondLink;

    /// 1. if redirect is enabled, try EH site first for EX link
    /// 2. if a gallery can't be found in EH site, it may be moved into EX site
    if (state.galleryUrl.contains(EHConsts.EXIndex) && EHSetting.redirect2Eh.isTrue) {
      firstLink = state.galleryUrl.replaceFirst(EHConsts.EXIndex, EHConsts.EHIndex);
      secondLink = state.galleryUrl;
    } else if (state.galleryUrl.contains(EHConsts.EXIndex) && EHSetting.redirect2Eh.isFalse) {
      firstLink = null;
      secondLink = state.galleryUrl;
    } else {
      firstLink = state.galleryUrl;
      secondLink = state.galleryUrl.replaceFirst(EHConsts.EHIndex, EHConsts.EXIndex);
    }

    /// if we can't find gallery via firstLink, try second link
    if (!isEmptyOrNull(firstLink)) {
      try {
        Map<String, dynamic> galleryAndDetailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
          galleryUrl: firstLink!,
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
          useCacheIfAvailable: useCache,
        );
        state.gallery?.galleryUrl = state.galleryUrl = firstLink;
        return galleryAndDetailAndApikey;
      } on DioError catch (e) {
        if (e.response?.statusCode != 404) {
          rethrow;
        }
        Log.verbose('Can\'t find gallery, firstLink: $firstLink');
      }
    }

    try {
      Map<String, dynamic> galleryAndDetailAndApikey = await EHRequest.requestDetailPage<Map<String, dynamic>>(
        galleryUrl: secondLink,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        useCacheIfAvailable: useCache,
      );
      state.gallery?.galleryUrl = state.galleryUrl = secondLink;
      return galleryAndDetailAndApikey;
    } on DioError catch (_) {
      Log.verbose('Can\'t find gallery, secondLink: $secondLink');
      rethrow;
    }
  }

  /// some field in [gallery] sometimes is null
  void _dealWithMissingField(List<Object> updateIds, Gallery newGallery) {
    if (state.gallery == null) {
      state.gallery = newGallery;
      updateIds.add(galleryId);
      updateIds.add(pageCountId);
      updateIds.add(uploaderId);
      updateIds.add(favoriteId);
      updateIds.add(ratingId);
      updateIds.add(pageCountId);
      return;
    }

    /// page count is null in favorite page
    if (state.gallery?.pageCount != newGallery.pageCount) {
      state.gallery?.pageCount = newGallery.pageCount;
      updateIds.add(pageCountId);
    }

    /// uploader info is null in favorite page
    if (state.gallery?.uploader != newGallery.uploader) {
      state.gallery?.uploader = newGallery.uploader;
      updateIds.add(uploaderId);
    }

    /// favorite info is null in ranklist page
    if (state.gallery?.isFavorite != newGallery.isFavorite ||
        state.gallery?.favoriteTagIndex != newGallery.favoriteTagIndex ||
        state.gallery?.favoriteTagName != newGallery.favoriteTagName) {
      state.gallery?.isFavorite = newGallery.isFavorite;
      state.gallery?.favoriteTagIndex = newGallery.favoriteTagIndex;
      state.gallery?.favoriteTagName = newGallery.favoriteTagName;
      updateIds.add(favoriteId);
    }

    /// rating info is null in ranklist page
    if (state.gallery?.hasRated != newGallery.hasRated || state.gallery?.rating != newGallery.rating) {
      state.gallery?.hasRated = newGallery.hasRated;
      state.gallery?.rating = newGallery.rating;
      updateIds.add(ratingId);
    }
  }

  void _addColor2WatchedTags(LinkedHashMap<String, List<GalleryTag>> fullTags) {
    for (List<GalleryTag> tags in fullTags.values) {
      for (GalleryTag tag in tags) {
        if (tag.color != null || tag.backgroundColor != null) {
          continue;
        }

        TagSet? tagSet = MyTagsSetting.getOnlineTagSetByTagData(tag.tagData);
        if (tagSet == null) {
          continue;
        }

        tag.backgroundColor = tagSet.backgroundColor ?? const Color(0xFF3377FF);
        tag.color = tagSet.backgroundColor == null
            ? const Color(0xFFF1F1F1)
            : ThemeData.estimateBrightnessForColor(tagSet.backgroundColor!) == Brightness.light
                ? const Color.fromRGBO(9, 9, 9, 1)
                : const Color(0xFFF1F1F1);
      }
    }
  }

  void _removeCache() {
    Get.find<EHCacheInterceptor>().removeGalleryDetailPageCache(state.galleryUrl);
  }
}
