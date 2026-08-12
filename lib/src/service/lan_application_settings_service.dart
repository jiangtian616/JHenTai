import 'dart:convert';

import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/lan_application_settings.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/eh_setting.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/keyboard_shortcut_setting.dart';
import 'package:jhentai/src/setting/mouse_setting.dart';
import 'package:jhentai/src/setting/performance_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';

LanApplicationSettingsService lanApplicationSettingsService =
    LanApplicationSettingsService();

class _LanSettingBinding {
  final ConfigEnum key;
  final String Function() export;
  final Future<void> Function() refresh;
  final Set<String> omittedFields;

  const _LanSettingBinding({
    required this.key,
    required this.export,
    required this.refresh,
    this.omittedFields = const <String>{},
  });
}

class LanApplicationSettingsService {
  final LocalConfigService _localConfigService;

  LanApplicationSettingsService({LocalConfigService? configService})
    : _localConfigService = configService ?? localConfigService;

  List<_LanSettingBinding> get _bindings => <_LanSettingBinding>[
    _LanSettingBinding(
      key: ConfigEnum.EHSetting,
      export: ehSetting.toConfigString,
      refresh: ehSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.mouseSetting,
      export: mouseSetting.toConfigString,
      refresh: mouseSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.downloadSetting,
      export: downloadSetting.toConfigString,
      refresh: downloadSetting.refreshBean,
      omittedFields: <String>{
        'downloadPath',
        'singleImageSavePath',
        'tempDownloadPath',
        'extraGalleryScanPath',
      },
    ),
    _LanSettingBinding(
      key: ConfigEnum.performanceSetting,
      export: performanceSetting.toConfigString,
      refresh: performanceSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.preferenceSetting,
      export: preferenceSetting.toConfigString,
      refresh: preferenceSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.readSetting,
      export: readSetting.toConfigString,
      refresh: readSetting.refreshBean,
      omittedFields: <String>{'thirdPartyViewerPath'},
    ),
    _LanSettingBinding(
      key: ConfigEnum.siteSetting,
      export: siteSetting.toConfigString,
      refresh: siteSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.styleSetting,
      export: styleSetting.toConfigString,
      refresh: styleSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.keyboardShortcutSetting,
      export: keyboardShortcutSetting.toConfigString,
      refresh: keyboardShortcutSetting.refreshBean,
    ),
    _LanSettingBinding(
      key: ConfigEnum.imageTranslationSetting,
      export: imageTranslationSetting.toConfigString,
      refresh: imageTranslationSetting.refreshBean,
      omittedFields: <String>{'translatorEndpoint', 'localLlamaServerPath'},
    ),
  ];

  Future<LanApplicationSettingsPayload> exportSettings({
    required String sourceDeviceId,
    required DateTime generatedAt,
  }) async {
    final Map<String, String> configs = <String, String>{};
    for (final _LanSettingBinding binding in _bindings) {
      final String value =
          await _localConfigService.read(configKey: binding.key) ??
          binding.export();
      configs[binding.key.key] = _sanitize(value, binding.omittedFields);
    }
    return LanApplicationSettingsPayload(
      sourceDeviceId: sourceDeviceId,
      generatedAt: generatedAt,
      configs: configs,
    );
  }

  Future<int> importSettings(LanApplicationSettingsPayload payload) async {
    final Map<String, _LanSettingBinding> bindings =
        <String, _LanSettingBinding>{
          for (final _LanSettingBinding binding in _bindings)
            binding.key.key: binding,
        };
    int imported = 0;
    for (final MapEntry<String, String> entry in payload.configs.entries) {
      final _LanSettingBinding? binding = bindings[entry.key];
      if (binding == null) {
        continue;
      }
      final String value = _sanitize(entry.value, binding.omittedFields);
      await _localConfigService.write(configKey: binding.key, value: value);
      await binding.refresh();
      imported++;
    }
    return imported;
  }

  String _sanitize(String value, Set<String> omittedFields) {
    final dynamic decoded = jsonDecode(value);
    if (decoded is! Map || omittedFields.isEmpty) {
      return value;
    }
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(decoded);
    for (final String field in omittedFields) {
      sanitized.remove(field);
    }
    return jsonEncode(sanitized);
  }
}
