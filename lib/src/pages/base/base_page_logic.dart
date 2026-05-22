import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/widget/eh_search_config_dialog.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../exception/eh_site_exception.dart';
import '../../mixin/scroll_to_top_logic_mixin.dart';
import '../../mixin/scroll_to_top_state_mixin.dart';
import '../../model/gallery.dart';
import '../../model/gallery_tag.dart';
import '../../network/eh_request.dart';
import '../../routes/routes.dart';
import '../../service/local_block_rule_service.dart';
import '../../service/tag_translation_service.dart';
import '../../setting/user_setting.dart';
import '../../utils/eh_spider_parser.dart';
import '../../service/log.dart';
import '../../utils/route_util.dart';
import '../../utils/snack_util.dart';
import '../../utils/toast_util.dart';
import '../../utils/uuid_util.dart';
import '../../widget/loading_state_indicator.dart';
import '../details/details_page_logic.dart';
import 'base_page_state.dart';

abstract class BasePageLogic extends GetxController with Scroll2TopLogicMixin {
  BasePageState get state;

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  final String appBarId = 'appBarId';
  final String bodyId = 'bodyId';
  final String refreshStateId = 'refreshStateId';
  final String loadingStateId = 'loadingStateId';

  bool get useSearchConfig;

  String get searchConfigKey => runtimeType.toString();

  bool get autoLoadForFirstTime => true;

  bool get autoLoadNeedLogin => false;

  @override
  Future<void> onInit() async {
    super.onInit();

    if (useSearchConfig) {
      localConfigService.read(configKey: ConfigEnum.searchConfig, subConfigKey: searchConfigKey).then((searchConfigString) {
        if (searchConfigString != null) {
          Map<String, dynamic> map = jsonDecode(searchConfigString);
          state.searchConfig = SearchConfig.fromJson(map);
        }
      }).whenComplete(() {
        state.searchConfigInitCompleter.complete();
      });
    } else {
      state.searchConfigInitCompleter.complete();
    }

    if (autoLoadForFirstTime) {
      if (autoLoadNeedLogin && !userSetting.hasLoggedIn()) {
        state.loadingState = LoadingState.noData;
        updateSafely([bodyId]);
        Get.engine.addPostFrameCallback((_) => toast('needLoginToOperate'.tr));
        return;
      }

      loadMore();
    }
  }

  /// pull-down
  Future<void> handlePullDown() async {
    if (state.prevGid == null) {
      return handleRefresh();
    }

    return loadBefore();
  }

  /// not clear current data before refresh
  /// [updateId] is for subclass to override
  Future<void> handleRefresh({String? updateId}) async {
    if (state.refreshState == LoadingState.loading) {
      return;
    }

    state.refreshState = LoadingState.loading;
    updateSafely([refreshStateId]);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage();
    } on DioException catch (e) {
      log.error('refreshGalleryFailed'.tr, e.errorMsg);
      snack('refreshGalleryFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('refreshGalleryFailed'.tr, e.message);
      snack(
        'refreshGalleryFailed'.tr,
        e.message,
        isShort: true,
        onPressed: e.referLink == null ? null : () => launchUrlString(e.referLink!, mode: LaunchMode.externalApplication),
      );
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    } catch (e) {
      log.error('refreshGalleryFailed'.tr, e.toString());
      snack('refreshGalleryFailed'.tr, e.toString(), isShort: true);
      state.refreshState = LoadingState.error;
      updateSafely([refreshStateId]);
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys, cleanDuplicate: false);

    state.gallerys = gallerys;
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;
    state.galleryCollectionKey = Key(newUUID());

    state.refreshState = LoadingState.idle;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    if (updateId != null) {
      updateSafely([updateId]);
    } else {
      updateSafely();
    }
  }

  /// clear current data first, then refresh
  Future<void> handleClearAndRefresh() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;

    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.seek = DateTime.now();
    state.totalCount = null;
    state.favoriteSortOrder = null;

    jump2Top();

    updateSafely();

    return loadMore(checkLoadingState: false);
  }

  /// pull-down to load page before(after jumping to a certain page), after load, we must restore [state.downloadState]
  /// to [prevState] in case of [prevState] is [noMore]
  Future<void> loadBefore() async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    LoadingState prevState = state.loadingState;
    state.loadingState = LoadingState.loading;

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(prevGid: state.prevGid);
    } on DioException catch (e) {
      log.error('getGallerysFailed'.tr, e.errorMsg);
      snack('getGallerysFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('getGallerysFailed'.tr, e.message);
      snack(
        'getGallerysFailed'.tr,
        e.message,
        isShort: true,
        onPressed: e.referLink == null ? null : () => launchUrlString(e.referLink!, mode: LaunchMode.externalApplication),
      );
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    } catch (e) {
      log.error('getGallerysFailed'.tr, e.toString());
      snack('getGallerysFailed'.tr, e.toString(), isShort: true);
      state.loadingState = prevState;
      updateSafely([loadingStateId]);
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys);

    state.gallerys.insertAll(0, gallerys);
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;

    state.loadingState = prevState;

    updateSafely();
  }

  /// has scrolled to bottom, so need to load more data.
  Future<void> loadMore({bool checkLoadingState = true}) async {
    if (checkLoadingState && state.loadingState == LoadingState.loading) {
      return;
    }

    state.loadingState = LoadingState.loading;
    updateSafely([loadingStateId]);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(nextGid: state.nextGid);
    } on DioException catch (e) {
      log.error('getGallerysFailed'.tr, e.errorMsg);
      snack('getGallerysFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('getGallerysFailed'.tr, e.message);
      snack(
        'getGallerysFailed'.tr,
        e.message,
        isShort: true,
        onPressed: e.referLink == null ? null : () => launchUrlString(e.referLink!, mode: LaunchMode.externalApplication),
      );
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } catch (e) {
      log.error('getGallerysFailed'.tr, e.toString());
      snack('getGallerysFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys);

    state.gallerys.addAll(gallerys);
    state.totalCount = galleryPage.totalCount;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }

  Future<void> jumpPage(DateTime dateTime) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    log.info('Jump page to $dateTime');

    state.gallerys.clear();
    state.loadingState = LoadingState.loading;
    updateSafely();

    state.scrollController.jumpTo(0);

    GalleryPageInfo galleryPage;
    try {
      galleryPage = await getGalleryPage(nextGid: state.nextGid, prevGid: state.prevGid, seek: dateTime);
    } on DioException catch (e) {
      log.error('getGallerysFailed'.tr, e.errorMsg);
      snack('getGallerysFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } on EHSiteException catch (e) {
      log.error('getGallerysFailed'.tr, e.message);
      snack(
        'getGallerysFailed'.tr,
        e.message,
        isShort: true,
        onPressed: e.referLink == null ? null : () => launchUrlString(e.referLink!, mode: LaunchMode.externalApplication),
      );
      state.loadingState = LoadingState.error;
      updateSafely([loadingStateId]);
      return;
    } catch (e) {
      log.error('getGallerysFailed'.tr, e.toString());
      snack('getGallerysFailed'.tr, e.toString(), isShort: true);
      updateSafely([loadingStateId]);
      return;
    }

    List<Gallery> gallerys = await postHandleNewGallerys(galleryPage.gallerys);

    state.gallerys = gallerys;
    state.totalCount = galleryPage.totalCount;
    state.prevGid = galleryPage.prevGid;
    state.nextGid = galleryPage.nextGid;
    state.favoriteSortOrder = galleryPage.favoriteSortOrder;
    state.galleryCollectionKey = Key(newUUID());

    state.seek = dateTime;

    if (state.nextGid == null && state.prevGid == null && state.gallerys.isEmpty) {
      state.loadingState = LoadingState.noData;
    } else if (state.nextGid == null) {
      state.loadingState = LoadingState.noMore;
    } else {
      state.loadingState = LoadingState.idle;
    }

    updateSafely();
  }

  Future<void> handleTapJumpButton() async {
    DateTime? dateTime = await showDatePicker(
      context: Get.context!,
      initialDate: state.seek,
      currentDate: DateTime.now(),
      firstDate: DateTime(2007),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (dateTime != null) {
      jumpPage(dateTime);
    }
  }

  Future<void> handleTapFilterButton([EHSearchConfigDialogType searchConfigDialogType = EHSearchConfigDialogType.filter]) async {
    await state.searchConfigInitCompleter.future;

    Map<String, dynamic>? result = await Get.dialog(
      EHSearchConfigDialog(searchConfig: state.searchConfig, type: searchConfigDialogType),
    );

    if (result == null) {
      return;
    }

    SearchConfig searchConfig = result['searchConfig'];
    state.searchConfig = searchConfig;

    /// No need to save at search page
    if (useSearchConfig) {
      await saveSearchConfig(searchConfig);
    }

    handleClearAndRefresh();
  }

  void handleTapGalleryCard(Gallery gallery) async {
    toRoute(
      Routes.details,
      arguments: DetailsPageArgument(galleryUrl: gallery.galleryUrl, gallery: gallery),
    );
  }

  void handleLongPressCard(BuildContext context, Gallery gallery) async {}

  void handleSecondaryTapCard(BuildContext context, Gallery gallery) async {}

  Future<GalleryPageInfo> getGalleryPage({String? prevGid, String? nextGid, DateTime? seek}) async {
    log.info('$runtimeType get data, prevGid:$prevGid, nextGid:$nextGid');

    await state.searchConfigInitCompleter.future;

    return ehRequest.requestGalleryPage(
      prevGid: prevGid,
      nextGid: nextGid,
      seek: seek,
      searchConfig: state.searchConfig,
      parser: EHSpiderParser.galleryPage2GalleryPageInfo,
    );
  }

  Future<void> saveSearchConfig(SearchConfig searchConfig) async {
    await localConfigService.write(
      configKey: ConfigEnum.searchConfig,
      subConfigKey: searchConfigKey,
      value: jsonEncode(searchConfig),
    );
  }

  Future<List<Gallery>> postHandleNewGallerys(List<Gallery> gallerys, {bool cleanDuplicate = true}) async {
    if (cleanDuplicate) {
      _cleanDuplicateGallery(gallerys);
    }

    await _translateGalleryTagsIfNeeded(gallerys);

    _preSortTagsForDisplay(gallerys);

    List<Gallery> filteredGallerys = await _filterByBlockingRules(gallerys);

    if (preferenceSetting.preloadGalleryCover.isTrue) {
      // Batch prefetch first 20 covers with controlled concurrency
      final covers = gallerys.take(20).map((g) => g.cover.url).toList();
      Future.wait(
        covers.map((url) => getNetworkImageData(url, useCache: true)),
      );
    }

    return filteredGallerys;
  }

  /// deal with the first and last page
  void _cleanDuplicateGallery(List<Gallery> newGallerys) {
    newGallerys.removeWhere((newGallery) => state.gallerys.firstWhereOrNull((e) => e.galleryUrl == newGallery.galleryUrl) != null);
  }

  Future<List<Gallery>> _filterByBlockingRules(List<Gallery> newGallerys) async {
    if (newGallerys.isEmpty) {
      return newGallerys;
    }

    // if all gallerys are filtered, we keep the first one to indicate it
    List<Gallery> filteredGallerys = await localBlockRuleService.executeRules(newGallerys);
    if (filteredGallerys.isNotEmpty) {
      return filteredGallerys;
    } else {
      return newGallerys.sublist(0, 1).map((g) => g..blockedByLocalRules = true).toList();
    }
  }

  Future<void> _translateGalleryTagsIfNeeded(List<Gallery> gallerys) async {
    await Future.wait(gallerys.map((gallery) {
      return tagTranslationService.translateTagsIfNeeded(gallery.tags);
    }).toList());
  }

  void _preSortTagsForDisplay(List<Gallery> gallerys) {
    for (Gallery gallery in gallerys) {
      List<GalleryTag> mergedList = [];
      gallery.tags.forEach((namespace, galleryTags) {
        mergedList.addAll(galleryTags);
      });
      mergedList.sort((a, b) {
        bool aWatched = a.backgroundColor != null;
        bool bWatched = b.backgroundColor != null;
        if (aWatched && !bWatched) {
          return -1;
        } else if (!aWatched && bWatched) {
          return 1;
        } else {
          return 0;
        }
      });
      gallery.sortedTagsForDisplay = mergedList;
    }
  }
}
