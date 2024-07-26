import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart';

import '../setting/read_setting.dart';
import '../service/log.dart';

void openThirdPartyViewer(String dirPath) {
  String viewerPath = ReadSetting.thirdPartyViewerPath.value!;

  Process.run(
    basename(viewerPath),
    [dirPath],
    workingDirectory: dirname(viewerPath),
    runInShell: true,
  ).catchError((e) {
    toast('internalError'.tr + e.toString());
    log.error(e);
    log.uploadError(
      e,
      extraInfos: {'viewerPath': viewerPath, 'dirPath': dirPath},
    );
  }).then((result) {
    if (!isEmptyOrNull(result.stderr)) {
      toast('internalError'.tr + result.stderr);
      log.error(result.stderr);
      log.uploadError(
        Exception('Process Error'),
        extraInfos: {
          'viewerPath': viewerPath,
          'dirPath': dirPath,
          'exitCode': result.exitCode,
          'stderr': result.stderr,
        },
      );
    }
  });
}
