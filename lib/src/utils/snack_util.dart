import 'package:flutter/material.dart';
import 'package:get/get.dart';

void snack(
  String title,
  String message, {
  bool longDuration = false,
  SnackPosition? snackPosition,
  bool dense = false,
  double maxWidth = 200,
}) {
  Get.snackbar(
    title,
    message,
    duration: Duration(milliseconds: longDuration ? 3000 : 1000),
    snackPosition: snackPosition,
    maxWidth: dense ? maxWidth : null,
    backgroundColor: Colors.black.withOpacity(0.7),
    colorText: Colors.white70,
  );
}
