import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/lan_application_settings.dart';

void main() {
  test('application settings payload round-trips safe config values', () {
    final LanApplicationSettingsPayload original =
        LanApplicationSettingsPayload(
          sourceDeviceId: 'device-a',
          generatedAt: DateTime.utc(2026, 8, 13),
          configs: const <String, String>{
            'styleSetting': '{"themeMode":"dark"}',
            'imageTranslationSetting': '{"translatorApiKey":"secret"}',
          },
        );

    final LanApplicationSettingsPayload restored =
        LanApplicationSettingsPayload.fromJson(original.toJson());

    expect(restored.sourceDeviceId, original.sourceDeviceId);
    expect(restored.generatedAt, original.generatedAt);
    expect(restored.configs, original.configs);
  });

  test('application settings payload rejects sensitive fields', () {
    final LanApplicationSettingsPayload payload = LanApplicationSettingsPayload(
      sourceDeviceId: 'device-a',
      generatedAt: DateTime.utc(2026, 8, 13),
      configs: const <String, String>{
        'imageTranslationSetting': '{"apiKey":"secret"}',
      },
    );

    expect(payload.toJson, throwsFormatException);
  });
}
