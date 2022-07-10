import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double get fullScreenWidth => Get.width;

double get screenWidth => StyleSetting.inTabletOrDesktopLayoutMode.isFalse
    ? Get.width
    : StyleSetting.layoutMode.value == LayoutMode.tablet
        ? Get.width / 2
        : (Get.width - GlobalConfig.desktopLeftTabBarWidth) / 2;

double get screenHeight => Get.height;
