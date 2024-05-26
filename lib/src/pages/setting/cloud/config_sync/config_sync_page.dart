import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/jh_request.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/byte_util.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_config_type_select_dialog.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../config/ui_config.dart';
import '../../../../model/config.dart';
import '../../../../utils/jh_spider_parser.dart';
import '../../../../utils/permission_util.dart';
import '../../../../utils/route_util.dart';

class ConfigSyncPage extends StatefulWidget {
  const ConfigSyncPage({super.key});

  @override
  State<ConfigSyncPage> createState() => _ConfigSyncPageState();
}

class _ConfigSyncPageState extends State<ConfigSyncPage> {
  final CloudConfigService cloudConfigService = Get.find();

  LoadingState _loadingState = LoadingState.idle;
  List<CloudConfig> configs = [];

  @override
  void initState() {
    _refresh();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('configSync'.tr)),
      body: LoadingStateIndicator(
        loadingState: _loadingState,
        successWidgetBuilder: () => configs.isEmpty
            ? Center(child: Text('noData'.tr, style: const TextStyle(fontSize: 16)))
            : ListView(
                padding: const EdgeInsets.only(top: 16),
                children: configs
                    .mapIndexed(
                      (index, config) => ListTile(
                        titleAlignment: ListTileTitleAlignment.center,
                        leading: Text((configs.length - index).toString()),
                        isThreeLine: true,
                        title: Text(config.type.name.tr),
                        subtitle: Text('v${config.version}\n${config.shareCode}'),
                        trailing: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(config.ctime)),
                        onTap: () => _handleTapConfig(context, config),
                      ),
                    )
                    .toList(),
              ).withListTileTheme(context),
        errorTapCallback: _refresh,
      ),
      floatingActionButton: UserSetting.hasLoggedIn() ? _buildFloatingActionButton(context) : null,
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.upload),
      onPressed: () async {
        if (_loadingState == LoadingState.loading) {
          return;
        }

        List<CloudConfigTypeEnum>? result = await showDialog(
          context: context,
          builder: (_) => const EHConfigTypeSelectDialog(),
        );

        if (result?.isNotEmpty ?? false) {
          _uploadConfig(result!);
        }
      },
    );
  }

  Future<void> _refresh() async {
    if (_loadingState == LoadingState.loading) {
      return;
    }

    if (!UserSetting.hasLoggedIn()) {
      setStateSafely(() => _loadingState = LoadingState.success);
      return;
    }

    setStateSafely(() => _loadingState = LoadingState.loading);

    try {
      List<CloudConfig> configs = await JHRequest.requestListConfig<List<CloudConfig>>(parser: JHResponseParser.listConfigApi2Configs);
      setStateSafely(() {
        this.configs = configs;
        _loadingState = LoadingState.success;
      });
    } on DioException catch (e) {
      Log.error('requestListConfig error: $e');
      snack('failed'.tr, e.errorMsg ?? '');
      setStateSafely(() => _loadingState = LoadingState.error);
    } catch (e) {
      Log.error('requestListConfig error: $e');
      snack('failed'.tr, e.toString());
      setStateSafely(() {
        _loadingState = LoadingState.error;
      });
    }
  }

  Future<void> _handleTapConfig(BuildContext context, CloudConfig config) async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('copyShareCode'.tr),
            onPressed: () {
              backRoute();
              Clipboard.setData(ClipboardData(text: config.shareCode));
              toast('hasCopiedToClipboard'.tr);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('download'.tr),
            onPressed: () {
              backRoute();
              _downloadConfig(config);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('import'.tr + (config.type == CloudConfigTypeEnum.settings ? '(${'needRestartApp'.tr})' : '')),
            onPressed: () {
              backRoute();
              _importConfig(config);
            },
          ),
          CupertinoActionSheetAction(
            child: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
            onPressed: () {
              backRoute();
              _deleteConfig(config);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: Text('cancel'.tr), onPressed: backRoute),
      ),
    );
  }

  Future<void> _downloadConfig(CloudConfig config) async {
    await requestStoragePermission();

    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath();
    } on Exception catch (e) {
      Log.error('Pick download config path failed', e);
    }

    if (path == null) {
      return;
    }

    if (!checkPermissionForPath(path)) {
      toast('invalidPath'.tr, isShort: false);
      return;
    }

    String fileName = '${config.type.name.tr}_${config.version}_${config.shareCode}.json';
    File file = File('$path/$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(config.config);
    toast('success'.tr);
  }

  Future<void> _importConfig(CloudConfig config) async {
    try {
      await cloudConfigService.importConfig(config);
      toast('success'.tr);
    } on Exception catch (e) {
      Log.error('importConfig error: $e');
      toast('failed'.tr);
    }
  }

  Future<void> _deleteConfig(CloudConfig config) async {
    if (_loadingState == LoadingState.loading) {
      return;
    }
    setStateSafely(() {
      configs = [];
      _loadingState = LoadingState.loading;
    });

    try {
      await JHRequest.requestDeleteConfig(
        id: config.id,
        parser: JHResponseParser.api2Success,
      );
    } on DioException catch (e) {
      Log.error('requestDeleteConfig error: $e');
      snack('failed'.tr, e.errorMsg ?? '');
      setStateSafely(() => _loadingState = LoadingState.error);
      return;
    } catch (e) {
      Log.error('requestDeleteConfig error: $e');
      snack('failed'.tr, e.toString());
      setStateSafely(() => _loadingState = LoadingState.error);
      return;
    }

    toast('success'.tr);
    _loadingState = LoadingState.success;

    _refresh();
  }

  Future<void> _uploadConfig(List<CloudConfigTypeEnum> types) async {
    if (_loadingState == LoadingState.loading) {
      return;
    }
    setStateSafely(() {
      configs = [];
      _loadingState = LoadingState.loading;
    });

    Map<CloudConfigTypeEnum, String> currentConfigMap = await cloudConfigService.getCurrentConfigMap();
    List<({int type, String version, String config})> uploadConfigs = currentConfigMap.entries.where((entry) => types.contains(entry.key)).map((entry) {
      return (
        type: entry.key.code,
        version: CloudConfigService.configTypeVersionMap[entry.key] ?? '1.0.0',
        config: entry.value,
      );
    }).toList();

    try {
      await JHRequest.requestBatchUploadConfig(
        configs: uploadConfigs,
        parser: JHResponseParser.api2Success,
      );
    } on DioException catch (e) {
      Log.error('requestUploadConfig error: $e');
      snack('failed'.tr, e.errorMsg ?? '');
      setStateSafely(() => _loadingState = LoadingState.error);
      return;
    } catch (e) {
      Log.error('requestUploadConfig error: $e');
      snack('failed'.tr, e.toString());
      setStateSafely(() => _loadingState = LoadingState.error);
      return;
    }

    toast('success'.tr);
    _loadingState = LoadingState.success;

    _refresh();
  }
}
