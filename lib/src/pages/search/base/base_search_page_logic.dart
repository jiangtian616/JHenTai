import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';
import 'package:jhentai/src/utils/check_util.dart';
import 'package:throttling/throttling.dart';

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
  Future<void> clearAndRefresh() async {
    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }
    state.redirectUrl = null;

    writeHistory();

    /// reset scroll offset
    state.pageStorageKey = PageStorageKey('$runtimeType::${Random().nextInt(9999999)}');

    return super.clearAndRefresh();
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
    state.prevPageIndexToLoad = null;
    state.nextPageIndexToLoad = 0;
    state.pageCount = -1;

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
    if (state.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }

    /// only search after 300ms
    debouncing.debounce(searchTags);
  }

  Future<void> searchTags() async {
    Log.info('search for ${state.searchConfig.keyword}');

    /// chinese => database
    /// other => EH api
    if (StyleSetting.enableTagZHTranslation.isTrue && tagTranslationService.loadingState.value == LoadingState.success) {
      state.suggestions = await tagTranslationService.searchTags(state.searchConfig.keyword!);
    } else {
      try {
        state.suggestions = await EHRequest.requestTagSuggestion(state.searchConfig.keyword!, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
      }
    }

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      update([suggestionBodyId]);
    }
  }

  List<String> getSearchHistory() {
    List history = storageService.read('searchHistory') ?? <String>[];
    return history.cast<String>();
  }

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.debug('Get gallerys info at page: $pageIndex');

    if (state.redirectUrl == null) {
      return await EHRequest.requestGalleryPage(
        pageNo: pageIndex,
        searchConfig: state.searchConfig,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    }

    return await EHRequest.requestGalleryPage(
      url: state.redirectUrl,
      pageNo: pageIndex,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );
  }

  void writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }

    String searchPhrase = state.searchConfig.toTagKeywords(withTranslation: false, separator: ' ');
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

  void toggleBodyType() {
    state.bodyType = (state.bodyType == SearchPageBodyType.gallerys ? SearchPageBodyType.suggestionAndHistory : SearchPageBodyType.gallerys);
    update();
  }

  void updateGalleryBody() {
    update([galleryBodyId]);
  }
}
