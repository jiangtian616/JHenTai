import 'dart:io' as io;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_cache_interceptor.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';

class SettingAdvancedPage extends StatefulWidget {
  const SettingAdvancedPage({Key? key}) : super(key: key);

  @override
  _SettingAdvancedPageState createState() => _SettingAdvancedPageState();
}

class _SettingAdvancedPageState extends State<SettingAdvancedPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('advancedSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildEnableLogging(),
            if (AdvancedSetting.enableLogging.isTrue) _buildRecordAllLogs().fadeIn(),
            _buildOpenLogs(),

            /// Can't delete file that file is being used on Windows
            if (!GetPlatform.isWindows) _buildClearLogs(),
            _buildClearImageCache(),
            _buildClearNetworkCache(),
            _buildCheckUpdate(),
            _buildCheckClipboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableLogging() {
    return ListTile(
      title: Text('enableLogging'.tr),
      trailing: Switch(value: AdvancedSetting.enableLogging.value, onChanged: AdvancedSetting.saveEnableLogging),
      subtitle: Text('needRestart'.tr),
    );
  }

  Widget _buildRecordAllLogs() {
    return ListTile(
      title: Text('enableVerboseLogging'.tr),
      trailing: Switch(value: AdvancedSetting.enableVerboseLogging.value, onChanged: AdvancedSetting.saveEnableVerboseLogging),
    );
  }

  Widget _buildOpenLogs() {
    return ListTile(
      title: Text('openLog'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.logList),
    );
  }

  Widget _buildClearLogs() {
    return ListTile(
      title: Text('clearLogs'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Text(Log.getSize(), style: TextStyle(color: UIConfig.resumeButtonColor, fontWeight: FontWeight.w500)).marginOnly(right: 8),
      onLongPress: () {
        Log.clear();
        setState(() {
          toast('clearSuccess'.tr, isCenter: false);
        });
      },
    );
  }

  Widget _buildClearImageCache() {
    return ListTile(
      title: Text('clearImagesCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Text(_getImagesCacheSize(), style: TextStyle(color: UIConfig.resumeButtonColor, fontWeight: FontWeight.w500)).marginOnly(right: 8),
      onLongPress: () async {
        await clearDiskCachedImages();
        setState(() {
          toast('clearSuccess'.tr, isCenter: false);
        });
      },
    );
  }

  Widget _buildClearNetworkCache() {
    return ListTile(
      title: Text('clearPageCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      onLongPress: () async {
        await Get.find<EHCacheInterceptor>().removeAllCache();
        toast('clearSuccess'.tr, isCenter: false);
      },
    );
  }

  Widget _buildCheckUpdate() {
    return ListTile(
      title: Text('checkUpdateAfterLaunchingApp'.tr),
      trailing: Switch(value: AdvancedSetting.enableCheckUpdate.value, onChanged: AdvancedSetting.saveEnableCheckUpdate),
    );
  }

  Widget _buildCheckClipboard() {
    return ListTile(
      title: Text('checkClipboard'.tr),
      trailing: Switch(value: AdvancedSetting.enableCheckClipboard.value, onChanged: AdvancedSetting.saveEnableCheckClipboard),
    );
  }

  String _getImagesCacheSize() {
    try {
      io.Directory cacheImagesDirectory = io.Directory(join(PathSetting.tempDir.path, cacheImageFolderName));
      if (!cacheImagesDirectory.existsSync()) {
        return '0KB';
      }

      int totalBytes = cacheImagesDirectory.listSync().fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());

      return (totalBytes / 1024 / 1024).toStringAsFixed(2) + 'MB';
    } on Exception catch (e) {
      Log.upload(e);
      return '0KB';
    }
  }
}
