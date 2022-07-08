import 'package:flutter/material.dart';
import 'package:get/get.dart';

void snack(
  String title,
  String message, {
  bool longDuration = false,
  SnackPosition? snackPosition,
  bool dense = false,
  double maxWidth = 200,
  bool closeBefore = false,
  OnTap? onTap,
}) {
  if (closeBefore) {
    Get.closeAllSnackbars();
  }
  Get.snackbar(
    title,
    message,
    duration: Duration(milliseconds: longDuration ? 3000 : 1000),
    snackPosition: snackPosition,
    maxWidth: dense ? maxWidth : null,
    backgroundColor: Colors.black.withOpacity(0.7),
    colorText: Colors.white70,
    margin: GetPlatform.isWindows ? const EdgeInsets.all(20) : null,
    onTap: onTap,
  );
}
