import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

extension GetLogicExtension on GetxController {
  void updateSafely([List<Object>? ids, bool condition = true]) {
    update(ids, condition && !isClosed);
  }

  void updateSafelyInNextFrame([List<Object>? ids, bool condition = true]) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      update(ids, condition && !isClosed);
    });
  }
}
