import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/global_config.dart';
import '../utils/route_util.dart';

class EHDownloadOriginalImageDialog extends StatelessWidget {
  const EHDownloadOriginalImageDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GlobalConfig.downloadOriginalImageDialogColor,
      title: Text('downloadOriginalImage'.tr + ' ?'),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      actions: [
        TextButton(onPressed: backRoute, child: Text('resampleImage'.tr)),
        TextButton(onPressed: () => backRoute(result: true), child: Text('originalImage'.tr)),
      ],
    );
  }
}
