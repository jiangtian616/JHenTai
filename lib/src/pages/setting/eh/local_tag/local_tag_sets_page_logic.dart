import 'package:get/get.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsLogic extends GetxController with Scroll2TopLogicMixin, GetTickerProviderStateMixin {
  final LocalTagSetsState state = LocalTagSetsState();

  @override
  Scroll2TopStateMixin get scroll2TopState => state;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    state.controller.dispose();
    super.onClose();
  }
}
