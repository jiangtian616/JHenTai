import 'dart:async';

import 'package:flutter/material.dart';

class SpeedComputer {
  Timer? timer;

  String speed = '0 B/s';

  int downloadedBytesLastTime = 0;
  int downloadedBytes = 0;

  VoidCallback? updateCallback;

  SpeedComputer({this.updateCallback});

  bool isActive() {
    return timer?.isActive ?? false;
  }

  void start() {
    if (isActive()) {
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) => computeAndUpdateSpeed());
  }

  void computeAndUpdateSpeed() {
    int prevDownloadedBytesLastTime = downloadedBytesLastTime;
    downloadedBytesLastTime = downloadedBytes;

    double difference = 0.0 + downloadedBytes - prevDownloadedBytesLastTime;

    if (difference <= 0) {
      speed = '0 B/s';
      updateCallback?.call();
      return;
    }

    if (difference < 1024) {
      speed = '${difference.toInt()} B/s';
      updateCallback?.call();
      return;
    }

    difference /= 1024;
    if (difference < 1024) {
      speed = '${difference.toInt()} KB/s';
      updateCallback?.call();
      return;
    }

    difference /= 1024;
    if (difference < 1024) {
      speed = '${difference.toStringAsFixed(1)} MB/s';
      updateCallback?.call();
      return;
    }

    difference /= 1024;
    speed = '${difference.toStringAsFixed(2)} GB/s';
    updateCallback?.call();
  }

  void pause() {
    timer?.cancel();
    speed = '0 KB/s';
  }

  void dispose() {
    timer?.cancel();
  }
}
