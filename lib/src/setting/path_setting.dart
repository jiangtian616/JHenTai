import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PathSetting {
  static late Directory appDocDir;
  static late Directory appSupportDir;
  static late Directory? externalStorageDir;

  static Future<void> init() async {
    await Future.wait([
      getApplicationDocumentsDirectory().then((value) => appDocDir = value),
      getApplicationSupportDirectory().then((value) => appSupportDir = value),
      getExternalStorageDirectory().then((value) => externalStorageDir = value),
    ]);
  }
}
