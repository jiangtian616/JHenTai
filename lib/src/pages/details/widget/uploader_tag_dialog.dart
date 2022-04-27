import 'package:dio/dio.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../network/eh_request.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/log.dart';
import '../../../utils/snack_util.dart';
import '../../../utils/toast_util.dart';
import '../../../widget/loading_state_indicator.dart';

class UploaderTagDialog extends StatefulWidget {
  final String uploader;

  const UploaderTagDialog({Key? key, required this.uploader}) : super(key: key);

  @override
  State<UploaderTagDialog> createState() => _UploaderTagDialogState();
}

class _UploaderTagDialogState extends State<UploaderTagDialog> {
  LoadingState addWatchedTagState = LoadingState.idle;
  LoadingState addHiddenTagState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('uploader:${widget.uploader}'),
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            LoadingStateIndicator(
              loadingState: addWatchedTagState,
              idleWidget: GestureDetector(
                onTap: () => _addNewTagSet(true),
                child: Icon(Icons.favorite, color: Get.theme.primaryColorLight),
              ),
              successWidgetBuilder: () => const DoneWidget(),
              errorTapCallback: () => _addNewTagSet(true),
            ),
            LoadingStateIndicator(
              loadingState: addHiddenTagState,
              idleWidget: GestureDetector(
                onTap: () => _addNewTagSet(false),
                child: Icon(Icons.visibility_off, color: Colors.grey.shade700),
              ),
              successWidgetBuilder: () => const DoneWidget(),
              errorTapCallback: () => _addNewTagSet(false),
            ),
          ],
        )
      ],
    );
  }

  Future<void> _addNewTagSet(bool watch) async {
    toast('needLoginToOperate'.tr);
    if (!UserSetting.hasLoggedIn()) {
      toast('needLoginToOperate'.tr);
      return;
    }

    setState(() {
      if (watch) {
        addWatchedTagState = LoadingState.loading;
      } else {
        addHiddenTagState = LoadingState.loading;
      }
    });

    try {
      await EHRequest.requestAddTagSet(
        tag: 'uploader:${widget.uploader}',
        tagWeight: 10,
        watch: watch,
        hidden: !watch,
      );
    } on DioError catch (e) {
      Log.error('addNewTagSetFailed'.tr, e.message);
      snack('addNewTagSetFailed'.tr, e.message, longDuration: true, snackPosition: SnackPosition.BOTTOM);
      setState(() {
        if (watch) {
          addWatchedTagState = LoadingState.error;
        } else {
          addHiddenTagState = LoadingState.error;
        }
      });
      return;
    }

    setState(() {
      if (watch) {
        addWatchedTagState = LoadingState.success;
      } else {
        addHiddenTagState = LoadingState.success;
      }
    });

    Log.info('addNewTagSetSuccess'.tr, false);
    snack(
      watch ? 'addNewWatchedTagSetSuccess'.tr : 'addNewHiddenTagSetSuccess'.tr,
      'addNewTagSetSuccessHint'.tr,
      longDuration: true,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
