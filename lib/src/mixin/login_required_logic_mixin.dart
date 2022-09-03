import 'package:get/get.dart';

import '../utils/snack_util.dart';

mixin LoginRequiredLogicMixin on GetxController {
  void showLoginSnack() {
    snack('operationFailed'.tr, 'needLoginToOperate'.tr);
  }
}
