import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page.dart';
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
import '../../../../utils/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
import '../../../../widget/loading_state_indicator.dart';
import 'tag_sets_page_state.dart';

class TagSetsLogic extends GetxController with Scroll2TopLogicMixin {
  static const String titleId = 'titleId';
  static const String bodyId = 'bodyId';
  static const String loadingStateId = 'loadingStateId';
  static const String tagId = 'tagId';

  final TagSetsState state = TagSetsState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  final TagTranslationService tagTranslationService = Get.find<TagTranslationService>();

  @override
  void onInit() {
    super.onInit();
    getTagSet();
  }

  Future<void> getTagSet() async {
    state.tags.clear();
    state.loadingState = LoadingState.loading;
    updateSafely([bodyId]);
    ({List<({int number, String name})> tagSets, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await EHRequest.requestMyTagsPage(
        tagSetNo: state.currentTagSetNo,
        parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey,
      );
    } on DioException catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      snack('getTagSetFailed'.tr, e.message ?? '', longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([bodyId]);
      return;
    } on EHSiteException catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      snack('getTagSetFailed'.tr, e.message, longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([bodyId]);
      return;
    } catch (e) {
      Log.error('getTagSetFailed'.tr, e.toString());
      snack('getTagSetFailed'.tr, e.toString(), longDuration: true);
      state.loadingState = LoadingState.error;
      updateSafely([bodyId]);
      return;
    }

    state.tagSets = pageInfo.tagSets;
    state.tags = pageInfo.tags;
    state.apikey = pageInfo.apikey;

    await _translateTagSetNamesIfNeeded();

    state.loadingState = LoadingState.success;
    updateSafely([titleId, bodyId]);
  }

  Future<void> handleUpdateColor(int tagSetIndex, Color? newColor) async {
    if (newColor == state.tags[tagSetIndex].backgroundColor) {
      return;
    }

    WatchedTag tagSet = state.tags[tagSetIndex].copyWith();
    tagSet.backgroundColor = newColor;
    _updateTagSet(tagSet);
  }

  Future<void> handleUpdateWeight(int tagSetIndex, String value) async {
    int? newValue = int.tryParse(value);
    if (newValue == null || newValue == state.tags[tagSetIndex].weight) {
      return;
    }

    WatchedTag tagSet = state.tags[tagSetIndex].copyWith(weight: newValue);
    _updateTagSet(tagSet);
  }

  Future<void> handleUpdateStatus(int tagSetIndex, TagSetStatus newStatus) async {
    TagSetStatus oldStatus = state.tags[tagSetIndex].watched
        ? TagSetStatus.watched
        : state.tags[tagSetIndex].hidden
            ? TagSetStatus.hidden
            : TagSetStatus.nope;

    if (newStatus == oldStatus) {
      return;
    }

    WatchedTag tagSet = state.tags[tagSetIndex].copyWith(
      watched: newStatus == TagSetStatus.watched,
      hidden: newStatus == TagSetStatus.hidden,
    );

    _updateTagSet(tagSet);
  }

  Future<void> showBottomSheet(int index, BuildContext context) async {
    Get.focusScope?.unfocus();

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: UIConfig.tagSetsPageIconDefaultColor(context)).marginOnly(right: 4),
                SizedBox(width: 56, child: Text('favorite'.tr)),
              ],
            ),
            onPressed: () {
              backRoute();
              handleUpdateStatus(index, TagSetStatus.watched);
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.not_interested, color: UIConfig.tagSetsPageIconDefaultColor(context)).marginOnly(right: 4),
                SizedBox(width: 56, child: Text('hidden'.tr)),
              ],
            ),
            onPressed: () {
              backRoute();
              handleUpdateStatus(index, TagSetStatus.hidden);
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.question_mark, color: UIConfig.tagSetsPageIconDefaultColor(context)),
                SizedBox(width: 56, child: Text('nope'.tr)),
              ],
            ),
            onPressed: () {
              backRoute();
              handleUpdateStatus(index, TagSetStatus.nope);
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, color: UIConfig.alertColor(context)),
                SizedBox(width: 56, child: Text('delete'.tr)),
              ],
            ),
            onPressed: () {
              backRoute();
              deleteTagSet(index);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }

  Future<void> _updateTagSet(WatchedTag tag) async {
    Log.info('Update tag:$tag');

    state.updateTagState = LoadingState.loading;
    updateSafely(['$tagId::${tag.tagId}']);

    try {
      await EHRequest.requestUpdateTagSet(
        apiuid: UserSetting.ipbMemberId.value!,
        apikey: state.apikey,
        tagId: tag.tagId,
        tagColor: color2aRGBString(tag.backgroundColor),
        tagWeight: tag.weight,
        watch: tag.watched,
        hidden: tag.hidden,
      );
    } on DioException catch (e) {
      Log.error('updateTagSetFailed'.tr, e.message);
      snack('updateTagSetFailed'.tr, e.message ?? '', longDuration: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } on EHSiteException catch (e) {
      Log.error('updateTagSetFailed'.tr, e.message);
      snack('updateTagSetFailed'.tr, e.message, longDuration: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    }

    int tagIndex = state.tags.indexWhere((element) => element.tagId == tag.tagId);
    state.tags[tagIndex] = tag;
    state.updateTagState = LoadingState.idle;

    toast('success'.tr);
    updateSafely(['$tagId::${tag.tagId}']);
  }

  Future<void> deleteTagSet(int tagSetIndex) async {
    WatchedTag tag = state.tags[tagSetIndex];
    Log.info('Delete tag:$tag');

    state.updateTagState = LoadingState.loading;
    updateSafely(['$tagId::${tag.tagId}']);

    try {
      await EHRequest.requestDeleteTagSet(watchedTagId: state.tags[tagSetIndex].tagId, tagSetNo: state.currentTagSetNo);
    } on DioException catch (e) {
      Log.error('deleteTagSetFailed'.tr, e.message);
      snack('deleteTagSetFailed'.tr, e.message ?? '', longDuration: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    } on EHSiteException catch (e) {
      Log.error('deleteTagSetFailed'.tr, e.message);
      snack('deleteTagSetFailed'.tr, e.message, longDuration: true);
      state.updateTagState = LoadingState.error;
      updateSafely(['$tagId::${tag.tagId}']);
      return;
    }

    toast('${'deleteTagSetSuccess'.tr}: ${state.tags[tagSetIndex].tagData.namespace}:${state.tags[tagSetIndex].tagData.key}');
    state.tags.removeAt(tagSetIndex);

    state.updateTagState = LoadingState.idle;
    updateSafely([bodyId]);
  }

  Future<void> _translateTagSetNamesIfNeeded() async {
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
