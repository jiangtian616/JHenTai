import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/style_setting.dart';

import '../config/ui_config.dart';

void snack(
  String title,
  String message, {
  bool longDuration = false,
  VoidCallback? onPressed,
}) {
  if (StyleSetting.isInMobileLayout) {
    ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            if (onPressed != null) {
              onPressed();
              ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18)),
              Text(message, style: const TextStyle(fontSize: 12)).marginOnly(top: 6),
            ],
          ),
        ),
        showCloseIcon: onPressed == null,
        action: onPressed == null ? null : SnackBarAction(label: '->', onPressed: onPressed),
        duration: Duration(milliseconds: longDuration ? 3000 : 1000),
      ),
    );
  } else {
    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(milliseconds: longDuration ? 3000 : 1000),
      backgroundColor: UIConfig.snackBackGroundColor,
      colorText: UIConfig.snackTextColor,
      margin: GetPlatform.isDesktop ? const EdgeInsets.all(20) : null,
      onTap: (_) => onPressed?.call(),
    );
  }
}
