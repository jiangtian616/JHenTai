import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/service/lan_sharing_runtime.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/performance_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/utils/app_icons.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../config/ui_config.dart';
import '../../../enum/config_type_enum.dart';
import '../../../routes/routes.dart';
import '../../../service/isolate_service.dart';
import '../../../utils/route_util.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../widget/eh_config_type_select_dialog.dart';
import '../../../widget/eh_apple_settings_list_view.dart';
import '../../../widget/eh_apple_controls.dart';
import '../../../widget/eh_apple_expandable_switch_list_tile.dart';

class SettingAdvancedPage extends StatefulWidget {
  const SettingAdvancedPage({Key? key}) : super(key: key);

  @override
  _SettingAdvancedPageState createState() => _SettingAdvancedPageState();
}

class _SettingAdvancedPageState extends State<SettingAdvancedPage> {
  LoadingState _logLoadingState = LoadingState.idle;
  String _logSize = '...';

  LoadingState _exportDataLoadingState = LoadingState.idle;
  LoadingState _importDataLoadingState = LoadingState.idle;
  late final TextEditingController _maxGalleryNum4AnimationController;

  @override
  void initState() {
    super.initState();

    _maxGalleryNum4AnimationController = TextEditingController(
      text: performanceSetting.maxGalleryNum4Animation.value.toString(),
    );
    _loadingLogSize();
  }

  @override
  void dispose() {
    _maxGalleryNum4AnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('advancedSetting'.tr)),
      body: Obx(
        () => EHAppleSettingsListView(
          groups: [
            EHAppleSettingsGroup(
              title: 'experimentalFeatures'.tr,
              children: [_buildLanSharingExperiment()],
            ),
            EHAppleSettingsGroup(
              title: 'readerPerformanceExperiments'.tr,
              children: [
                _buildReaderEngine2(),
                _buildPerformanceGovernor(),
                _buildProgressiveImagePipeline(),
                _buildCoverDecodeOptimization(),
              ],
            ),
            EHAppleSettingsGroup(
              children: [
                EHAppleExpandableSwitchListTile(
                  title: Text('enableLogging'.tr),
                  subtitle: Text('needRestart'.tr),
                  value: advancedSetting.enableLogging.value,
                  onChanged: advancedSetting.saveEnableLogging,
                  children: [_buildRecordAllLogs()],
                ),
                _buildOpenLogs(),
                _buildClearLogs(context),
                _buildMaxGalleryNum4Animation(context),
                _buildCheckUpdate(),
                _buildCheckClipboard(),
                if (GetPlatform.isAndroid) _buildVerifyAppLinks(),
                _buildInNoImageMode(),
                _buildImportData(context),
                _buildExportData(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderEngine2() {
    return EHAppleSwitchListTile(
      title: Text('readerEngine2'.tr),
      subtitle: Text('readerEngine2Hint'.tr),
      value: performanceSetting.enableReaderEngine2.value,
      onChanged: (value) async {
        await performanceSetting.setEnableReaderEngine2(value);
        toast('saveSuccess'.tr);
      },
    );
  }

  Widget _buildLanSharingExperiment() {
    return EHAppleExpandableSwitchListTile(
      title: Text('lanSharing'.tr),
      subtitle: Text('lanSharingExperimentalHint'.tr),
      value: advancedSetting.enableLanSharing.value,
      onChanged: (value) async {
        try {
          await advancedSetting.saveEnableLanSharing(value);
        } on Object catch (error, stack) {
          log.warning('Failed to save LAN sharing setting', error, true);
          log.trace(stack);
          toast('saveFailed'.tr);
          return;
        }

        try {
          await lanSharingRuntime.setEnabled(value);
        } on Object catch (error, stack) {
          log.warning('Failed to update LAN sharing runtime', error, true);
          log.trace(stack);
          if (value) {
            try {
              await advancedSetting.saveEnableLanSharing(false);
            } on Object catch (rollbackError, rollbackStack) {
              log.warning(
                'Failed to roll back LAN sharing setting',
                rollbackError,
                true,
              );
              log.trace(rollbackStack);
            }
          }
          toast('lanSharingStartFailed'.tr);
        }
      },
      children: [
        ListTile(
          title: Text('lanFindAndPairDevices'.tr),
          subtitle: Text('lanFindAndPairDevicesHint'.tr),
          trailing: Icon(AppIcons.chevronRight).marginOnly(right: 4),
          onTap: () => toRoute(Routes.lanSharing),
        ),
      ],
    );
  }

  Widget _buildPerformanceGovernor() {
    return EHAppleSwitchListTile(
      title: Text('performanceGovernor'.tr),
      subtitle: Text('performanceGovernorHint'.tr),
      value: performanceSetting.enablePerformanceGovernor.value,
      onChanged: (value) async {
        await performanceSetting.setEnablePerformanceGovernor(value);
        toast('saveSuccess'.tr);
      },
    );
  }

  Widget _buildProgressiveImagePipeline() {
    return EHAppleSwitchListTile(
      title: Text('progressiveImagePipeline'.tr),
      subtitle: Text('progressiveImagePipelineHint'.tr),
      value: performanceSetting.enableProgressiveImagePipeline.value,
      onChanged: (value) async {
        await performanceSetting.setEnableProgressiveImagePipeline(value);
        toast('saveSuccess'.tr);
      },
    );
  }

  Widget _buildCoverDecodeOptimization() {
    return EHAppleSwitchListTile(
      title: Text('enableCoverDecodeOptimization'.tr),
      subtitle: Text('enableCoverDecodeOptimizationHint'.tr),
      value: performanceSetting.enableCoverDecodeOptimization.value,
      onChanged: (value) async {
        await performanceSetting.setEnableCoverDecodeOptimization(value);
        toast('saveSuccess'.tr);
      },
    );
  }

  Widget _buildRecordAllLogs() {
    return EHAppleSwitchListTile(
      title: Text('enableVerboseLogging'.tr),
      subtitle: Text('needRestart'.tr),
      value: advancedSetting.enableVerboseLogging.value,
      onChanged: advancedSetting.saveEnableVerboseLogging,
    );
  }

  Widget _buildOpenLogs() {
    return ListTile(
      title: Text('openLog'.tr),
      trailing: Icon(AppIcons.chevronRight).marginOnly(right: 4),
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
            successWidgetBuilder:
                () => Text(
                  _logSize,
                  style: TextStyle(
                    color: UIConfig.resumePauseButtonColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            errorTapCallback: _loadingLogSize,
          ).marginOnly(right: 8),
        ],
      ),
      onLongPress: _clearAndLoadingLogSize,
    );
  }

  Widget _buildMaxGalleryNum4Animation(BuildContext context) {
    return ListTile(
      title: Text('maxGalleryNum4Animation'.tr),
      subtitle: Text('maxGalleryNum4AnimationHint'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: EHAppleTextField(
              controller: _maxGalleryNum4AnimationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                labelStyle: TextStyle(fontSize: 12),
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                IntRangeTextInputFormatter(minValue: 0),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final int? value = int.tryParse(
                _maxGalleryNum4AnimationController.value.text,
              );
              if (value == null) {
                return;
              }
              performanceSetting.setMaxGalleryNum4Animation(value);
              toast('saveSuccess'.tr);
            },
            icon: Icon(
              Icons.check,
              color: UIConfig.resumePauseButtonColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckUpdate() {
    return EHAppleSwitchListTile(
      title: Text('checkUpdateAfterLaunchingApp'.tr),
      value: advancedSetting.enableCheckUpdate.value,
      onChanged: advancedSetting.saveEnableCheckUpdate,
    );
  }

  Widget _buildCheckClipboard() {
    return EHAppleSwitchListTile(
      title: Text('checkClipboard'.tr),
      value: advancedSetting.enableCheckClipboard.value,
      onChanged: advancedSetting.saveEnableCheckClipboard,
    );
  }

  Widget _buildVerifyAppLinks() {
    return ListTile(
      title: Text('verityAppLinks4Android12'.tr),
      subtitle: Text('verityAppLinks4Android12Hint'.tr),
      trailing: Icon(AppIcons.chevronRight).marginOnly(right: 4),
      onTap: () async {
        try {
          await const AndroidIntent(
            action: 'android.settings.APP_OPEN_BY_DEFAULT_SETTINGS',
            data: 'package:top.jtmonster.jhentai',
          ).launch();
        } on Exception catch (e) {
          log.error(e);
          log.uploadError(e);
          toast('error'.tr);
        }
      },
    );
  }

  Widget _buildInNoImageMode() {
    return EHAppleSwitchListTile(
      title: Text('noImageMode'.tr),
      value: advancedSetting.inNoImageMode.value,
      onChanged: advancedSetting.saveInNoImageMode,
    );
  }

  Widget _buildImportData(BuildContext context) {
    return ListTile(
      title: Text('importData'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _importDataLoadingState,
            idleWidgetBuilder: () => Icon(AppIcons.chevronRight),
            successWidgetSameWithIdle: true,
            useCupertinoIndicator: true,
            errorWidgetSameWithIdle: true,
          ).marginOnly(right: 8),
        ],
      ),
      onTap: () => _importData(context),
    );
  }

  Widget _buildExportData(BuildContext context) {
    return ListTile(
      title: Text('exportData'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _exportDataLoadingState,
            idleWidgetBuilder: () => Icon(AppIcons.chevronRight),
            successWidgetSameWithIdle: true,
            useCupertinoIndicator: true,
            errorWidgetSameWithIdle: true,
          ).marginOnly(right: 8),
        ],
      ),
      onTap: () => _exportData(context),
    );
  }

  Future<void> _loadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.loading);

    try {
      _logSize = await log.getSize();
    } catch (e) {
      log.error('loading log size error', e);
      _logSize = '-1B';
      setStateSafely(() => _logLoadingState = LoadingState.error);
      return;
    }

    setStateSafely(() => _logLoadingState = LoadingState.success);
  }

  Future<void> _clearAndLoadingLogSize() async {
    if (_logLoadingState == LoadingState.loading) {
      return;
    }

    await log.clear();
    await _loadingLogSize();

    toast('clearSuccess'.tr, isCenter: false);
  }

  Future<void> _importData(BuildContext context) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowCompression: false,
        compressionQuality: 0,
      );
    } on Exception catch (e) {
      log.error('Pick import data file failed', e);
      return;
    }

    if (result == null) {
      return;
    }

    if (_importDataLoadingState == LoadingState.loading) {
      return;
    }

    log.info('Import data from ${result.files.first.path}');
    setStateSafely(() => _importDataLoadingState = LoadingState.loading);

    File file = File(result.files.first.path!);
    String string = await file.readAsString();

    try {
      List list = await isolateService.jsonDecodeAsync(string);
      List<CloudConfig> configs =
          list.map((e) => CloudConfig.fromJson(e)).toList();
      for (CloudConfig config in configs) {
        await cloudConfigService.importConfig(config);
      }

      toast('success'.tr);
      setStateSafely(() => _importDataLoadingState = LoadingState.success);
    } catch (e, s) {
      log.error('Import data failed', e, s);
      toast('internalError'.tr);
      setStateSafely(() => _importDataLoadingState = LoadingState.error);
      return;
    }
  }

  Future<void> _exportData(BuildContext context) async {
    List<CloudConfigTypeEnum>? result = await showDialog(
      context: context,
      builder: (_) => EHConfigTypeSelectDialog(title: 'selectExportItems'.tr),
    );
    if (result?.isEmpty ?? true) {
      return;
    }

    String fileName =
        '${CloudConfigService.configFileName}-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.json';
    if (GetPlatform.isMobile) {
      return _exportDataMobile(fileName, result);
    } else {
      return _exportDataDesktop(fileName, result);
    }
  }

  Future<void> _exportDataMobile(
    String fileName,
    List<CloudConfigTypeEnum>? result,
  ) async {
    if (_exportDataLoadingState == LoadingState.loading) {
      return;
    }
    setStateSafely(() => _exportDataLoadingState = LoadingState.loading);

    List<CloudConfig> uploadConfigs = [];
    for (CloudConfigTypeEnum type in result!) {
      CloudConfig? config = await cloudConfigService.getLocalConfig(type);
      if (config != null) {
        uploadConfigs.add(config);
      }
    }

    try {
      String? savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(await isolateService.jsonEncodeAsync(uploadConfigs)),
        lockParentWindow: true,
      );
      if (savedPath != null) {
        log.info('Export data to $savedPath success');
        toast('success'.tr);
        setStateSafely(() => _exportDataLoadingState = LoadingState.success);
      }
    } on Exception catch (e) {
      log.error('Export data failed', e);
      toast('internalError'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.error);
    }
  }

  Future<void> _exportDataDesktop(
    String fileName,
    List<CloudConfigTypeEnum>? result,
  ) async {
    if (_exportDataLoadingState == LoadingState.loading) {
      return;
    }
    setStateSafely(() => _exportDataLoadingState = LoadingState.loading);

    String? savedPath;
    try {
      savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        lockParentWindow: true,
      );
    } on Exception catch (e) {
      log.error('Select save path for exporting data failed', e);
      toast('internalError'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.error);
      return;
    }

    if (savedPath == null) {
      return;
    }

    List<CloudConfig> uploadConfigs = [];
    for (CloudConfigTypeEnum type in result!) {
      CloudConfig? config = await cloudConfigService.getLocalConfig(type);
      if (config != null) {
        uploadConfigs.add(config);
      }
    }

    File file = File(savedPath);
    try {
      if (await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(
        await isolateService.jsonEncodeAsync(uploadConfigs),
      );
      log.info('Export data to $savedPath success');
      toast('success'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.success);
    } on Exception catch (e) {
      log.error('Export data failed', e);
      toast('internalError'.tr);
      setStateSafely(() => _exportDataLoadingState = LoadingState.error);
      file.delete().ignore();
    }
  }
}
