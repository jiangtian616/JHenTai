import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/animation_logic_mixin.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../network/eh_request.dart';
import '../../../../service/tag_translation_service.dart';
import '../../../../setting/my_tags_setting.dart';
import '../../../../utils/eh_spider_parser.dart';
import '../../../../utils/log.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsLogic extends GetxController with GetTickerProviderStateMixin, AnimationLogicMixin {
  final String bodyId = 'bodyId';
  final String searchFieldId = 'searchFieldId';
  final String tagsId = 'tagsId';
  final String tagId = 'tagsId';
  final String searchLoadingStateId = 'searchLoadingStateId';

  final LocalTagSetsState state = LocalTagSetsState();

  final TagTranslationService tagTranslationService = Get.find();


  void waitAndSearchTags() {
    if (isEmptyOrNull(state.keyword)) {
      return;
    }
    state.searchDebouncing.debounce(searchTags);
  }

  Future<void> searchTags() async {
    if (isEmptyOrNull(state.keyword)) {
      return;
    }

    Log.info('search for ${state.keyword}');

    state.searchLoadingState = LoadingState.loading;
    updateSafely([searchLoadingStateId]);

    if (tagTranslationService.isReady) {
      state.tags = await tagTranslationService.searchTags(state.keyword!);
    } else {
      try {
        state.tags = await EHRequest.requestTagSuggestion(state.keyword!, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
        state.searchLoadingState = LoadingState.error;
        updateSafely([searchLoadingStateId]);
        return;
      }
    }

    if (state.tags.isEmpty) {
      state.searchLoadingState = LoadingState.noData;
    } else {
      state.searchLoadingState = LoadingState.success;
    }

    updateSafely([searchLoadingStateId, tagsId]);
  }

  Future<void> handleDeleteLocalTag(int index) async {
    bool? success = await Get.dialog(EHAlertDialog(title: 'delete'.tr + '?'));

    if (success == true) {
      MyTagsSetting.removeLocalTagSetByIndex(index);
      updateSafely([bodyId]);
    }
  }

  void toggleLocalTag(TagData tag) {
    if (hasBeenAdded(tag)) {
      deleteLocalTag(tag);
    } else {
      addLocalTag(tag);
    }
  }

  void addLocalTag(TagData tag) {
    MyTagsSetting.addLocalTagSet(tag);
    updateSafely(['$tagId::${tag.namespace}::${tag.key}']);
  }

  void deleteLocalTag(TagData tag) {
    MyTagsSetting.removeLocalTagSet(tag);
    updateSafely(['$tagId::${tag.namespace}::${tag.key}']);
  }

  bool hasBeenAdded(TagData tag) {
    return MyTagsSetting.localTagSets.any((element) => element.namespace == tag.namespace && element.key == tag.key);
  }
}
