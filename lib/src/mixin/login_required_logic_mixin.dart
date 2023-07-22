import 'package:get/get.dart';

import '../setting/user_setting.dart';
import '../utils/toast_util.dart';

mixin LoginRequiredMixin {
  bool checkLogin() {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return false;
    }

    return true;
  }

  showLoginToast() {
    toast('needLoginToOperate'.tr);
  }
}
