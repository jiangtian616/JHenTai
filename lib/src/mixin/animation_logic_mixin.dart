import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Copied from [AnimationMixin]
mixin AnimationLogicMixin on GetTickerProviderStateMixin  {
  final _controllerInstances = <AnimationController>[];

  AnimationController createController({bool unbounded = false, int? fps, String? updateId}) {
    final instance = _newAnimationController(unbounded: unbounded, fps: fps, updateId: updateId);
    _controllerInstances.add(instance);
    return instance;
  }

  AnimationController _newAnimationController({bool unbounded = false, int? fps, String? updateId}) {
    var controller = _instanceController(unbounded: unbounded);

    if (fps == null) {
      if (updateId == null) {
        controller.addListener(update);
      } else {
        controller.addListener(() => update([updateId]));
      }
    } else {
      _addFrameLimitingUpdater(controller, fps,updateId);
    }

    return controller;
  }

  void _addFrameLimitingUpdater(AnimationController controller, int fps, String? updateId) {
    var lastUpdateEmitted = DateTime(1970);
    final frameTimeMs = (1000 / fps).floor();

    controller.addListener(() {
      final now = DateTime.now();
      if (lastUpdateEmitted.isBefore(now.subtract(Duration(milliseconds: frameTimeMs)))) {
        lastUpdateEmitted = DateTime.now();
        updateId == null ? update() : update([updateId]);
      }
    });
  }

  AnimationController _instanceController({required bool unbounded}) {
    if (!unbounded) {
      return AnimationController(vsync: this, duration: const Duration(seconds: 1));
    } else {
      return AnimationController.unbounded(vsync: this, duration: const Duration(seconds: 1));
    }
  }

  @override
  void onClose() {
    super.onClose();
    for (var instance in _controllerInstances) {
      instance.dispose();
    }
  }
}
