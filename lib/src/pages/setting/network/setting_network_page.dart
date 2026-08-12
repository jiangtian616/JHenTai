import 'dart:async';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/database/dao/dio_cache_dao.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/app_icons.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_expandable_switch_list_tile.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:path/path.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../routes/routes.dart';
import '../../../utils/byte_util.dart';
import '../../../utils/route_util.dart';
import '../../../utils/text_input_formatter.dart';
import '../../../utils/toast_util.dart';

class SettingNetworkPage extends StatelessWidget {
  final TextEditingController proxyAddressController = TextEditingController(
    text: networkSetting.proxyAddress.value,
  );
  final TextEditingController connectTimeoutController = TextEditingController(
    text: networkSetting.connectTimeout.value.toString(),
  );
  final TextEditingController receiveTimeoutController = TextEditingController(
    text: networkSetting.receiveTimeout.value.toString(),
  );

  SettingNetworkPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('networkSetting'.tr)),
      body: Obx(
        () => EHAppleSettingsListView(
          groups: [
            EHAppleSettingsGroup(
              children: [
                _buildEnableDomainFronting(),
                _buildProxyAddress(),
                EHAppleExpandableSwitchListTile(
                  title: Text('enableSmartCache'.tr),
                  subtitle: Text('enableSmartCacheHint'.tr),
                  value: networkSetting.enableSmartCache.value,
                  onChanged: networkSetting.saveEnableSmartCache,
                  children: [
                    _buildSmartCacheRetention(),
                    _buildSmartCacheMaxSize(),
                    _buildSmartCacheEvictPolicy(),
                    const _CacheSizeTile(),
                    _buildMoveCacheToServer(context),
                  ],
                ),
                _buildConnectTimeout(context),
                _buildReceiveTimeout(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableDomainFronting() {
    return EHAppleSwitchListTile(
      title: Text('enableDomainFronting'.tr),
      subtitle: Text('bypassSNIBlocking'.tr),
      value: networkSetting.enableDomainFronting.value,
      onChanged: networkSetting.saveEnableDomainFronting,
    );
  }

  Widget _buildProxyAddress() {
    return ListTile(
      title: Text('proxyAddress'.tr),
      trailing: Icon(AppIcons.chevronRight).marginOnly(right: 4),
      onTap: () => toRoute(Routes.proxy),
    );
  }

  Widget _buildSmartCacheRetention() {
    return ListTile(
      title: Text('smartCacheRetention'.tr),
      subtitle: Text('smartCacheRetentionHint'.tr),
      trailing: EHCodexStyleDropdown<Duration>(
        value: networkSetting.smartCacheRetention.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged:
            (Duration? newValue) =>
                networkSetting.saveSmartCacheRetention(newValue!),
        items: [
          DropdownMenuItem(child: Text('unlimited'.tr), value: Duration.zero),
          DropdownMenuItem(
            child: Text('1d'.tr),
            value: const Duration(days: 1),
          ),
          DropdownMenuItem(
            child: Text('3d'.tr),
            value: const Duration(days: 3),
          ),
          DropdownMenuItem(
            child: Text('7d'.tr),
            value: const Duration(days: 7),
          ),
          DropdownMenuItem(
            child: Text('30d'.tr),
            value: const Duration(days: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartCacheMaxSize() {
    return ListTile(
      title: Text('smartCacheMaxSize'.tr),
      subtitle: Text('smartCacheMaxSizeHint'.tr),
      trailing: EHCodexStyleDropdown<int>(
        value: networkSetting.smartCacheMaxSizeMB.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged:
            (int? newValue) =>
                networkSetting.saveSmartCacheMaxSizeMB(newValue ?? 0),
        items: [
          DropdownMenuItem(child: Text('unlimited'.tr), value: 0),
          const DropdownMenuItem(child: Text('512MB'), value: 512),
          const DropdownMenuItem(child: Text('1GB'), value: 1024),
          const DropdownMenuItem(child: Text('2GB'), value: 2048),
          const DropdownMenuItem(child: Text('5GB'), value: 5120),
          const DropdownMenuItem(child: Text('10GB'), value: 10240),
        ],
      ),
    );
  }

  Widget _buildSmartCacheEvictPolicy() {
    return ListTile(
      title: Text('smartCacheEvictPolicy'.tr),
      subtitle: Text('smartCacheEvictPolicyHint'.tr),
      trailing: EHCodexStyleDropdown<SmartCacheEvictPolicy>(
        value: networkSetting.smartCacheEvictPolicy.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged:
            (SmartCacheEvictPolicy? newValue) =>
                networkSetting.saveSmartCacheEvictPolicy(
                  newValue ?? SmartCacheEvictPolicy.addedDate,
                ),
        items: [
          DropdownMenuItem(
            child: Text('smartCacheEvictByAddedDate'.tr),
            value: SmartCacheEvictPolicy.addedDate,
          ),
          DropdownMenuItem(
            child: Text('smartCacheEvictByUsageFrequency'.tr),
            value: SmartCacheEvictPolicy.usageFrequency,
          ),
        ],
      ),
    );
  }

  Widget _buildMoveCacheToServer(BuildContext context) {
    return GetBuilder<LanDeviceTrustService>(
      id: LanDeviceTrustService.devicesChangedId,
      builder: (service) {
        final bool connected = service.hasConnectedDevice;
        return ListTile(
          enabled: connected,
          leading: Icon(
            Icons.cloud_upload_outlined,
            color: connected ? null : Theme.of(context).disabledColor,
          ),
          title: Text('moveCacheToServer'.tr),
          subtitle: Text(
            connected
                ? 'moveCacheToServerHint'.tr
                : 'moveCacheToServerDisabledHint'.tr,
          ),
          onTap: connected ? () => unawaited(_moveCacheToServer()) : null,
        );
      },
    );
  }

  Future<void> _moveCacheToServer() async {
    final String? cachePath = extendedImageDiskCacheDirectory;
    if (cachePath == null || cachePath.isEmpty) {
      toast('moveCacheToServerDone'.trParams({'count': '0'}));
      return;
    }
    final Directory cacheDirectory = Directory(cachePath);
    if (!cacheDirectory.existsSync()) {
      toast('moveCacheToServerDone'.trParams({'count': '0'}));
      return;
    }
    final List<File> files = cacheDirectory.listSync().whereType<File>().toList();
    int uploaded = 0;
    for (final File file in files) {
      try {
        final String key = file.uri.pathSegments.last;
        if (key.isEmpty || key.contains('/') || key.contains('..')) {
          continue;
        }
        final bool ok = await lanDeviceTrustService.pushCacheFileToServer(
          key,
          await file.readAsBytes(),
        );
        if (ok) {
          uploaded++;
        }
      } on Object catch (error) {
        log.warning('Move cache to server failed: $error');
      }
    }
    toast('moveCacheToServerDone'.trParams({'count': '$uploaded'}));
  }

  Widget _buildConnectTimeout(BuildContext context) {
    return ListTile(
      title: Text('connectTimeout'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: EHAppleTextField(
              controller: connectTimeoutController,
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
          const SizedBox(width: 8),
          Text(
            'ms',
            style: UIConfig.settingPageListTileTrailingTextStyle(context),
          ),
          const SizedBox(width: 8),
          EHAppleIconButton(
            onPressed: () {
              int? value = int.tryParse(connectTimeoutController.value.text);
              if (value == null) {
                return;
              }
              networkSetting.saveConnectTimeout(value);
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

  Widget _buildReceiveTimeout(BuildContext context) {
    return ListTile(
      title: Text('receiveTimeout'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: EHAppleTextField(
              controller: receiveTimeoutController,
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
          const SizedBox(width: 8),
          Text(
            'ms',
            style: UIConfig.settingPageListTileTrailingTextStyle(context),
          ),
          const SizedBox(width: 8),
          EHAppleIconButton(
            onPressed: () {
              int? value = int.tryParse(receiveTimeoutController.value.text);
              if (value == null) {
                return;
              }
              networkSetting.saveReceiveTimeout(value);
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
}

/// Shows the total size of the page cache (dio_cache) plus the image cache
/// (cacheimage/), with refresh and clear actions.
class _CacheSizeTile extends StatefulWidget {
  const _CacheSizeTile({Key? key}) : super(key: key);

  @override
  State<_CacheSizeTile> createState() => _CacheSizeTileState();
}

class _CacheSizeTileState extends State<_CacheSizeTile> {
  LoadingState loadingState = LoadingState.idle;
  String sizeText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (loadingState == LoadingState.loading) {
      return;
    }

    setState(() => loadingState = LoadingState.loading);

    try {
      final int totalBytes = await _getTotalCacheSize();
      sizeText = byte2String(totalBytes.toDouble());
      if (!mounted) {
        return;
      }
      setState(() => loadingState = LoadingState.success);
    } catch (e) {
      log.error('Get cache size failed', e);
      sizeText = '-1B';
      if (!mounted) {
        return;
      }
      setState(() => loadingState = LoadingState.error);
    }
  }

  Future<void> _clear() async {
    if (loadingState == LoadingState.loading) {
      return;
    }

    await ehRequest.removeAllCache();
    await clearDiskCachedImages();
    toast('clearSuccess'.tr, isCenter: false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('cacheSize'.tr),
      subtitle: Text(
        loadingState == LoadingState.loading || sizeText.isEmpty
            ? 'loading'.tr
            : sizeText,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EHAppleIconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
          EHAppleIconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

Future<int> _getTotalCacheSize() async {
  final int pageBytes = await DioCacheDao.getTotalSize();
  final int imageBytes = await compute(
    _computeImageCacheSize,
    join(pathService.tempDir.path, PathService.smartCacheFolderName),
  );
  return pageBytes + imageBytes;
}

int _computeImageCacheSize(String dirPath) {
  Directory dir = Directory(dirPath);
  if (!dir.existsSync()) {
    return 0;
  }
  return dir.listSync().fold<int>(
    0,
    (previousValue, element) => previousValue + (element as File).lengthSync(),
  );
}
