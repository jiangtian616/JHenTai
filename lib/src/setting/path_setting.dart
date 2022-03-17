import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PathSetting {
  /// visible on ios
  static late Directory appDocDir;
  /// invisible on ios&android
  static late Directory appSupportDir;
  /// visible on android and not exists on ios
  static late Directory? externalStorageDir;

  static Future<void> init() async {
    await Future.wait([
      getApplicationDocumentsDirectory().then((value) => appDocDir = value),
      getApplicationSupportDirectory().then((value) => appSupportDir = value),
      getExternalStorageDirectory().then((value) => externalStorageDir = value).catchError((error) => null),
    ]);
  }
}
