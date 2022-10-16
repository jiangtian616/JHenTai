import 'package:get/get.dart';

import '../utils/toast_util.dart';

mixin LoginRequiredMixin {
  showLoginToast() {
    toast('needLoginToOperate'.tr);
  }
}
