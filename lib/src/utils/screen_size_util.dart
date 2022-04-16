import 'package:get/get.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double get fullScreenWidth => Get.width;

double get screenWidth => StyleSetting.currentEnableTabletLayout.isTrue ? Get.width / 2 : Get.width;

double get screenHeight => Get.height;
