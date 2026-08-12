import 'dart:convert';

/// A versioned snapshot of the non-sensitive application settings that may be
/// copied to a trusted peer. Values remain JSON strings so each setting keeps
/// its existing serialization and migration behavior on import.
class LanApplicationSettingsPayload {
  static const int schemaVersion = 1;

  final String sourceDeviceId;
  final DateTime generatedAt;
  final Map<String, String> configs;

  const LanApplicationSettingsPayload({
    required this.sourceDeviceId,
    required this.generatedAt,
    required this.configs,
  });

  Map<String, dynamic> toJson() {
    _validateConfigValues(configs);
    final Map<String, dynamic> payload = {
      'schemaVersion': schemaVersion,
      'capability': 'applicationSettingsV1',
      'sourceDeviceId': sourceDeviceId,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'configs': configs,
    };
    _validatePayload(payload);
    return payload;
  }

  factory LanApplicationSettingsPayload.fromJson(Map<String, dynamic> json) {
    _validatePayload(json);
    final dynamic rawConfigs = json['configs'];
    if (rawConfigs is! Map) {
      throw const FormatException(
        'LAN application settings configs must be an object',
      );
    }
    final Map<String, String> configs = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in rawConfigs.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException(
          'LAN application settings entries must be strings',
        );
      }
      configs[entry.key as String] = entry.value as String;
    }
    _validateConfigValues(configs);
    return LanApplicationSettingsPayload(
      sourceDeviceId: json['sourceDeviceId'] as String? ?? '',
      generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
      configs: configs,
    );
  }

  static const Set<String> _forbiddenKeys = <String>{
    'apikey',
    'api_key',
    'translationapikey',
    'proxypassword',
    'proxy_password',
    'applockpassword',
    'app_lock_password',
  };

  static void _validatePayload(Object? value) {
    if (value is Map) {
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        if (entry.key is String &&
            _forbiddenKeys.contains((entry.key as String).toLowerCase())) {
          throw const FormatException(
            'LAN application settings contain a forbidden secret field',
          );
        }
        _validatePayload(entry.value);
      }
    } else if (value is Iterable) {
      for (final Object? item in value) {
        _validatePayload(item);
      }
    }
  }

  static void _validateConfigValues(Map<String, String> configs) {
    for (final String value in configs.values) {
      try {
        _validatePayload(jsonDecode(value));
      } on FormatException {
        rethrow;
      } on Object catch (error) {
        throw FormatException('Invalid LAN application setting: $error');
      }
    }
  }
}
