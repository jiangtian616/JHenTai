import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

FToast _fToast = FToast();

void initToast(BuildContext context) {
  _fToast.init(context);
}

void toast(String msg, {bool isCenter = true, bool isShort = true}) {
  if (_fToast.context == null) {
    return;
  }

  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: Get.isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.9),
    ),
    child: Text(msg, style: TextStyle(color: Get.isDarkMode ? Colors.black : Colors.white)),
  );

  _fToast.removeCustomToast();
  _fToast.showToast(
    child: toast,
    toastDuration: Duration(seconds: isShort ? 1 : 2),
    positionedToastBuilder: (context, child) {
      if (isCenter) {
        return Positioned(
          top: 50,
          bottom: 50,
          left: 24,
          right: 24,
          child: child,
        );
      }
      return Positioned(
        bottom: 150.0,
        left: 24.0,
        right: 24.0,
        child: child,
      );
    },
  );
}
