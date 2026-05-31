import 'dart:convert';

import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import 'jh_service.dart';
import 'local_config_service.dart';

/// 需要导入/导出的设置模块（排除 securitySetting）
const List<ConfigEnum> kSettingsConfigEnums = [
  ConfigEnum.userSetting,
  ConfigEnum.EHSetting,
  ConfigEnum.siteSetting,
  ConfigEnum.favoriteSetting,
  ConfigEnum.styleSetting,
  ConfigEnum.readSetting,
  ConfigEnum.preferenceSetting,
  ConfigEnum.networkSetting,
  ConfigEnum.downloadSetting,
  ConfigEnum.performanceSetting,
  ConfigEnum.mouseSetting,
  ConfigEnum.advancedSetting,
  ConfigEnum.superResolutionSetting,
  ConfigEnum.archiveBotSetting,
];

/// 配置导入导出数据模型
class AppSettingsExportData {
  final int version;
  final String appName;
  final String exportTime;
  final Map<String, String> configs;

  AppSettingsExportData({
    required this.version,
    required this.appName,
    required this.exportTime,
    required this.configs,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'appName': appName,
        'exportTime': exportTime,
        'configs': configs,
      };

  factory AppSettingsExportData.fromJson(Map<String, dynamic> json) {
    return AppSettingsExportData(
      version: json['version'] as int? ?? 1,
      appName: json['appName'] as String? ?? 'JHenTai',
      exportTime: json['exportTime'] as String? ?? '',
      configs: Map<String, String>.from(json['configs'] as Map? ?? {}),
    );
  }

  /// 从 JSON 字符串解析
  factory AppSettingsExportData.fromString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppSettingsExportData.fromJson(json);
  }

  /// 序列化为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());
}

/// 配置导入导出服务
class ConfigImportExportService {
  final LocalConfigService _localConfigService;

  ConfigImportExportService(this._localConfigService);

  /// 导出所有设置配置
  Future<AppSettingsExportData> exportSettings() async {
    final Map<String, String> configs = {};

    for (final configEnum in kSettingsConfigEnums) {
      try {
        final configString = await _localConfigService.read(configKey: configEnum.key);
        if (configString != null && configString.isNotEmpty) {
          configs[configEnum.key] = configString;
        }
      } catch (e) {
        log.warning('Failed to export config: ${configEnum.key}', e);
      }
    }

    return AppSettingsExportData(
      version: 1,
      appName: 'JHenTai',
      exportTime: DateTime.now().toIso8601String(),
      configs: configs,
    );
  }

  /// 导入设置配置
  /// 返回成功导入的配置数量
  Future<int> importSettings(AppSettingsExportData data) async {
    int importedCount = 0;

    for (final entry in data.configs.entries) {
      try {
        final configEnum = ConfigEnum.from(entry.key);

        // 跳过不在导入列表中的配置
        if (!kSettingsConfigEnums.contains(configEnum)) {
          log.info('Skipping config: ${entry.key} (not in import list)');
          continue;
        }

        // 跳过 securitySetting
        if (configEnum == ConfigEnum.securitySetting) {
          log.info('Skipping securitySetting (requires local device computation)');
          continue;
        }

        await _localConfigService.write(
          configKey: entry.key,
          value: entry.value,
        );
        importedCount++;
      } catch (e) {
        log.warning('Failed to import config: ${entry.key}', e);
      }
    }

    return importedCount;
  }

  /// 获取可导入的配置模块名称（用于 UI 显示）
  List<String> getAvailableConfigNames() {
    return kSettingsConfigEnums
        .where((e) => e != ConfigEnum.securitySetting)
        .map((e) => e.key)
        .toList();
  }
}
