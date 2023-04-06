import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../service/super_resolution_service.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/log.dart';
import '../../../../widget/loading_state_indicator.dart';

class SettingSuperResolutionPage extends StatelessWidget {
  const SettingSuperResolutionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('superResolution'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildModelDirectoryPath(),
            _buildDownload(),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDirectoryPath() {
    return ListTile(
      title: Text('modelDirectoryPath'.tr),
      subtitle: Text(SuperResolutionSetting.modelDirectoryPath.value ?? ''),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        String? result;
        try {
          result = await FilePicker.platform.getDirectoryPath();
        } on Exception catch (e) {
          Log.error('Pick executable file path failed', e);
          Log.upload(e);
          toast('internalError'.tr);
        }

        if (result == null) {
          return;
        }

        SuperResolutionSetting.saveModelDirectoryPath(result);
      },
    );
  }

  Widget _buildDownload() {
    return GetBuilder<SuperResolutionService>(
      id: SuperResolutionService.downloadId,
      builder: (superResolutionService) => ListTile(
        title: superResolutionService.downloadState == LoadingState.loading ? Text('downloading'.tr) : Text('downloadSuperResolutionModelHint'.tr),
        subtitle: superResolutionService.downloadState == LoadingState.loading
            ? Text(superResolutionService.downloadProgress)
            : superResolutionService.downloadState == LoadingState.success
                ? Text('downloaded'.tr)
                : null,
        trailing: superResolutionService.downloadState == LoadingState.loading ? const CupertinoActivityIndicator() : null,
        onTap: () {
          if (superResolutionService.downloadState == LoadingState.idle || superResolutionService.downloadState == LoadingState.error) {
            superResolutionService.downloadModelFile();
          } else if (superResolutionService.downloadState == LoadingState.success) {
            superResolutionService.deleteModelFile();
          } else {
            return;
          }
        },
      ),
    );
  }
}
