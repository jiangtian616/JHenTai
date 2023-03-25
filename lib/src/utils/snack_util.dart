import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

void snack(
  String title,
  String message, {
  bool longDuration = false,
  SnackPosition? snackPosition,
  OnTap? onTap,
}) {
  Get.closeAllSnackbars();

  Get.snackbar(
    title,
    message,
    duration: Duration(milliseconds: longDuration ? 3000 : 1000),
    snackPosition: snackPosition,
    backgroundColor: UIConfig.snackBackGroundColor,
    colorText: UIConfig.snackTextColor,
    margin: GetPlatform.isDesktop ? const EdgeInsets.all(20) : null,
    onTap: onTap,
  );
}
