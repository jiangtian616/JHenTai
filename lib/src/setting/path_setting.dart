import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PathSetting {
  static late Directory tempDir;

  /// visible on ios
  static Directory? appDocDir;

  /// invisible on ios&android
  static late Directory appSupportDir;

  /// visible on android and not exists on ios
  static Directory? externalStorageDir;

  static Future<void> init() async {
    await Future.wait([
      getTemporaryDirectory().then((value) => tempDir = value),
      getApplicationDocumentsDirectory().then((value) => appDocDir = value),
      getApplicationSupportDirectory().then((value) => appSupportDir = value),
      getExternalStorageDirectory().then((value) => externalStorageDir = value).catchError((error) => null),
    ]);
  }

  static Directory getVisibleDir() {
    if (Platform.isAndroid && externalStorageDir != null) {
      return externalStorageDir!;
    }
    return appDocDir!;
  }
}
