import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

import '../../../../model/tag_set.dart';
import '../../../../utils/color_util.dart';
import '../../../../utils/log.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/snack_util.dart';
import '../../../../widget/loading_state_indicator.dart';
import 'tag_sets_state.dart';

const String titleId = 'titleId';
const String bodyId = 'bodyId';
const String loadingStateId = 'loadingStateId';
const String updateWatchedStateId = 'updateWatchedStateId';
const String updateHiddenStateId = 'updateHiddenStateId';
const String updateWeightStateId = 'updateWeightStateId';
const String deleteStateId = 'deleteStateId';

class TagSetsLogic extends GetxController {
  final TagSetsState state = TagSetsState();

  @override
  void onInit() {
    getTagSet();
    super.onInit();
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
      update([loadingStateId]);
      return;
    }

    state.tagSetNames = map['tagSetNames'];
    state.tagSets = map['tagSets'];
    state.apikey = map['apikey'];
    state.loadingState = LoadingState.idle;
    update([titleId, bodyId]);
  }

  Future<void> updateTagSet(TagSet tag, String updateId) async {
    Log.info('Update tag:$tag');

    state.updateTagState = LoadingState.loading;
    update(['$updateId-${tag.tagId}']);

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
      update(['$updateId-${tag.tagId}']);
      return;
    }

    int tagIndex = state.tagSets.indexWhere((element) => element.tagId == tag.tagId);
    state.tagSets[tagIndex] = tag;
    state.updateTagState = LoadingState.idle;
    update([
      '$updateWatchedStateId-${tag.tagId}',
      '$updateHiddenStateId-${tag.tagId}',
      '$updateWeightStateId-${tag.tagId}',
    ]);
  }

  Future<void> deleteTagSet(int tagSetIndex) async {
    Log.info('Delete tag:$tagSetIndex');

    state.deleteTagState = LoadingState.loading;
    update(['$deleteStateId-$tagSetIndex']);

    try {
      await EHRequest.requestDeleteTagSet(tagSetId: state.tagSets[tagSetIndex].tagId);
    } on DioError catch (e) {
      Log.error('deleteTagSetFailed'.tr, e.message);
      snack('deleteTagSetFailed'.tr, e.message, longDuration: true);
      state.deleteTagState = LoadingState.error;
      update(['$deleteStateId-$tagSetIndex']);
      return;
    }

    snack(
      'deleteTagSetSuccess'.tr,
      '${state.tagSets[tagSetIndex].tagData.namespace}:${state.tagSets[tagSetIndex].tagData.key}',
      longDuration: false,
    );
    state.tagSets.removeAt(tagSetIndex);
    state.deleteTagState = LoadingState.idle;
    update([bodyId]);
  }

  Future<void> handleTapWatchButton(int tagSetIndex) async {
    TagSet tagSet = state.tagSets[tagSetIndex].copyWith();

    tagSet.watched = !tagSet.watched;
    if (tagSet.watched) {
      tagSet.hidden = false;
    }

    updateTagSet(tagSet, updateWatchedStateId);
  }

  Future<void> handleTapHiddenButton(int tagSetIndex) async {
    TagSet tagSet = state.tagSets[tagSetIndex].copyWith();

    tagSet.hidden = !tagSet.hidden;
    if (tagSet.hidden) {
      tagSet.watched = false;
    }

    updateTagSet(tagSet, updateHiddenStateId);
  }

  Future<void> handleUpdateWeight(int tagSetIndex, String value) async {
    int? newValue = int.tryParse(value);
    if (newValue == null || newValue == state.tagSets[tagSetIndex].weight) {
      return;
    }

    TagSet tagSet = state.tagSets[tagSetIndex].copyWith(weight: newValue);
    updateTagSet(tagSet, updateWeightStateId);
  }

  Future<void> showDeleteBottomSheet(int index) async {
    showCupertinoModalPopup(
      context: Get.context!,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text(
              '${'delete'.tr} ${state.tagSets[index].tagData.namespace}:${state.tagSets[index].tagData.key}',
              style: TextStyle(color: Colors.red.shade400),
            ),
            onPressed: () async {
              deleteTagSet(index);
              backRoute();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('cancel'.tr),
          onPressed: () => backRoute(),
        ),
      ),
    );
  }
}
