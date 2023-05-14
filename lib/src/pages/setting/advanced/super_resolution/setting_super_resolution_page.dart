import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../service/super_resolution_service.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/log.dart';
import '../../../../widget/loading_state_indicator.dart';

class SettingSuperResolutionPage extends StatelessWidget {
  const SettingSuperResolutionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('superResolution'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () => launchUrlString(
              PreferenceSetting.locale.value.languageCode == 'zh'
                  ? 'https://github.com/jiangtian616/JHenTai/wiki/AI%E5%9B%BE%E7%89%87%E6%94%BE%E5%A4%A7%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95'
                  : PreferenceSetting.locale.value.languageCode == 'ko'
                      ? 'https://github.com/jiangtian616/JHenTai/wiki/AI-%EC%B4%88%EA%B3%A0%ED%99%94%EC%A7%88-%EC%9D%B4%EB%AF%B8%EC%A7%80-%EC%82%AC%EC%9A%A9-%EB%B0%A9%EB%B2%95'
                      : 'https://github.com/jiangtian616/JHenTai/wiki/AI-Image-Super-Resolution-Usage',
            ),
          )
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildModelDirectoryPath(),
            _buildDownload(),
            _buildModelType(),
          ],
        ).withListTileTheme(context),
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

  Widget _buildModelType() {
    return ListTile(
      title: Text('modelType'.tr),
      subtitle: Text(SuperResolutionSetting.modelType.value == 'realesrgan-x4plus' ? 'x4plusHint'.tr : 'x4plusAnimeHint'.tr),
      trailing: DropdownButton<String>(
        value: SuperResolutionSetting.modelType.value,
        elevation: 4,
        onChanged: (String? newValue) => SuperResolutionSetting.saveModelType(newValue!),
        items: const [
          DropdownMenuItem(child: Text('realesrgan-x4plus'), value: 'realesrgan-x4plus'),
          DropdownMenuItem(child: Text('realesrgan-x4plus-anime'), value: 'realesrgan-x4plus-anime'),
        ],
      ),
    );
  }

  Widget _buildEnable4OnlineReading() {
    return SwitchListTile(
      title: Text('enable4OnlineReading'.tr),
      value: SuperResolutionSetting.enable4OnlineReading.value,
      onChanged: SuperResolutionSetting.saveEnable4OnlineReading,
    );
  }
}
