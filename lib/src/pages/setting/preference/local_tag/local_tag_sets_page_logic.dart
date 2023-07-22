import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/mixin/animation_logic_mixin.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';

import '../../../../setting/my_tags_setting.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsLogic extends GetxController with GetTickerProviderStateMixin, AnimationLogicMixin {
  final String bodyId = 'bodyId';

  final LocalTagSetsState state = LocalTagSetsState();

  Future<void> handleDeleteLocalTag(int index) async {
    bool? success = await Get.dialog(
      EHDialog(
        title: 'delete'.tr + '?',
        content: '${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}',
      ),
    );

    if (success == true) {
      MyTagsSetting.removeLocalTagSetByIndex(index);
      updateSafely([bodyId]);
    }
  }
}
