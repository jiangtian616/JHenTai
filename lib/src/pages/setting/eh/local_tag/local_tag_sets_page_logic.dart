import 'package:get/get.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsLogic extends GetxController with Scroll2TopLogicMixin, GetTickerProviderStateMixin {
  @override
  final LocalTagSetsState state = LocalTagSetsState();

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
