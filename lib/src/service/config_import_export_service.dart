import 'dart:convert';

import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/performance_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';

import 'jh_service.dart';

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
  ConfigImportExportService();

  /// 获取 ConfigEnum 对应的设置模块
  JHLifeCircleBeanWithConfigStorage? _getSettingBean(ConfigEnum configEnum) {
    switch (configEnum) {
      case ConfigEnum.userSetting:
        return userSetting;
      case ConfigEnum.EHSetting:
        return ehSetting;
      case ConfigEnum.siteSetting:
        return siteSetting;
      case ConfigEnum.favoriteSetting:
        return favoriteSetting;
      case ConfigEnum.styleSetting:
        return styleSetting;
      case ConfigEnum.readSetting:
        return readSetting;
      case ConfigEnum.preferenceSetting:
        return preferenceSetting;
      case ConfigEnum.networkSetting:
        return networkSetting;
      case ConfigEnum.downloadSetting:
        return downloadSetting;
      case ConfigEnum.performanceSetting:
        return performanceSetting;
      case ConfigEnum.mouseSetting:
        return mouseSetting;
      case ConfigEnum.advancedSetting:
        return advancedSetting;
      case ConfigEnum.superResolutionSetting:
        return superResolutionSetting;
      case ConfigEnum.archiveBotSetting:
        return archiveBotSetting;
      default:
        return null;
    }
  }

  /// 导出所有设置配置
  Future<AppSettingsExportData> exportSettings() async {
    final Map<String, String> configs = {};

    for (final configEnum in kSettingsConfigEnums) {
      try {
        final bean = _getSettingBean(configEnum);
        if (bean != null) {
          // 通过设置模块的 toConfigString() 方法导出
          configs[configEnum.key] = bean.toConfigString();
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
  /// 通过设置模块的 applyBeanConfig() 方法导入，模拟用户从 UI 修改设置
  /// 返回成功导入的配置数量
  Future<int> importSettings(AppSettingsExportData data) async {
    int importedCount = 0;

    for (final entry in data.configs.entries) {
      try {
        // 安全解析 ConfigEnum，处理未知 key 的情况
        ConfigEnum configEnum;
        try {
          configEnum = ConfigEnum.from(entry.key);
        } catch (e) {
          // 未知的配置 key，跳过（可能是旧版本或新版本的配置）
          log.info('Skipping unknown config key: ${entry.key}');
          continue;
        }

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

        // 获取对应的设置模块
        final bean = _getSettingBean(configEnum);
        if (bean == null) {
          log.warning('No setting bean found for: ${entry.key}');
          continue;
        }

        // 通过设置模块的 applyBeanConfig() 方法导入配置
        // 这会更新内存中的 Rx 变量，并自动触发保存到数据库
        bean.applyBeanConfig(entry.value);
        await bean.saveBeanConfig();

        importedCount++;
        log.info('Imported config: ${entry.key}');
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
