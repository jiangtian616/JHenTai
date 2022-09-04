import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/base/base_page_logic.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';
import 'package:jhentai/src/service/check_service.dart';

import '../../../network/eh_request.dart';
import '../../../service/quick_search_service.dart';
import '../../../setting/style_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/loading_state_indicator.dart';

mixin BaseSearchPageLogic on BasePageLogic {
  @override
  BaseSearchPageState get state;

  String get searchFieldId;
  String get suggestionBodyId;
  String get galleryBodyId;

  @override
  bool showScroll2TopButton = false;

  final QuickSearchService quickSearchService = Get.find();

  /// used for delayed search suggestion
  Timer? timer;
  static const Duration searchDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    state.searchFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Future<void> clearAndRefresh() async {
    state.hasSearched = true;

    if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
      toggleBodyType();
    }
    state.redirectUrl = null;

    _writeHistory();

    /// Reset scroll offset
    state.pageStorageKey = PageStorageKey('$runtimeType::${Random().nextInt(9999999)}');

    return super.clearAndRefresh();
  }

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.debug('Get gallerys info at page: $pageIndex');

    List<dynamic> gallerysAndPageInfo;
    if (state.redirectUrl == null) {
      gallerysAndPageInfo = await EHRequest.requestGalleryPage(
        pageNo: pageIndex,
        searchConfig: state.searchConfig,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    } else {
      gallerysAndPageInfo = await EHRequest.requestGalleryPage(
        url: state.redirectUrl,
        pageNo: pageIndex,
        parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
      );
    }

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
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

    Log.info('File search', false);

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
    update([pageId]);

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
    timer?.cancel();

    if (state.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }
    timer = Timer(searchDelay, searchTags);
  }

  Future<void> searchTags() async {
    Log.info('search for ${state.searchConfig.keyword}', false);

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

  void _writeHistory() {
    /// do not record file search
    if (state.redirectUrl != null) {
      return;
    }

    if (state.searchConfig.keyword?.isEmpty ?? true) {
      return;
    }

    List history = storageService.read('searchHistory') ?? <String>[];
    history.remove(state.searchConfig.keyword);
    history.insert(0, state.searchConfig.keyword);
    storageService.write('searchHistory', history);
  }

  void clearHistory() {
    storageService.remove('searchHistory').then((_) {
      if (state.bodyType == SearchPageBodyType.suggestionAndHistory) {
        update([pageId]);
      }
    });
  }

  void toggleBodyType() {
    state.bodyType = (state.bodyType == SearchPageBodyType.gallerys ? SearchPageBodyType.suggestionAndHistory : SearchPageBodyType.gallerys);
    showScroll2TopButton = state.bodyType == SearchPageBodyType.gallerys;
    update([pageId]);
  }

  void updateGalleryBody() {
    update([galleryBodyId]);
  }
}
