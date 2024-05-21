import 'dart:io' as io;

import 'package:android_intent_plus/android_intent.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';

import '../../../config/ui_config.dart';
import '../../../routes/routes.dart';
import '../../../utils/byte_util.dart';
import '../../../utils/route_util.dart';

class SettingAdvancedPage extends StatefulWidget {
  const SettingAdvancedPage({Key? key}) : super(key: key);

  @override
  _SettingAdvancedPageState createState() => _SettingAdvancedPageState();
}

class _SettingAdvancedPageState extends State<SettingAdvancedPage> {
  LoadingState _logLoadingState = LoadingState.idle;
  String _logSize = '...';

  LoadingState _imageCacheLoadingState = LoadingState.idle;
  String _imageCacheSize = '...';

  @override
  void initState() {
    super.initState();

    _loadingLogSize();
    _getImagesCacheSize();
  }

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
            _buildClearLogs(context),
            _buildClearImageCache(context),
            _buildClearNetworkCache(),
            if (GetPlatform.isDesktop) _buildSuperResolution(),
            _buildCheckUpdate(),
            _buildCheckClipboard(),
            if (GetPlatform.isAndroid) _buildVerifyAppLinks(),
            _buildInNoImageMode(),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildEnableLogging() {
    return ListTile(
      title: Text('enableLogging'.tr),
      subtitle: Text('needRestart'.tr),
      trailing: Switch(value: AdvancedSetting.enableLogging.value, onChanged: AdvancedSetting.saveEnableLogging),
    );
  }

  Widget _buildRecordAllLogs() {
    return SwitchListTile(
      title: Text('enableVerboseLogging'.tr),
      subtitle: Text('needRestart'.tr),
      value: AdvancedSetting.enableVerboseLogging.value,
      onChanged: AdvancedSetting.saveEnableVerboseLogging,
    );
  }

  Widget _buildOpenLogs() {
    return ListTile(
      title: Text('openLog'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.logList),
    );
  }

  Widget _buildClearLogs(BuildContext context) {
    return ListTile(
      title: Text('clearLogs'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _logLoadingState,
            useCupertinoIndicator: true,
            successWidgetBuilder: () => Text(
              _logSize,
              style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.w500),
            ),
            errorTapCallback: _loadingLogSize,
          ).marginOnly(right: 8)
        ],
      ),
      onLongPress: _clearAndLoadingLogSize,
    );
  }

  Widget _buildClearImageCache(BuildContext context) {
    return ListTile(
      title: Text('clearImagesCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _imageCacheLoadingState,
            useCupertinoIndicator: true,
            successWidgetBuilder: () => Text(
              _imageCacheSize,
              style: TextStyle(color: UIConfig.resumePauseButtonColor(context), fontWeight: FontWeight.w500),
            ),
            errorTapCallback: _getImagesCacheSize,
          ).marginOnly(right: 8)
        ],
      ),
      onLongPress: _clearAndLoadingImageCacheSize,
    );
  }

  Widget _buildClearNetworkCache() {
    return ListTile(
      title: Text('clearPageCache'.tr),
      subtitle: Text('longPress2Clear'.tr),
      onLongPress: () async {
        await EHRequest.removeAllCache();
        toast('clearSuccess'.tr, isCenter: false);
      },
    );
  }

  Widget _buildSuperResolution() {
    return ListTile(
      title: Text('superResolution'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () => toRoute(Routes.superResolution),
    );
  }

  Widget _buildCheckUpdate() {
    return SwitchListTile(
      title: Text('checkUpdateAfterLaunchingApp'.tr),
      value: AdvancedSetting.enableCheckUpdate.value,
      onChanged: AdvancedSetting.saveEnableCheckUpdate,
    );
  }

  Widget _buildCheckClipboard() {
    return SwitchListTile(
      title: Text('checkClipboard'.tr),
      value: AdvancedSetting.enableCheckClipboard.value,
      onChanged: AdvancedSetting.saveEnableCheckClipboard,
    );
  }

  Widget _buildVerifyAppLinks() {
    return ListTile(
      title: Text('verityAppLinks4Android12'.tr),
      subtitle: Text('verityAppLinks4Android12Hint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right).marginOnly(right: 4),
      onTap: () async {
        try {
          await const AndroidIntent(
            action: 'android.settings.APP_OPEN_BY_DEFAULT_SETTINGS',
            data: 'package:top.jtmonster.jhentai',
          ).launch();
        } on Exception catch (e) {
          Log.error(e);
          Log.uploadError(e);
          toast('error'.tr);
        }
      },
    );
  }

  Widget _buildInNoImageMode() {
    return SwitchListTile(
      title: Text('noImageMode'.tr),
      value: AdvancedSetting.inNoImageMode.value,
      onChanged: AdvancedSetting.saveInNoImageMode,
    );
  }

  Future<void> _loadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.loading);

    try {
      _logSize = await Log.getSize();
    } catch (e) {
      Log.error('loading log size error', e);
      _logSize = '-1B';
      setStateSafely(() => _imageCacheLoadingState = LoadingState.error);
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.success);
  }

  Future<void> _clearAndLoadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    await Log.clear();
    await _loadingLogSize();

    toast('clearSuccess'.tr, isCenter: false);
  }

  Future<void> _getImagesCacheSize() async {
    if (_imageCacheLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => _imageCacheLoadingState = LoadingState.loading);

    try {
      _imageCacheSize = await compute(
        (dirPath) {
          io.Directory cacheImagesDirectory = io.Directory(dirPath);

          int totalBytes;
          if (!cacheImagesDirectory.existsSync()) {
            totalBytes = 0;
          } else {
            totalBytes = cacheImagesDirectory.listSync().fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());
          }

          return byte2String(totalBytes.toDouble());
        },
        join(PathSetting.tempDir.path, cacheImageFolderName),
      );
    } catch (e) {
      Log.error(e);
      _imageCacheSize = '-1B';
      setStateSafely(() => _imageCacheLoadingState = LoadingState.error);
      return;
    }

    setStateSafely(() => _imageCacheLoadingState = LoadingState.success);
  }

  Future<void> _clearAndLoadingImageCacheSize() async {
    if (_imageCacheLoadingState == LoadingState.loading) {
      return;
    }

    await clearDiskCachedImages();
    await _getImagesCacheSize();

    toast('clearSuccess'.tr, isCenter: false);
  }
}
