import 'package:get/get.dart';

import '../utils/snack_util.dart';
import '../utils/toast_util.dart';

mixin LoginRequiredMixin {
  showLoginToast() {
    toast('needLoginToOperate'.tr);
  }
}
