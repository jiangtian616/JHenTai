import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/snack_util.dart';

class SettingDownloadPage extends StatelessWidget {
  const SettingDownloadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('downloadSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('downloadPath'.tr),
              subtitle: Text(DownloadService.downloadPath),
            ),
            ListTile(
              title: Text('downloadTaskConcurrency'.tr),
              subtitle: Text('needRestart'.tr),
              trailing: DropdownButton<int>(
                value: DownloadSetting.downloadTaskConcurrency.value,
                elevation: 4,
                onChanged: (int? newValue) {
                  DownloadSetting.saveDownloadTaskConcurrency(newValue!);
                },
                items: const [
                  DropdownMenuItem(
                    child: Text('2'),
                    value: 2,
                  ),
                  DropdownMenuItem(
                    child: Text('4'),
                    value: 4,
                  ),
                  DropdownMenuItem(
                    child: Text('6'),
                    value: 6,
                  ),
                  DropdownMenuItem(
                    child: Text('8'),
                    value: 8,
                  ),
                  DropdownMenuItem(
                    child: Text('10'),
                    value: 10,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('${'speedLimit'.tr} (${'needRestart'.tr})'),
              subtitle: Text('speedLimitHint'.tr),
              trailing: SizedBox(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<int>(
                      value: DownloadSetting.maximum.value,
                      elevation: 4,
                      alignment: AlignmentDirectional.bottomEnd,
                      onChanged: (int? newValue) {
                        DownloadSetting.saveMaximum(newValue!);
                      },
                      items: const [
                        DropdownMenuItem(
                          child: Text('1'),
                          value: 1,
                        ),
                        DropdownMenuItem(
                          child: Text('2'),
                          value: 2,
                        ),
                        DropdownMenuItem(
                          child: Text('3'),
                          value: 3,
                        ),
                        DropdownMenuItem(
                          child: Text('5'),
                          value: 5,
                        ),
                        DropdownMenuItem(
                          child: Text('10'),
                          value: 10,
                        ),
                        DropdownMenuItem(
                          child: Text('99'),
                          value: 99,
                        ),
                      ],
                    ),
                    Text('${'images'.tr} ${'per'.tr}').marginSymmetric(horizontal: 4),
                    DropdownButton<Duration>(
                      value: DownloadSetting.period.value,
                      elevation: 4,
                      alignment: AlignmentDirectional.bottomEnd,
                      onChanged: (Duration? newValue) {
                        DownloadSetting.savePeriod(newValue!);
                      },
                      items: const [
                        DropdownMenuItem(
                          child: Text('1s'),
                          value: Duration(seconds: 1),
                        ),
                        DropdownMenuItem(
                          child: Text('2s'),
                          value: Duration(seconds: 2),
                        ),
                        DropdownMenuItem(
                          child: Text('3s'),
                          value: Duration(seconds: 3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              title: Text('downloadTimeout'.tr),
              trailing: DropdownButton<int>(
                value: DownloadSetting.timeout.value,
                elevation: 4,
                onChanged: (int? newValue) {
                  DownloadSetting.saveTimeout(newValue!);
                },
                items: const [
                  DropdownMenuItem(
                    child: Text('5s'),
                    value: 5,
                  ),
                  DropdownMenuItem(
                    child: Text('10s'),
                    value: 10,
                  ),
                  DropdownMenuItem(
                    child: Text('15s'),
                    value: 15,
                  ),
                  DropdownMenuItem(
                    child: Text('20s'),
                    value: 20,
                  ),
                  DropdownMenuItem(
                    child: Text('30s'),
                    value: 30,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('enableStoreMetadataForRestore'.tr),
              trailing: Switch(
                value: DownloadSetting.enableStoreMetadataForRestore.value,
                onChanged: (value) => DownloadSetting.saveEnableStoreMetadataToRestore(value),
              ),
              subtitle: Text('enableStoreMetadataForRestoreHint'.tr),
            ),
            ListTile(
              title: Text('restoreDownloadTasks'.tr),
              subtitle: Text('restoreDownloadTasksHint'.tr),
              onTap: () async {
                int restoredCount = await Get.find<DownloadService>().restore();
                snack('restoreDownloadTasksSuccess'.tr, '${'restoredCount'.tr}: $restoredCount');
              },
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
