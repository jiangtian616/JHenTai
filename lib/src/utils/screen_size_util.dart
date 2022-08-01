import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double get fullScreenWidth => Get.width;

double get screenWidth => StyleSetting.isInMobileLayout
    ? Get.width
    : StyleSetting.isInTabletLayout
        ? Get.width / 2
        : (Get.width - GlobalConfig.desktopLeftTabBarWidth) / 2;

double get screenHeight => Get.height;
