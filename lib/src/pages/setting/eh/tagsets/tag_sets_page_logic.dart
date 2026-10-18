import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../database/database.dart';
import '../../../../exception/eh_site_exception.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../model/tag_set.dart';
import '../../../../service/tag_translation_service.dart';
import '../../../../utils/color_util.dart';
import '../../../../service/log.dart';
import '../../../../utils/snack_util.dart';
import '../../../../widget/loading_state_indicator.dart';
import 'tag_sets_page_state.dart';

class TagSetsLogic extends GetxController with Scroll2TopLogicMixin {
  static const String titleId = 'titleId';
  static const String bodyId = 'bodyId';
  static const String loadingStateId = 'loadingStateId';
  static const String tagSetId = 'tagSetId';
  static const String tagId = 'tagId';
  static const String searchId = 'searchId';

  final TagSetsState state = TagSetsState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  void onInit() {
    super.onInit();
    getCurrentTagSet();
  }

  @override
  void onClose() {
    state.searchController.dispose();
    super.onClose();
  }

  List<WatchedTag> get filteredTags {
    if (state.searchKeyword.isEmpty) {
      return state.tags;
    }
    String keyword = state.searchKeyword.toLowerCase();
    return state.tags.where((tag) => _matchTag(tag, keyword)).toList();
  }

  /// Suggestions complete the keyword to a full tag name from the current tag set.
  List<WatchedTag> get autoCompleteSuggestions {
    if (state.searchKeyword.isEmpty) {
      return const [];
    }
    return filteredTags.take(8).toList();
  }

  bool _matchTag(WatchedTag tag, String keyword) {
    TagData tagData = tag.tagData;
    if ('${tagData.namespace}:${tagData.key}'.toLowerCase().contains(keyword)) {
      return true;
    }
    if (tagData.key.toLowerCase().contains(keyword)) {
      return true;
    }
    if (tagData.tagName?.toLowerCase().contains(keyword) ?? false) {
      return true;
    }
    return tagData.translatedNamespace?.toLowerCase().contains(keyword) ?? false;
  }

  void enterSearchMode() {
    state.searchMode = true;
    updateSafely([searchId]);
  }

  void exitSearchMode() {
    Get.focusScope?.unfocus();
    state.searchMode = false;
    state.searchKeyword = '';
    state.searchController.clear();
    updateSafely([searchId, bodyId]);
  }

  void updateSearchKeyword(String keyword) {
    state.searchKeyword = keyword;
    updateSafely([bodyId]);
  }

  void applySuggestion(WatchedTag tag) {
    Get.focusScope?.unfocus();
    String keyword = '${tag.tagData.namespace}:${tag.tagData.key}';
    state.searchController.text = keyword;
    updateSearchKeyword(keyword);
  }

  Future<void> getCurrentTagSet() async {
    state.tagSets.clear();
    state.tags.clear();
    state.loadingState = LoadingState.loading;
    updateSafely([tagSetId, bodyId]);

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await ehRequest.requestMyTagsPage(tagSetNo: state.currentTagSetNo, parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey);
    } on DioException catch (e) {
      log.error('getTagSetFailed'.tr, e.errorMsg);
      snack('getTagSetFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    } on EHSiteException catch (e) {
      log.error('getTagSetFailed'.tr, e.message);
      snack('getTagSetFailed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    } catch (e) {
      log.error('getTagSetFailed'.tr, e.toString());
      snack('getTagSetFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    }

    state.currentTagSetEnable = pageInfo.tagSetEnable;
    state.currentTagSetBackgroundColor = pageInfo.tagSetBackgroundColor;
    state.tagSets = pageInfo.tagSets;
    state.tags = pageInfo.tags;
    state.apikey = pageInfo.apikey;

    await _translateTagNamesIfNeeded();

    state.loadingState = LoadingState.success;
    updateSafely([titleId, tagSetId, bodyId]);
  }

  Future<void> handleUpdateTagSetColor(Color? newColor) async {
    if (newColor == state.currentTagSetBackgroundColor) {
      return;
    }

    state.tagSets.clear();
    state.tags.clear();
    state.loadingState = LoadingState.loading;
    updateSafely([tagSetId, bodyId]);

    try {
      await ehRequest.requestUpdateTagSet(
        tagSetNo: state.currentTagSetNo,
        enable: true,
        color: color2aRGBString(newColor),
      );
    } on DioException catch (e) {
      log.error('updateTagSetFailed'.tr, e.errorMsg);
      snack('updateTagSetFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    } on EHSiteException catch (e) {
      log.error('updateTagSetFailed'.tr, e.message);
      snack('updateTagSetFailed'.tr, e.message, isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    } catch (e) {
      log.error('updateTagSetFailed'.tr, e.toString());
      snack('updateTagSetFailed'.tr, e.toString(), isShort: true);
      state.loadingState = LoadingState.error;
      updateSafely([titleId, tagSetId, bodyId]);
      return;
    }

    getCurrentTagSet();
    
    myTagsSetting.refreshOnlineTagSets(state.currentTagSetNo);
  }

  /// Pack all edited fields (status / weight / color) into one API call.
  Future<void> handleUpdateTag(int tagSetIndex, WatchedTag newTag) async {
    WatchedTag oldTag = state.tags[tagSetIndex];
    if (newTag.watched == oldTag.watched && newTag.hidden == oldTag.hidden && newTag.weight == oldTag.weight && newTag.backgroundColor == oldTag.backgroundColor) {
      return;
    }

    await _updateTag(newTag);
  }

  Future<void> deleteTag(int tagSetIndex) async {
    WatchedTag tag = state.tags[tagSetIndex];
    log.info('Delete tag:$tag');

    state.updateTagState = LoadingState.loading;
    updateSafely(['$tagId::${tag.tagId}']);

    try {
      await ehRequest.requestDeleteWatchedTag(watchedTagId: state.tags[tagSetIndex].tagId, tagSetNo: state.currentTagSetNo);
    } on DioException catch (e) {
      log.error('deleteTagFailed'.tr, e.errorMsg);
      snack('deleteTagFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } on EHSiteException catch (e) {
      log.error('deleteTagFailed'.tr, e.message);
      snack('deleteTagFailed'.tr, e.message, isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } catch (e) {
      log.error('deleteTagFailed'.tr, e.toString());
      snack('deleteTagFailed'.tr, e.toString(), isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    }

    toast('${'deleteTagSuccess'.tr}: ${state.tags[tagSetIndex].tagData.namespace}:${state.tags[tagSetIndex].tagData.key}');
    state.tags.removeAt(tagSetIndex);

    state.updateTagState = LoadingState.idle;
    updateSafely([bodyId]);

    myTagsSetting.refreshOnlineTagSets(state.currentTagSetNo);
  }

  Future<void> _updateTag(WatchedTag tag) async {
    log.info('Update tag:$tag');

    state.updateTagState = LoadingState.loading;
    updateSafely(['$tagId::${tag.tagId}']);

    try {
      await ehRequest.requestUpdateWatchedTag(
        apiuid: userSetting.ipbMemberId.value!,
        apikey: state.apikey,
        tagId: tag.tagId,
        tagColor: color2aRGBString(tag.backgroundColor),
        tagWeight: tag.weight,
        watch: tag.watched,
        hidden: tag.hidden,
      );
    } on DioException catch (e) {
      log.error('updateTagFailed'.tr, e.errorMsg);
      snack('updateTagFailed'.tr, e.errorMsg ?? '', isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } on EHSiteException catch (e) {
      log.error('updateTagFailed'.tr, e.message);
      snack('updateTagFailed'.tr, e.message, isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } catch (e) {
      log.error('updateTagFailed'.tr, e.toString());
      snack('updateTagFailed'.tr, e.toString(), isShort: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    }

    int tagIndex = state.tags.indexWhere((element) => element.tagId == tag.tagId);
    state.tags[tagIndex] = tag;
    state.updateTagState = LoadingState.idle;

    toast('success'.tr);
    updateSafely(['$tagId::${tag.tagId}']);

    myTagsSetting.refreshOnlineTagSets(state.currentTagSetNo);
  }

  Future<void> _translateTagNamesIfNeeded() async {
    if (tagTranslationService.isReady) {
      for (WatchedTag tagSet in state.tags) {
        TagData? tagData = await tagTranslationService.getTagTranslation(tagSet.tagData.namespace, tagSet.tagData.key);
        if (tagData != null) {
          tagSet.tagData = tagData;
        }
      }
    }
  }
}
