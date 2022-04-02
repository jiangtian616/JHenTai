import 'package:get/get.dart';
import 'package:jhentai/src/setting/style_setting.dart';

double fullScreenWidth = Get.width;

double screenWidth = StyleSetting.enableTabletLayout.isTrue ? Get.width / 2 : Get.width;

double screenHeight = Get.height;
