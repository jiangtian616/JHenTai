import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';
import 'package:jhentai/src/utils/check_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:throttling/throttling.dart';

import '../../../model/gallery.dart';
import '../../../model/gallery_page.dart';
import '../../../network/eh_request.dart';
import '../../../service/quick_search_service.dart';
import '../../../setting/style_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/loading_state_indicator.dart';

mixin BaseSearchPageLogicMixin on BasePageLogic {
  @override
  BaseSearchPageStateMixin get state;

  final String suggestionBodyId = 'suggestionBodyId';
  final String galleryBodyId = 'galleryBodyId';
  final String searchFieldId = 'searchFieldId';

  final QuickSearchService quickSearchService = Get.find();

  Debouncing debouncing = Debouncing(duration: const Duration(milliseconds: 300));

  @override
  void onClose() {
    super.dispose();
    state.searchFieldFocusNode.dispose();
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
      result = await FilePicker.platform.pickFiles(type: FileType.image);
    } on Exception catch (e) {
      Log.error('Pick file failed', e);
    }

    if (result == null) {
      return;
    }

    Log.info('File search');

    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }

    state.gallerys.clear();
    state.prevGid = null;
    state.nextGid = null;
    state.totalCount = null;

    state.loadingState = LoadingState.loading;
    state.searchConfig.keyword = null;
    update();

    try {
      state.redirectUrl = await EHRequest.requestLookup(
        imagePath: result.files.first.path!,
        imageName: result.files.first.name,
        parser: EHSpiderParser.imageLookup2RedirectUrl,
      );
    } on DioError catch (e) {
      Log.error('fileSearchFailed'.tr, e.message);
      snack('fileSearchFailed'.tr, e.message);
      state.loadingState = LoadingState.idle;
      update([loadingStateId]);
      return;
    } on CheckException catch (_) {
      state.loadingState = LoadingState.idle;
      update([loadingStateId]);
      rethrow;
    }

    Log.info('Get redirect url success:${state.redirectUrl}');
    loadMore(checkLoadingState: false);
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags() async {
    if (state.searchConfig.keyword?.trim().isEmpty ?? true) {
      return;
    }

    /// only search after 300ms
    debouncing.debounce(searchTags);
  }

  Future<void> searchTags() async {
    Log.info('search for ${state.searchConfig.keyword}');

    String keyword = state.searchConfig.keyword!.split(' ').last.trim();
    if (keyword.isEmpty) {
      return;
    }

    /// chinese => database
    /// other => EH api
    if (StyleSetting.enableTagZHTranslation.isTrue && tagTranslationService.loadingState.value == LoadingState.success) {
      state.suggestions = await tagTranslationService.searchTags(keyword);
    } else {
      try {
        state.suggestions = await EHRequest.requestTagSuggestion(keyword, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
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

  List<String> getSearchHistory() {
    List history = storageService.read('searchHistory') ?? <String>[];
    return history.cast<String>();
  }

  @override
  Future<GalleryPageInfo> getGalleryPage({int? prevGid, int? nextGid}) {
    if (state.redirectUrl == null) {
      return super.getGalleryPage(prevGid: prevGid, nextGid: nextGid);
    }

    Log.info('Get gallerys data with file search, prevGid:$prevGid, nextGid:$nextGid');
    return EHRequest.requestGalleryPage(
      prevGid: prevGid,
      nextGid: nextGid,
      url: state.redirectUrl,
      parser: EHSpiderParser.galleryPage2GalleryPageInfo,
    );
  }

  void writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }

    String searchPhrase = state.searchConfig.computeKeywords();
    if (searchPhrase.isEmpty) {
      return;
    }

    List history = storageService.read('searchHistory') ?? <String>[];

    history.remove(searchPhrase);
    history.insert(0, searchPhrase);

    storageService.write('searchHistory', history);
  }

  Future<void> clearHistory() async {
    await storageService.remove('searchHistory');
    update([suggestionBodyId]);
  }

  @override
  void handleTapGalleryCard(Gallery gallery) async {
    state.searchFieldFocusNode.unfocus();
    super.handleTapGalleryCard(gallery);
  }

  /// double tap to clear tags
  void handleTapClearButton() {
    if (isEmptyOrNull(state.searchConfig.keyword)) {
      state.searchConfig.tags?.clear();
    } else {
      state.searchConfig.keyword = '';
    }
    update([searchFieldId]);
  }

  void toggleBodyType() {
    state.bodyType = (state.bodyType == SearchPageBodyType.gallerys ? SearchPageBodyType.suggestionAndHistory : SearchPageBodyType.gallerys);
    update();
  }

  void toggleHideSearchHistory() {
    state.hideSearchHistory = !state.hideSearchHistory;
    update([suggestionBodyId]);
  }
}
