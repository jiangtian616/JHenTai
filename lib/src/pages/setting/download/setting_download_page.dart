import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/download_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';

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
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }
}
