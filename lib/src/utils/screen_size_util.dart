import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double get fullScreenWidth => Get.width;

double get screenWidth => styleSetting.isInMobileLayout
    ? Get.width
    : styleSetting.isInTabletLayout
        ? Get.width / 2
        : (Get.width - UIConfig.desktopLeftTabBarWidth) / 2;

double get screenHeight => Get.height;
