import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/model/gallery_image_page_url.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/search_history.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/search/mixin/search_page_state_mixin.dart';
import 'package:jhentai/src/service/search_history_service.dart';
import 'package:jhentai/src/utils/check_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:throttling/throttling.dart';

import '../../../exception/eh_site_exception.dart';
import '../../../model/eh_raw_tag.dart';
import '../../../model/gallery.dart';
import '../../../model/gallery_page.dart';
import '../../../network/eh_request.dart';
import '../../../service/quick_search_service.dart';
import '../../../service/storage_service.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../service/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/eh_alert_dialog.dart';
import '../../../widget/loading_state_indicator.dart';

mixin SearchPageLogicMixin on BasePageLogic {
  @override
  SearchPageStateMixin get state;

  @override
  bool get autoLoadForFirstTime => false;

  @override
  bool get useSearchConfig => true;

  @override
  String get searchConfigKey => searchPageConfigKey;
  static const searchPageConfigKey = 'search';

  final String suggestionBodyId = 'suggestionBodyId';
  final String galleryBodyId = 'galleryBodyId';
  final String searchFieldId = 'searchFieldId';

  final QuickSearchService quickSearchService = Get.find();
  final SearchHistoryService searchHistoryService = Get.find();

  final Debouncing suggestDebouncing = Debouncing(duration: const Duration(milliseconds: 300));
  final Debouncing recordDebouncing = Debouncing(duration: const Duration(milliseconds: 1000));

  @override
  Future<void> onInit() async {
    await super.onInit();
    state.enableSearchHistoryTranslation = storageService.read(ConfigEnum.enableSearchHistoryTranslation.key) ?? state.enableSearchHistoryTranslation;
  }

  @override
  void onClose() {
    state.searchFieldFocusNode.dispose();
    suggestDebouncing.close();
    recordDebouncing.close();
  }

  @override
  Future<void> handleClearAndRefresh() async {
    state.searchFieldFocusNode.unfocus();

    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }
    state.redirectUrl = null;

    writeHistory();

    /// reset scroll offset
    state.pageStorageKey = PageStorageKey('$runtimeType::${Random().nextInt(9999999)}');

    return super.handleClearAndRefresh();
  }

  Future<void> handleFileSearch() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowCompression: false,
        compressionQuality: 0,
      );
    } on Exception catch (e) {
      log.error('Pick file failed', e);
      return;
    }

    if (result == null) {
      return;
    }

    log.info('File search');

    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }

    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.totalCount = null;
    state.favoriteSortOrder = null;

    state.loadingState = LoadingState.loading;
    await state.searchConfigInitCompleter.future;
    state.searchConfig.keyword = null;
    updateSafely();

    try {
      state.redirectUrl = await ehRequest.requestLookup(
        imagePath: result.files.first.path!,
        imageName: result.files.first.name,
        parser: EHSpiderParser.imageLookup2RedirectUrl,
      );
    } on DioException catch (e) {
      log.error('fileSearchFailed'.tr, e.errorMsg);
      snack('fileSearchFailed'.tr, e.errorMsg ?? '');
      state.hasSearched = false;
      state.loadingState = LoadingState.idle;
      updateSafely();
      return;
    } on EHSiteException catch (e) {
      log.error('fileSearchFailed'.tr, e.message);
      snack('fileSearchFailed'.tr, e.message);
      state.hasSearched = false;
      state.loadingState = LoadingState.idle;
      updateSafely();
      return;
    } on CheckException catch (_) {
      state.hasSearched = false;
      state.loadingState = LoadingState.idle;
      updateSafely();
      rethrow;
    }

    log.info('Get redirect url success:${state.redirectUrl}');
    loadMore(checkLoadingState: false);
  }

  Future<void> onInputChanged(String text) async {
    await state.searchConfigInitCompleter.future;
    state.searchConfig.keyword = text;

    GalleryUrl? galleryUrl = GalleryUrl.tryParse(text);
    if (galleryUrl != null) {
      state.inputGalleryUrl = galleryUrl;
      state.inputGalleryImagePageUrl = null;
      updateSafely([suggestionBodyId]);
      return;
    }

    GalleryImagePageUrl? galleryImagePageUrl = GalleryImagePageUrl.tryParse(text);
    if (galleryImagePageUrl != null) {
      state.inputGalleryUrl = null;
      state.inputGalleryImagePageUrl = galleryImagePageUrl;
      updateSafely([suggestionBodyId]);
      return;
    }

    state.inputGalleryUrl = null;
    state.inputGalleryImagePageUrl = null;
    waitAndSearchTags();
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags() async {
    if (state.searchConfig.keyword?.trim().isEmpty ?? true) {
      return;
    }

    /// only search after 300ms
    suggestDebouncing.debounce(searchTags);
  }

  Future<void> searchTags() async {
    String keyword = state.searchConfig.keyword!;
    if (keyword.isEmpty) {
      return;
    }

    log.info('search for ${state.searchConfig.keyword}');

    /// chinese => database; other => EH api
    if (tagTranslationService.isReady) {
      state.suggestions = await tagTranslationService.searchTags(keyword, limit: 100);
    } else {
      String lastPart = keyword.split(' ').last;
      try {
        List<EHRawTag> tags = await ehRequest.requestTagSuggestion(lastPart, EHSpiderParser.tagSuggestion2TagList);
        state.suggestions = tags
            .map((t) => (
                  searchText: keyword,
                  matchStart: keyword.length - lastPart.length,
                  matchEnd: keyword.length,
                  tagData: TagData(namespace: t.namespace, key: t.key),
                  score: 0.0,
                  namespaceMatch:
                      t.namespace.contains(lastPart) ? (start: t.namespace.indexOf(lastPart), end: t.namespace.indexOf(lastPart) + lastPart.length) : null,
                  translatedNamespaceMatch: null,
                  keyMatch: t.key.contains(lastPart) ? (start: t.key.indexOf(lastPart), end: t.key.indexOf(lastPart) + lastPart.length) : null,
                  tagNameMatch: null,
                ))
            .toList();
      } on DioException catch (e) {
        log.error('Request tag suggestion failed', e);
        state.suggestions = [];
      }
    }

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      updateSafely([suggestionBodyId]);
    }

    if (state.suggestions.isNotEmpty && !state.hideSearchHistory) {
      state.hideSearchHistory = true;
      updateSafely([suggestionBodyId]);
    }
  }

  @override
  Future<void> jumpPage(DateTime dateTime) async {
    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }
    state.hasSearched = true;
    super.jumpPage(dateTime);
  }

  @override
  Future<GalleryPageInfo> getGalleryPage({String? prevGid, String? nextGid, DateTime? seek}) {
    if (state.redirectUrl == null) {
      return super.getGalleryPage(prevGid: prevGid, nextGid: nextGid, seek: seek);
    }

    log.info('Get gallerys data with file search, prevGid:$prevGid, nextGid:$nextGid');
    return ehRequest.requestGalleryPage(
      prevGid: prevGid,
      nextGid: nextGid,
      seek: seek,
      url: state.redirectUrl,
      parser: EHSpiderParser.galleryPage2GalleryPageInfo,
    );
  }

  @override
  void handleTapGalleryCard(Gallery gallery) async {
    state.searchFieldFocusNode.unfocus();
    super.handleTapGalleryCard(gallery);
  }

  Future<void> handleTapClearButton() async {
    await state.searchConfigInitCompleter.future;

    if (isEmptyOrNull(state.searchConfig.keyword)) {
      state.searchConfig.tags?.clear();
    } else {
      state.searchConfig.keyword = '';
    }
    update([searchFieldId]);
  }

  void toggleDeleteSearchHistoryMode() {
    state.inDeleteSearchHistoryMode = !state.inDeleteSearchHistoryMode;
    update([suggestionBodyId]);

    if (state.inDeleteSearchHistoryMode) {
      toast('tapChip2Delete'.tr);
    }
  }

  Future<void> handleClearAllSearchHistories() async {
    bool? result = await Get.dialog(EHDialog(title: 'deleteAll'.tr + '?'));

    if (result == true) {
      await searchHistoryService.clearHistory();
      update([suggestionBodyId]);
    }
  }

  Future<void> handleDeleteSearchHistory(SearchHistory history) async {
    await searchHistoryService.deleteHistory(history);

    /// exit delete mode if there's no history
    if (searchHistoryService.histories.isEmpty) {
      state.inDeleteSearchHistoryMode = false;
    }
    update([suggestionBodyId]);
  }

  void writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }

    String searchPhrase = state.searchConfig.computeFullKeywords();
    if (searchPhrase.isEmpty) {
      return;
    }

    searchHistoryService.writeHistory(searchPhrase);
  }

  void toggleBodyType() {
    state.bodyType = (state.bodyType == SearchPageBodyType.gallerys ? SearchPageBodyType.suggestionAndHistory : SearchPageBodyType.gallerys);
    update();
  }

  void toggleHideSearchHistory() {
    state.hideSearchHistory = !state.hideSearchHistory;
    update([suggestionBodyId]);
  }

  void toggleEnableSearchHistoryTranslation() {
    state.enableSearchHistoryTranslation = !state.enableSearchHistoryTranslation;
    storageService.write(ConfigEnum.enableSearchHistoryTranslation.key, state.enableSearchHistoryTranslation);
    update([suggestionBodyId]);
  }
}
