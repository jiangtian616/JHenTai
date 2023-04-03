import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../service/super_resolution_service.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/log.dart';
import '../../../../widget/loading_state_indicator.dart';

class SettingSuperResolutionPage extends StatelessWidget {
  // final SuperResolutionService superResolutionService = Get.find();

  SettingSuperResolutionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('superResolution'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildDownload(),
            _buildExecutableFilePath(),
            _buildUpSamplingScale(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownload() {
    return GetBuilder<SuperResolutionService>(
      id: SuperResolutionService.downloadId,
      builder: (superResolutionService) => ListTile(
        title: LoadingStateIndicator(
          loadingState: superResolutionService.downloadState,
          idleWidget: Text('downloadModelHint'.tr),
          loadingWidget: Text('downloading'.tr),
          successWidgetSameWithIdle: true,
          errorWidgetSameWithIdle: true,
        ),
        subtitle: LoadingStateIndicator(
          loadingState: superResolutionService.downloadState,
          idleWidget: null,
          loadingWidget: Text(superResolutionService.downloadProgress),
          successWidgetBuilder: () => Text('downloaded'.tr),
          errorWidgetSameWithIdle: true,
        ),
        trailing: LoadingStateIndicator(
          loadingState: superResolutionService.downloadState,
          idleWidget: null,
          successWidgetSameWithIdle: true,
        ),
        onTap: () {
          if (superResolutionService.downloadState == LoadingState.idle || superResolutionService.downloadState == LoadingState.error) {
            superResolutionService.downloadModelFile();
          } else {
            return;
          }
        },
      ),
    );
  }

  Widget _buildExecutableFilePath() {
    return ListTile(
      title: Text('executableFilePath'.tr),
      subtitle: Text(SuperResolutionSetting.executableFilePath.value ?? ''),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        FilePickerResult? result;
        try {
          result = await FilePicker.platform.pickFiles();
        } on Exception catch (e) {
          Log.error('Pick executable file path failed', e);
          Log.upload(e);
          toast('internalError'.tr);
        }

        if (result == null || result.files.single.path == null) {
          return;
        }

        SuperResolutionSetting.saveExecutableFilePath(result.files.single.path!);
      },
    );
  }

  Widget _buildUpSamplingScale() {
    return ListTile(
      title: Text('upSamplingScale'.tr),
      trailing: DropdownButton<int>(
        value: SuperResolutionSetting.upSamplingScale.value,
        elevation: 4,
        onChanged: (int? newValue) => SuperResolutionSetting.saveUpSamplingScale(newValue!),
        items: const [
          DropdownMenuItem(child: Text('2'), value: 2),
          DropdownMenuItem(child: Text('3'), value: 3),
          DropdownMenuItem(child: Text('4'), value: 4),
        ],
      ).marginOnly(right: 12),
    );
  }
}
