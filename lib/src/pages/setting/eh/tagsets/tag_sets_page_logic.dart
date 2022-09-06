import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_logic_mixin.dart';
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

  @override
  final TagSetsState state = TagSetsState();

  final TagTranslationService tagTranslationService = Get.find<TagTranslationService>();

  @override
  void onInit() {
    super.onInit();
    getTagSet();
  }

  Future<void> getTagSet() async {
    state.tagSets.clear();
    state.loadingState = LoadingState.loading;
    update([bodyId]);

    Map<String, dynamic> map;
    try {
      map = await EHRequest.requestMyTagsPage(
        tagSetNo: state.currentTagSetIndex + 1,
        parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey,
      );
    } on DioError catch (e) {
      Log.error('getTagSetFailed'.tr, e.message);
      snack('getTagSetFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.loadingState = LoadingState.error;
      update([bodyId]);
      return;
    }

    state.tagSetNames = map['tagSetNames'];
    state.tagSets = map['tagSets'];
    state.apikey = map['apikey'];

    await _translateTagSetNamesIfNeeded();

    state.loadingState = LoadingState.success;
    update([titleId, bodyId]);
  }

  Future<void> handleUpdateWeight(int tagSetIndex, String value) async {
    int? newValue = int.tryParse(value);
    if (newValue == null || newValue == state.tagSets[tagSetIndex].weight) {
      return;
    }

    TagSet tagSet = state.tagSets[tagSetIndex].copyWith(weight: newValue);
    _updateTagSet(tagSet);
  }

  Future<void> handleUpdateStatus(int tagSetIndex, TagSetStatus newStatus) async {
    TagSetStatus oldStatus = state.tagSets[tagSetIndex].watched
        ? TagSetStatus.watched
        : state.tagSets[tagSetIndex].hidden
            ? TagSetStatus.hidden
            : TagSetStatus.nope;

    if (newStatus == oldStatus) {
      return;
    }

    TagSet tagSet = state.tagSets[tagSetIndex].copyWith(
      watched: newStatus == TagSetStatus.watched,
      hidden: newStatus == TagSetStatus.hidden,
    );

    _updateTagSet(tagSet);
  }

  Future<void> showBottomSheet(int index, BuildContext context) async {
    Get.focusScope?.unfocus();

    showModalBottomSheet(
      context: Get.context!,
      builder: (_) => BottomSheet(
        onClosing: () {},
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.favorite, color: GlobalConfig.tagSetsPageIconColor),
                title: Text('favorite'.tr),
                onTap: () {
                  backRoute();
                  handleUpdateStatus(index, TagSetStatus.watched);
                },
              ),
              ListTile(
                leading: Icon(Icons.not_interested, color: GlobalConfig.tagSetsPageIconColor),
                title: Text('hidden'.tr),
                onTap: () {
                  backRoute();
                  handleUpdateStatus(index, TagSetStatus.hidden);
                },
              ),
              ListTile(
                leading: Icon(Icons.question_mark, color: GlobalConfig.tagSetsPageIconColor),
                title: Text('nope'.tr),
                onTap: () {
                  backRoute();
                  handleUpdateStatus(index, TagSetStatus.nope);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Get.theme.colorScheme.error),
                title: Text('delete'.tr),
                onTap: () {
                  backRoute();
                  deleteTagSet(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTagSet(TagSet tag) async {
    Log.info('Update tag:$tag');

    state.updateTagState = LoadingState.loading;
    update(['$tagId::${tag.tagId}']);

    try {
      await EHRequest.requestUpdateTagSet(
        apiuid: UserSetting.ipbMemberId.value!,
        apikey: state.apikey,
        tagId: tag.tagId,
        tagColor: color2aRGBString(tag.color),
        tagWeight: tag.weight,
        watch: tag.watched,
        hidden: tag.hidden,
      );
    } on DioError catch (e) {
      Log.error('updateTagSetFailed'.tr, e.message);
      snack('updateTagSetFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      state.updateTagState = LoadingState.error;
      update(['$tagId::${tag.tagId}']);
      return;
    }

    int tagIndex = state.tagSets.indexWhere((element) => element.tagId == tag.tagId);
    state.tagSets[tagIndex] = tag;
    state.updateTagState = LoadingState.idle;

    toast('success'.tr);
    update(['$tagId::${tag.tagId}']);
  }

  Future<void> deleteTagSet(int tagSetIndex) async {
    TagSet tag = state.tagSets[tagSetIndex];
    Log.info('Delete tag:$tag');

    state.updateTagState = LoadingState.loading;
    update(['$tagId::${tag.tagId}']);

    try {
      await EHRequest.requestDeleteTagSet(tagSetId: state.tagSets[tagSetIndex].tagId);
    } on DioError catch (e) {
      Log.error('deleteTagSetFailed'.tr, e.message);
      snack('deleteTagSetFailed'.tr, e.message, longDuration: true);
      state.updateTagState = LoadingState.error;
      update(['$tagId::${tag.tagId}']);
      return;
    }

    toast('${'deleteTagSetSuccess'.tr}: ${state.tagSets[tagSetIndex].tagData.namespace}:${state.tagSets[tagSetIndex].tagData.key}');
    state.tagSets.removeAt(tagSetIndex);

    state.updateTagState = LoadingState.idle;
    update([bodyId]);
  }

  Future<void> _translateTagSetNamesIfNeeded() async {
    if (StyleSetting.enableTagZHTranslation.isTrue && tagTranslationService.loadingState.value == LoadingState.success) {
      for (TagSet tagSet in state.tagSets) {
        TagData? tagData = await tagTranslationService.getTagTranslation(tagSet.tagData.namespace, tagSet.tagData.key);
        if (tagData != null) {
          tagSet.tagData = tagData;
        }
      }
    }
  }
}
