import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double get fullScreenWidth => Get.width;

double get _desktopLeftRailWidth => GetPlatform.isMacOS && ThemeConfig.isApple
    ? UIConfig.desktopMacOSLeftTabBarWidth
    : UIConfig.desktopLeftTabBarWidth;

double get screenWidth => styleSetting.isInMobileLayout
    ? Get.width
    : styleSetting.isInTabletLayout
        ? Get.width / 2
        : (Get.width - _desktopLeftRailWidth) / 2;

double get screenHeight => Get.height;
