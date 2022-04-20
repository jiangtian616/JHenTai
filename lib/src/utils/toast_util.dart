import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

FToast _fToast = FToast();

void toast(
  BuildContext context,
  String msg, {
  bool isCenter = true,
  bool isShort = true,
}) {
  _fToast.init(context);

  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: Get.isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
    ),
    child: Text(msg, style: TextStyle(color: Get.isDarkMode ? Colors.black : Colors.white)),
  );

  _fToast.showToast(
    child: toast,
    toastDuration: Duration(seconds: isShort ? 1 : 2),
    positionedToastBuilder: (context, child) {
      return Positioned(
        bottom: 150.0,
        left: 24.0,
        right: 24.0,
        child: child,
      );
    },
  );
}
