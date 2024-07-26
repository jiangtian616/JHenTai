import 'dart:async';
import 'dart:collection';

import 'package:clipboard/clipboard.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/dao/archive_dao.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
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
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:share_plus/share_plus.dart';

import '../../exception/eh_site_exception.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
import '../../mixin/update_global_gallery_status_logic_mixin.dart';
import '../../model/gallery_detail.dart';
import '../../model/gallery_image.dart';
import '../../model/gallery_metadata.dart';
import '../../model/gallery_note.dart';
import '../../model/search_config.dart';
import '../../model/tag_set.dart';
import '../../service/history_service.dart';
import '../../service/gallery_download_service.dart';
import '../../service/local_block_rule_service.dart';
import '../../service/storage_service.dart';
import '../../setting/eh_setting.dart';
import '../../setting/preference_setting.dart';
import '../../setting/read_setting.dart';
import '../../setting/site_setting.dart';
import '../../utils/process_util.dart';
import '../../utils/route_util.dart';
import '../../utils/search_util.dart';
import '../../utils/toast_util.dart';
import '../../utils/uuid_util.dart';
import '../../widget/eh_download_dialog.dart';
import '../../widget/eh_download_hh_dialog.dart';
import '../../widget/eh_gallery_history_dialog.dart';
import '../../widget/eh_tag_dialog.dart';
import '../../widget/jump_page_dialog.dart';
import '../../widget/re_unlock_dialog.dart';
import 'details_page_state.dart';

class DetailsPageArgument {
  final GalleryUrl galleryUrl;

  final Gallery? gallery;

  final ({GalleryDetail galleryDetails, String apikey})? detailsPageInfo;

  const DetailsPageArgument({required this.galleryUrl, this.gallery, this.detailsPageInfo});

  @override
  String toString() {
    return 'DetailsPageArgument{galleryUrl: $galleryUrl, gallery: $gallery, detailsPageInfo: $detailsPageInfo}';
  }
}

class DetailsPageLogic extends GetxController with LoginRequiredMixin, Scroll2TopLogicMixin, UpdateGlobalGalleryStatusLogicMixin {
  static const String galleryId = 'galleryId';
  static const String uploaderId = 'uploaderId';
  static const String detailsId = 'detailsId';
  static const String metadataId = 'metadataId';
  static const String languageId = 'languageId';
  static const String pageCountId = 'pageCountId';
  static const String ratingId = 'ratingId';
  static const String favoriteId = 'favoriteId';
  static const String readButtonId = 'readButtonId';
  static const String thumbnailsId = 'thumbnailsId';
  static const String thumbnailId = 'thumbnailId';
  static const String loadingStateId = 'fullPageLoadingStateId';
  static const String loadingThumbnailsStateId = 'loadingThumbnailsStateId';

  /// there may be more than one DetailsPages in route stack at same time, eg: tap a link in a comment.
  /// use this param as a 'tag' to get target [DetailsPageLogic] and [DetailsPageState].
  static final List<DetailsPageLogic> _stack = <DetailsPageLogic>[];

  static DetailsPageLogic? get current => _stack.isEmpty ? null : _stack.last;

  final DetailsPageState state = DetailsPageState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();
  final SuperResolutionService superResolutionService = Get.find();
  final StorageService storageService = Get.find();
  final HistoryService historyService = Get.find();
  final TagTranslationService tagTranslationService = Get.find();
  final LocalBlockRuleService localBlockRuleService = Get.find();

  DetailsPageLogic() {
    _stack.add(this);
  }

  DetailsPageLogic.preview();

  @override
  void onInit() {
    super.onInit();

    if (Get.arguments is! DetailsPageArgument) {
      return;
    }

    DetailsPageArgument argument = Get.arguments;

    state.galleryUrl = argument.galleryUrl;
    state.gallery = argument.gallery;
    state.galleryDetails = argument.detailsPageInfo?.galleryDetails;
    state.apikey = argument.detailsPageInfo?.apikey;
  }

  @override
  void onReady() async {
    super.onReady();

    if (state.galleryDetails == null || state.apikey == null) {
      getDetails();
    }
  }

  @override
  void onClose() {
    super.onClose();
    _stack.remove(this);
  }

  String get mainTitleText {
    if (state.gallery?.title != null) {
      return state.gallery!.title;
    }

    if (SiteSetting.preferJapaneseTitle.isTrue) {
      return state.galleryDetails?.japaneseTitle ??
          state.galleryDetails?.rawTitle ??
          state.galleryMetadata?.japaneseTitle ??
          state.galleryMetadata?.title ??
          '';
    } else {
      return state.galleryDetails?.rawTitle ??
          state.galleryDetails?.japaneseTitle ??
          state.galleryMetadata?.title ??
          state.galleryMetadata?.japaneseTitle ??
          '';
    }
  }

  String get uploader => state.galleryDetails?.uploader ?? state.gallery?.uploader ?? state.galleryMetadata?.uploader ?? '';

  Future<void> getDetails({bool refreshPageImmediately = true, bool useCacheIfAvailable = true}) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    if (refreshPageImmediately) {
      updateSafely([loadingStateId]);
    }

    log.info('Get gallery details:${state.galleryUrl.url}');

    ({GalleryDetail galleryDetails, String apikey})? detailPageInfo;
    try {
      detailPageInfo = await _getDetailsWithRedirectAndFallback(useCache: useCacheIfAvailable);
    } on DioException catch (e) {
      log.error('Get Gallery Detail Failed', e.errorMsg, e.stackTrace);
      snack('getGalleryDetailFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    } on EHSiteException catch (e) {
      if (e.type == EHSiteExceptionType.galleryDeleted) {
        return _handleGalleryDeleted(refreshPageImmediately, e);
      }

      log.error('Get Gallery Detail Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    } catch (e, s) {
      log.error('Get Gallery Detail Failed', e, s);
      snack('getGalleryDetailFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    }

    state.galleryDetails = detailPageInfo.galleryDetails;
    state.apikey = detailPageInfo.apikey;
    state.nextPageIndexToLoadThumbnails = 1;

    await tagTranslationService.translateTagsIfNeeded(state.galleryDetails!.tags);

    _addColor2WatchedTags(state.galleryDetails!.tags);

    state.galleryDetails!.comments = await localBlockRuleService.executeRules(state.galleryDetails!.comments);

    state.loadingState = LoadingState.success;
    updateSafely(_judgeUpdateIds());

    SchedulerBinding.instance.scheduleTask(
      () => historyService.record(galleryDetail2GalleryHistoryModel(state.galleryDetails!)),
      Priority.animation,
    );
    SchedulerBinding.instance.scheduleTask(
      () => GalleryDao.updateGalleryTags(state.galleryDetails!.galleryUrl.gid, tagMap2TagString(state.galleryDetails!.tags)),
      Priority.animation,
    );
    SchedulerBinding.instance.scheduleTask(
      () => ArchiveDao.updateArchiveTags(state.galleryDetails!.galleryUrl.gid, tagMap2TagString(state.galleryDetails!.tags)),
      Priority.animation,
    );
  }

  Future<void> _handleGalleryDeleted(bool refreshPageImmediately, EHSiteException exception) async {
    log.trace('Gallery deleted: ${state.galleryUrl.url}, try to get metadata');

    try {
      state.galleryMetadata = await ehRequest.requestGalleryMetadata<GalleryMetadata>(
        gid: state.galleryUrl.gid,
        token: state.galleryUrl.token,
        parser: EHSpiderParser.galleryMetadataJson2GalleryMetadata,
      );
    } on DioException catch (e) {
      log.error('Get Gallery Metadata Failed', e.errorMsg);
      snack('getGalleryDetailFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    } on EHSiteException catch (e) {
      log.error('Get Gallery Metadata Failed', e.message);
      snack('getGalleryDetailFailed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    } catch (e, s) {
      log.error('Get Gallery Metadata Failed', e, s);
      snack('getGalleryDetailFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      if (refreshPageImmediately) {
        updateSafely([loadingStateId]);
      }
      return;
    }

    state.copyRighter = exception.message;
    state.nextPageIndexToLoadThumbnails = 1;

    state.loadingState = LoadingState.success;
    updateSafely(_judgeUpdateIds4MetaData());
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
      newThumbNails = await ehRequest.requestDetailPage(
        galleryUrl: state.galleryUrl.url,
        thumbnailsPageIndex: state.nextPageIndexToLoadThumbnails,
        parser: EHSpiderParser.detailPage2Thumbnails,
      );
    } on DioException catch (e) {
      log.error('failToGetThumbnails'.tr, e.errorMsg);
      snack('failToGetThumbnails'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingThumbnailsState = LoadingState.error;
      updateSafely([loadingThumbnailsStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('failToGetThumbnails'.tr, e.message);
      snack('failToGetThumbnails'.tr, e.message, isShort: true);
      state.loadingThumbnailsState = LoadingState.error;
      updateSafely([loadingThumbnailsStateId]);
      return;
    } catch (e, s) {
      log.error('failToGetThumbnails'.tr, e, s);
      snack('failToGetThumbnails'.tr, e.toString(), isShort: true);
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
    return getDetails(refreshPageImmediately: false, useCacheIfAvailable: false);
  }

  Future<void> handleTapDownload() async {
    GalleryDownloadService downloadService = Get.find<GalleryDownloadService>();
    GalleryDownloadedData? galleryDownloadedData = downloadService.gallerys.singleWhereOrNull((g) => g.gid == state.galleryUrl.gid);
    GalleryDownloadProgress? downloadProgress = downloadService.galleryDownloadInfos[state.galleryUrl.gid]?.downloadProgress;

    /// new download
    if (galleryDownloadedData == null || downloadProgress == null) {
      ({String group, bool downloadOriginalImage})? result = await Get.dialog(
        EHDownloadDialog(
          title: 'chooseGroup'.tr,
          currentGroup: downloadSetting.defaultGalleryGroup.value,
          candidates: downloadService.allGroups,
          showDownloadOriginalImageCheckBox: userSetting.hasLoggedIn(),
          downloadOriginalImage: downloadSetting.downloadOriginalImageByDefault.value,
        ),
      );

      if (result == null) {
        return;
      }

      if (state.gallery == null && state.galleryDetails == null) {
        return;
      }

      GalleryDownloadedData galleryDownloadedData = GalleryDownloadedData(
        gid: state.galleryDetails?.galleryUrl.gid ?? state.gallery!.galleryUrl.gid,
        token: state.galleryDetails?.galleryUrl.token ?? state.gallery!.galleryUrl.token,
        title: mainTitleText,
        category: state.galleryDetails?.category ?? state.gallery!.category,
        pageCount: state.galleryDetails?.pageCount ?? state.gallery!.pageCount!,
        galleryUrl: state.galleryDetails?.galleryUrl.url ?? state.gallery!.galleryUrl.url,
        uploader: state.galleryDetails?.uploader ?? state.gallery?.uploader,
        publishTime: state.galleryDetails?.publishTime ?? state.gallery!.publishTime,
        downloadStatusIndex: DownloadStatus.downloading.index,
        downloadOriginalImage: result.downloadOriginalImage,
        sortOrder: 0,
        groupName: result.group,
        insertTime: DateTime.now().toString(),
        priority: GalleryDownloadService.defaultDownloadGalleryPriority,
        tags: state.galleryDetails != null ? tagMap2TagString(state.galleryDetails!.tags) : tagMap2TagString(state.gallery!.tags),
        tagRefreshTime: DateTime.now().toString(),
      );
      downloadService.downloadGallery(galleryDownloadedData);

      updateGlobalGalleryStatus();

      toast('${'beginToDownload'.tr}： ${state.galleryUrl.gid}', isCenter: false);
      return;
    }

    if (downloadProgress.downloadStatus == DownloadStatus.paused) {
      downloadService.resumeDownloadGallery(galleryDownloadedData);
      toast('${'resume'.tr}： ${state.galleryUrl.gid}', isCenter: false);
      return;
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloading) {
      downloadService.pauseDownloadGallery(galleryDownloadedData);
      toast('${'pause'.tr}： ${state.galleryUrl.gid}', isCenter: false);
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloaded && state.galleryDetails?.newVersionGalleryUrl == null) {
      goToReadPage();
    } else if (downloadProgress.downloadStatus == DownloadStatus.downloaded && state.galleryDetails?.newVersionGalleryUrl != null) {
      downloadService.updateGallery(galleryDownloadedData, state.galleryDetails!.newVersionGalleryUrl!);
      toast('${'update'.tr}： ${state.galleryUrl.gid}', isCenter: false);
    }
  }

  Future<void> handleTapFavorite({required bool useDefault}) async {
    if (!checkLogin()) {
      return;
    }

    if (state.favoriteState == LoadingState.loading) {
      return;
    }

    if (!favoriteSetting.inited) {
      favoriteSetting.fetchDataFromEH();
    }

    int? currentFavIndex = state.galleryDetails?.favoriteTagIndex ?? state.gallery?.favoriteTagIndex;

    ({bool isDelete, int favIndex, String note, bool remember}) operation;
    if (useDefault && userSetting.defaultFavoriteIndex.value != null) {
      state.favoriteState = LoadingState.loading;
      updateSafely([favoriteId]);

      /// need to get current favorite note if we have favorite this gallery and we are not unfavoriting it.
      GalleryNote? galleryNote;
      if (currentFavIndex != null && currentFavIndex != userSetting.defaultFavoriteIndex.value) {
        log.info('Get gallery favorite info: ${state.galleryUrl.gid}');
        try {
          galleryNote = await ehRequest.requestPopupPage<GalleryNote>(
            state.galleryUrl.gid,
            state.galleryUrl.token,
            'addfav',
            EHSpiderParser.favoritePopup2GalleryNote,
          );
        } on DioException catch (e) {
          log.error('getGalleryFavoriteInfoFailed'.tr, e.errorMsg);
          snack('getGalleryFavoriteInfoFailed'.tr, e.errorMsg ?? '', isShort: true);
          state.favoriteState = LoadingState.error;
          updateSafely([favoriteId]);
          return;
        } on EHSiteException catch (e) {
          log.error('getGalleryFavoriteInfoFailed'.tr, e.message);
          snack('getGalleryFavoriteInfoFailed'.tr, e.message, isShort: true);
          state.favoriteState = LoadingState.error;
          updateSafely([favoriteId]);
          return;
        } catch (e, s) {
          log.error('getGalleryFavoriteInfoFailed'.tr, e, s);
          snack('getGalleryFavoriteInfoFailed'.tr, e.toString(), isShort: true);
          state.favoriteState = LoadingState.error;
          updateSafely([favoriteId]);
          return;
        }
      }

      operation = (
        isDelete: currentFavIndex == userSetting.defaultFavoriteIndex.value,
        favIndex: userSetting.defaultFavoriteIndex.value!,
        note: galleryNote?.note ?? '',
        remember: false,
      );
    } else {
      /// we need to get current favorite note after opening the dialog if we have favorite this gallery.
      ({bool isDelete, int favIndex, String note, bool remember})? result = await Get.dialog(
        EHFavoriteDialog(
          selectedIndex: currentFavIndex,
          needInitNote: currentFavIndex != null,
          initNoteFuture: () => ehRequest.requestPopupPage<GalleryNote>(
            state.galleryUrl.gid,
            state.galleryUrl.token,
            'addfav',
            EHSpiderParser.favoritePopup2GalleryNote,
          ),
        ),
      );

      if (result == null) {
        return;
      }

      operation = result;
      state.favoriteState = LoadingState.loading;
      updateSafely([favoriteId]);
    }

    if (operation.remember == true) {
      userSetting.saveDefaultFavoriteIndex(operation.favIndex);
    }

    log.info('Favorite gallery: ${state.galleryUrl.gid}');

    try {
      if (operation.isDelete) {
        await ehRequest.requestRemoveFavorite(state.galleryUrl.gid, state.galleryUrl.token);
        favoriteSetting.decrementFavByIndex(operation.favIndex);
        state.gallery
          ?..favoriteTagIndex = null
          ..favoriteTagName = null;
        state.galleryDetails
          ?..favoriteTagIndex = null
          ..favoriteTagName = null;
      } else {
        await ehRequest.requestAddFavorite(state.galleryUrl.gid, state.galleryUrl.token, operation.favIndex, operation.note);
        favoriteSetting.incrementFavByIndex(operation.favIndex);
        favoriteSetting.decrementFavByIndex(currentFavIndex);
        state.gallery
          ?..favoriteTagIndex = operation.favIndex
          ..favoriteTagName = favoriteSetting.favoriteTagNames[operation.favIndex];
        state.galleryDetails
          ?..favoriteTagIndex = operation.favIndex
          ..favoriteTagName = favoriteSetting.favoriteTagNames[operation.favIndex];
      }
    } on DioException catch (e) {
      log.error(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e.errorMsg);
      snack(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.favoriteState = LoadingState.error;
      updateSafely([favoriteId]);
      return;
    } on EHSiteException catch (e) {
      log.error(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e.message);
      snack(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e.message, isShort: true);
      state.favoriteState = LoadingState.error;
      updateSafely([favoriteId]);
      return;
    } catch (e, s) {
      log.error(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e, s);
      snack(operation.isDelete ? 'removeFavoriteFailed'.tr : 'favoriteGalleryFailed'.tr, e.toString(), isShort: true);
      state.favoriteState = LoadingState.error;
      updateSafely([favoriteId]);
      return;
    }

    removeCache();

    state.favoriteState = LoadingState.idle;
    updateSafely([favoriteId]);

    updateGlobalGalleryStatus();

    toast(
      operation.isDelete ? 'removeFavoriteSuccess'.tr : 'favoriteGallerySuccess'.tr,
      isCenter: false,
    );
  }

  Future<void> handleTapRating() async {
    if (state.apikey == null) {
      return;
    }
    if (state.galleryDetails?.rating == null && state.gallery?.rating == null) {
      return;
    }

    if (!checkLogin()) {
      return;
    }

    double? rating = await Get.dialog(EHRatingDialog(
      rating: state.galleryDetails?.rating ?? state.gallery!.rating,
      hasRated: state.galleryDetails?.hasRated ?? state.gallery!.hasRated,
    ));

    if (rating == null) {
      return;
    }

    log.info('Rate gallery: ${state.galleryUrl.gid}, rating: $rating');

    state.ratingState = LoadingState.loading;
    updateSafely([ratingId]);

    Map<String, dynamic> ratingInfo;
    try {
      ratingInfo = await ehRequest.requestSubmitRating(
        state.galleryUrl.gid,
        state.galleryUrl.token,
        userSetting.ipbMemberId.value!,
        state.apikey!,
        (rating * 2).toInt(),
        EHSpiderParser.galleryRatingResponse2RatingInfo,
      );
    } on DioException catch (e) {
      log.error('ratingFailed'.tr, e.errorMsg);
      snack('ratingFailed'.tr, e.errorMsg ?? '');
      state.ratingState = LoadingState.error;
      updateSafely([ratingId]);
      return;
    } on EHSiteException catch (e) {
      log.error('ratingFailed'.tr, e.message);
      snack('ratingFailed'.tr, e.message);
      state.ratingState = LoadingState.error;
      updateSafely([ratingId]);
      return;
    } on FormatException catch (_) {
      /// expired apikey
      await DetailsPageLogic.current!.handleRefresh();
      return handleTapRating();
    } catch (e, s) {
      log.error('ratingFailed'.tr, e, s);
      snack('ratingFailed'.tr, e.toString());
      state.ratingState = LoadingState.error;
      updateSafely([ratingId]);
      return;
    }

    /// eg: {"rating_avg":0.93000000000000005,"rating_usr":0.5,"rating_cnt":21,"rating_cls":"ir irr"}
    state.gallery?.hasRated = true;
    state.gallery?.rating = ratingInfo['rating_usr'];
    state.galleryDetails?.hasRated = true;
    state.galleryDetails?.rating = ratingInfo['rating_usr'];
    state.galleryDetails?.realRating = ratingInfo['rating_avg'];
    state.galleryDetails?.ratingCount = ratingInfo['rating_cnt'];

    removeCache();

    state.ratingState = LoadingState.idle;
    updateSafely();

    updateGlobalGalleryStatus();

    toast('ratingSuccess'.tr, isCenter: false);
  }

  Future<void> handleTapArchive(BuildContext context) async {
    ArchiveStatus? archiveStatus = archiveDownloadService.archiveDownloadInfos[state.galleryUrl.gid]?.archiveStatus;

    /// new download
    if (archiveStatus == null) {
      if (!userSetting.hasLoggedIn()) {
        showLoginToast();
        return;
      }

      ({bool isOriginal, int size, String group})? result = await Get.dialog(
        EHArchiveDialog(
          title: 'chooseArchive'.tr,
          archivePageUrl: state.galleryDetails!.archivePageUrl,
          currentGroup: downloadSetting.defaultArchiveGroup.value,
          candidates: archiveDownloadService.allGroups,
        ),
      );
      if (result == null) {
        return;
      }

      ArchiveDownloadedData archive = ArchiveDownloadedData(
        gid: state.galleryDetails!.galleryUrl.gid,
        token: state.galleryDetails!.galleryUrl.token,
        title: mainTitleText,
        category: state.galleryDetails!.category,
        pageCount: state.galleryDetails!.pageCount,
        galleryUrl: state.galleryDetails!.galleryUrl.url,
        uploader: state.galleryDetails!.uploader,
        size: result.size,
        coverUrl: state.galleryDetails!.cover.url,
        publishTime: state.galleryDetails!.publishTime,
        archiveStatusCode: ArchiveStatus.unlocking.code,
        archivePageUrl: state.galleryDetails!.archivePageUrl,
        isOriginal: result.isOriginal,
        insertTime: DateTime.now().toString(),
        sortOrder: 0,
        groupName: result.group,
        tags: state.galleryDetails != null ? tagMap2TagString(state.galleryDetails!.tags) : tagMap2TagString(state.gallery!.tags),
        tagRefreshTime: DateTime.now().toString(),
      );
      archiveDownloadService.downloadArchive(archive);

      updateGlobalGalleryStatus();

      log.info('${'beginToDownloadArchive'.tr}: ${archive.title}');
      toast('${'beginToDownloadArchive'.tr}:  ${archive.title}', isCenter: false);
      return;
    }

    ArchiveDownloadedData archive = archiveDownloadService.archives.firstWhere((a) => a.gid == state.galleryUrl.gid);

    if (archiveStatus == ArchiveStatus.needReUnlock) {
      bool? ok = await showDialog(context: context, builder: (_) => const ReUnlockDialog());
      if (ok ?? false) {
        await archiveDownloadService.cancelArchive(archive.gid);
        await archiveDownloadService.downloadArchive(archive, resume: true);
      }
      return;
    }

    if (archiveStatus == ArchiveStatus.paused) {
      return archiveDownloadService.resumeDownloadArchive(archive.gid);
    }

    if (ArchiveStatus.unlocking.code <= archiveStatus.code && archiveStatus.code < ArchiveStatus.downloaded.code) {
      return archiveDownloadService.pauseDownloadArchive(archive.gid);
    }

    if (archiveStatus == ArchiveStatus.completed) {
      String storageKey = '${ConfigEnum.readIndexRecord.key}::${archive.gid}';
      int readIndexRecord = storageService.read(storageKey) ?? 0;
      List<GalleryImage> images = await archiveDownloadService.getUnpackedImages(archive.gid);

      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.archive,
          gid: archive.gid,
          token: archive.token,
          galleryTitle: archive.title,
          galleryUrl: archive.galleryUrl,
          initialIndex: readIndexRecord,
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
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    String? resolution = await Get.dialog(EHDownloadHHDialog(archivePageUrl: state.galleryDetails!.archivePageUrl));
    if (resolution == null) {
      return;
    }

    log.info('HH Download: ${state.galleryUrl.gid}, resolution: $resolution');

    String result;
    try {
      result = await ehRequest.requestHHDownload(
        url: state.galleryDetails!.archivePageUrl,
        resolution: resolution,
        parser: EHSpiderParser.downloadHHPage2Result,
      );
    } on DioException catch (e) {
      log.error('H@H download error', e.errorMsg);
      snack('failed'.tr, e.errorMsg ?? '');
      return;
    } on EHSiteException catch (e) {
      log.error('H@H download error', e.message);
      snack('failed'.tr, e.message);
      return;
    } catch (e, s) {
      log.error('H@H download error', e, s);
      snack('failed'.tr, e.toString());
      return;
    }

    toast(result, isShort: false);
  }

  void searchSimilar() {
    if (mainTitleText.isEmpty) {
      return;
    }

    newSearch(keyword: 'title:"${(mainTitleText).replaceAll(RegExp(r'\[.*?\]|\(.*?\)|{.*?}'), '').trim()}"', forceNewRoute: true);
  }

  void searchUploader() {
    if (state.galleryDetails?.uploader == null && state.gallery?.uploader == null) {
      return;
    }

    newSearch(keyword: 'uploader:"${state.galleryDetails?.uploader ?? state.gallery!.uploader}"', forceNewRoute: true);
  }

  Future<void> handleTapTorrent() async {
    Get.dialog(EHGalleryTorrentsDialog(gid: state.galleryUrl.gid, token: state.galleryUrl.token));
  }

  Future<void> handleTapStatistic() async {
    Get.dialog(EHGalleryStatDialog(gid: state.galleryUrl.gid, token: state.galleryUrl.token));
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

  void handleTapHistoryButton(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => EHGalleryHistoryDialog(
        currentGalleryTitle: state.gallery?.title ?? state.galleryDetails?.japaneseTitle ?? state.galleryDetails?.rawTitle ?? '',
        parentUrl: state.galleryDetails?.parentGalleryUrl,
        childrenGallerys: state.galleryDetails?.childrenGallerys,
      ),
    );
  }

  void onCommentVoted(GalleryComment comment, bool isVotingUp, String score) {
    comment.score = score;
    if (isVotingUp) {
      comment.votedUp = !comment.votedUp;
      comment.votedDown = false;
    } else {
      comment.votedDown = !comment.votedDown;
      comment.votedUp = false;
    }

    updateSafely([DetailsPageLogic.detailsId]);

    removeCache();
  }

  Future<void> shareGallery() async {
    log.info('Share gallery:${state.galleryUrl}');

    if (GetPlatform.isDesktop) {
      await FlutterClipboard.copy(state.galleryUrl.url);
      toast('hasCopiedToClipboard'.tr);
      return;
    }

    Share.share(
      state.galleryUrl.url,
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
    );
  }

  Future<void> handleTapDeleteDownload(BuildContext context, int gid, DownloadPageGalleryType downloadPageGalleryType) async {
    bool isUpdatingDependent = galleryDownloadService.isUpdatingDependent(gid);

    bool? result = await showDialog(
      context: context,
      builder: (_) => EHDialog(
        title: 'delete'.tr + '?',
        content: isUpdatingDependent ? 'deleteUpdatingDependentHint'.tr : null,
      ),
    );

    if (result == null || !result) {
      return;
    }

    if (downloadPageGalleryType == DownloadPageGalleryType.download) {
      galleryDownloadService.deleteGalleryByGid(gid);
    }

    if (downloadPageGalleryType == DownloadPageGalleryType.archive) {
      archiveDownloadService.deleteArchive(gid);
    }

    updateGlobalGalleryStatus();
  }

  void showTagDialog(GalleryTag tag) {
    Get.dialog(EHTagDialog(
      tagData: tag.tagData,
      gid: state.galleryDetails!.galleryUrl.gid,
      token: state.galleryDetails!.galleryUrl.token,
      apikey: state.apikey!,
      onTagVoted: (bool isVoted) => onTagVoted(tag, isVoted),
    ));
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

    log.info('Add tag:$newTag');

    toast('${'addTag'.tr}: $newTag');

    String? errMsg;
    try {
      errMsg = await ehRequest.voteTag(
        state.galleryUrl.gid,
        state.galleryUrl.token,
        userSetting.ipbMemberId.value!,
        state.apikey!,
        newTag,
        true,
        parser: EHSpiderParser.voteTagResponse2ErrorMessage,
      );
    } on DioException catch (e) {
      log.error('addTagFailed'.tr, e.errorMsg);
      snack('addTagFailed'.tr, e.errorMsg ?? '');
      return;
    } on EHSiteException catch (e) {
      log.error('addTagFailed'.tr, e.message);
      snack('addTagFailed'.tr, e.message);
      return;
    } catch (e, s) {
      log.error('addTagFailed'.tr, e, s);
      snack('addTagFailed'.tr, e.toString());
      return;
    }

    if (!isEmptyOrNull(errMsg)) {
      snack('addTagFailed'.tr, errMsg!, isShort: true);
      return;
    } else {
      toast('addTagSuccess'.tr);
      removeCache();
    }
  }

  void onTagVoted(GalleryTag tag, bool isVoted) {
    if (tag.voteStatus == EHTagVoteStatus.none) {
      tag.voteStatus = isVoted ? EHTagVoteStatus.up : EHTagVoteStatus.down;
    } else if (tag.voteStatus == EHTagVoteStatus.up) {
      tag.voteStatus = isVoted ? EHTagVoteStatus.up : EHTagVoteStatus.none;
    } else if (tag.voteStatus == EHTagVoteStatus.down) {
      tag.voteStatus = isVoted ? EHTagVoteStatus.none : EHTagVoteStatus.down;
    }

    updateSafely([detailsId]);
    removeCache();
  }

  Future<void> blockUser(GalleryComment comment) async {
    await localBlockRuleService.upsertBlockRule(
      LocalBlockRule(
        groupId: newUUID(),
        target: LocalBlockTargetEnum.comment,
        attribute: LocalBlockAttributeEnum.userName,
        pattern: LocalBlockPatternEnum.equal,
        expression: comment.username!,
      ),
    );
    if (comment.userId != null) {
      await localBlockRuleService.upsertBlockRule(
        LocalBlockRule(
          groupId: newUUID(),
          target: LocalBlockTargetEnum.comment,
          attribute: LocalBlockAttributeEnum.userId,
          pattern: LocalBlockPatternEnum.equal,
          expression: comment.userId!.toString(),
        ),
      );
    }

    state.galleryDetails!.comments = await localBlockRuleService.executeRules(state.galleryDetails!.comments);
    updateSafely([detailsId]);
    toast('success'.tr);
  }

  Future<void> blockUploader(String uploader) async {
    await localBlockRuleService.upsertBlockRule(
      LocalBlockRule(
        groupId: newUUID(),
        target: LocalBlockTargetEnum.gallery,
        attribute: LocalBlockAttributeEnum.uploader,
        pattern: LocalBlockPatternEnum.equal,
        expression: uploader,
      ),
    );
    toast('success'.tr);
  }

  void goToReadPage([int? forceIndex]) {
    String storageKey = '${ConfigEnum.readIndexRecord.key}::${state.galleryUrl.gid}';
    int readIndexRecord = storageService.read(storageKey) ?? 0;

    /// online
    if (galleryDownloadService.galleryDownloadInfos[state.galleryUrl.gid]?.downloadProgress == null) {
      toRoute(
        Routes.read,
        arguments: ReadPageInfo(
          mode: ReadMode.online,
          gid: state.galleryUrl.gid,
          token: state.galleryUrl.token,
          galleryTitle: mainTitleText,
          galleryUrl: state.galleryUrl.url,
          initialIndex: forceIndex ?? readIndexRecord,
          readProgressRecordStorageKey: storageKey,
          pageCount: state.galleryDetails?.pageCount ?? state.gallery?.pageCount ?? state.galleryMetadata!.pageCount,
          useSuperResolution: false,
        ),
      )?.then((_) => updateSafely([readButtonId]));
      return;
    }

    /// use GalleryDownloadedData's title
    GalleryDownloadedData gallery = galleryDownloadService.gallerys.firstWhere((g) => g.gid == state.galleryUrl.gid);

    if (readSetting.useThirdPartyViewer.isTrue && readSetting.thirdPartyViewerPath.value != null) {
      openThirdPartyViewer(galleryDownloadService.computeGalleryDownloadAbsolutePath(gallery.title, gallery.gid));
      return;
    }

    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.downloaded,
        gid: gallery.gid,
        token: gallery.token,
        galleryTitle: gallery.title,
        galleryUrl: gallery.galleryUrl,
        initialIndex: forceIndex ?? readIndexRecord,
        readProgressRecordStorageKey: storageKey,
        pageCount: gallery.pageCount,
        useSuperResolution: superResolutionService.get(state.galleryUrl.gid, SuperResolutionType.gallery) != null,
      ),
    )?.then((_) => updateSafely([readButtonId]));
  }

  int getReadIndexRecord() {
    return storageService.read('${ConfigEnum.readIndexRecord.key}::${state.galleryUrl.gid}') ?? 0;
  }

  Future<({GalleryDetail galleryDetails, String apikey})> _getDetailsWithRedirectAndFallback({bool useCache = true}) async {
    final GalleryUrl? firstLink;
    final GalleryUrl secondLink;

    /// 1. if redirect is enabled, try EH site first for EX link
    /// 2. if a gallery can't be found in EH site, it may be moved into EX site
    if (!state.galleryUrl.isEH) {
      if (ehSetting.redirect2Eh.isTrue && !_galleryOnlyInExSite()) {
        firstLink = state.galleryUrl.copyWith(isEH: true);
        secondLink = state.galleryUrl;
      } else {
        firstLink = null;
        secondLink = state.galleryUrl;
      }
    } else {
      /// fallback to EX site only if user has logged in
      firstLink = userSetting.hasLoggedIn() ? state.galleryUrl : null;
      secondLink = userSetting.hasLoggedIn() ? state.galleryUrl.copyWith(isEH: false) : state.galleryUrl;
    }

    /// if we can't find gallery via firstLink, try second link
    EHSiteException? firstException;
    if (firstLink != null) {
      log.trace('Try to find gallery via firstLink: $firstLink');
      try {
        ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await ehRequest.requestDetailPage<({GalleryDetail galleryDetails, String apikey})>(
          galleryUrl: firstLink.url,
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
          useCacheIfAvailable: useCache,
        );
        state.galleryUrl = firstLink;
        state.gallery?.galleryUrl = firstLink;
        state.galleryDetails?.galleryUrl = firstLink;
        return detailPageInfo;
      } on EHSiteException catch (e) {
        log.trace('Can\'t find gallery, firstLink: $firstLink, reason: ${e.message}');
        firstException = e;
      }
    }

    try {
      log.trace('Try to find gallery via secondLink: $secondLink');
      ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = await ehRequest.requestDetailPage<({GalleryDetail galleryDetails, String apikey})>(
        galleryUrl: secondLink.url,
        parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        useCacheIfAvailable: useCache,
      );
      state.galleryUrl = secondLink;
      state.gallery?.galleryUrl = secondLink;
      state.galleryDetails?.galleryUrl = secondLink;
      return detailPageInfo;
    } on EHSiteException catch (e) {
      log.trace('Can\'t find gallery, secondLink: $secondLink, reason: ${e.message}');
      throw firstException ?? e;
    }
  }

  bool _galleryOnlyInExSite() {
    if (state.gallery == null) {
      return false;
    }

    if (state.gallery!.tags.isEmpty) {
      return false;
    }

    return state.gallery!.tags.values.any((tagList) => tagList.any((tag) => tag.tagData.key == 'lolicon'));
  }

  /// some field in [gallery] sometimes is null
  List<Object> _judgeUpdateIds() {
    List<Object> updateIds = [detailsId, loadingStateId];

    if (state.gallery == null) {
      updateIds.add(galleryId);
      updateIds.add(languageId);
      updateIds.add(pageCountId);
      updateIds.add(uploaderId);
      updateIds.add(favoriteId);
      updateIds.add(ratingId);
      updateIds.add(pageCountId);
      return updateIds;
    }

    /// language is null in Minimal mode
    if (state.galleryDetails?.language != state.gallery?.language) {
      updateIds.add(languageId);
    }

    /// page count is null in favorite page
    if (state.galleryDetails?.pageCount != state.gallery?.pageCount) {
      updateIds.add(pageCountId);
    }

    /// uploader info is null in favorite page
    if (state.galleryDetails?.uploader != state.gallery?.uploader) {
      updateIds.add(uploaderId);
    }

    /// favorite info is null in ranklist page
    if (state.galleryDetails?.isFavorite != state.gallery?.isFavorite ||
        state.galleryDetails?.favoriteTagIndex != state.gallery?.favoriteTagIndex ||
        state.galleryDetails?.favoriteTagName != state.gallery?.favoriteTagName) {
      updateIds.add(favoriteId);
    }

    /// rating info is null in ranklist page
    if (state.galleryDetails?.hasRated != state.gallery?.hasRated || state.galleryDetails?.rating != state.gallery?.rating) {
      updateIds.add(ratingId);
    }

    return updateIds;
  }

  List<Object> _judgeUpdateIds4MetaData() {
    List<Object> updateIds = [detailsId, metadataId, loadingStateId];

    if (state.gallery == null) {
      updateIds.add(galleryId);
      updateIds.add(languageId);
      updateIds.add(pageCountId);
      updateIds.add(uploaderId);
      updateIds.add(favoriteId);
      updateIds.add(ratingId);
      updateIds.add(pageCountId);
      return updateIds;
    }

    /// language is null in Minimal mode
    if (state.galleryMetadata?.language != state.gallery?.language) {
      updateIds.add(languageId);
    }

    /// page count is null in favorite page
    if (state.galleryMetadata?.pageCount != state.gallery?.pageCount) {
      updateIds.add(pageCountId);
    }

    /// uploader info is null in favorite page
    if (state.galleryMetadata?.uploader != state.gallery?.uploader) {
      updateIds.add(uploaderId);
    }

    return updateIds;
  }

  void _addColor2WatchedTags(LinkedHashMap<String, List<GalleryTag>> fullTags) {
    for (List<GalleryTag> tags in fullTags.values) {
      for (GalleryTag tag in tags) {
        if (tag.color != null || tag.backgroundColor != null) {
          continue;
        }

        ({Color? tagSetBackGroundColor, WatchedTag tag})? tagInfo = myTagsSetting.getOnlineTagSetByTagData(tag.tagData);
        if (tagInfo == null) {
          continue;
        }

        Color? backGroundColor = tagInfo.tag.backgroundColor ?? tagInfo.tagSetBackGroundColor;
        tag.backgroundColor = backGroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor;
        tag.color = backGroundColor == null
            ? const Color(0xFFF1F1F1)
            : ThemeData.estimateBrightnessForColor(backGroundColor) == Brightness.light
                ? const Color.fromRGBO(9, 9, 9, 1)
                : const Color(0xFFF1F1F1);
      }
    }
  }

  void removeCache() {
    ehRequest.removeCacheByGalleryUrlAndPage(state.galleryUrl.url, 0);
  }
}
