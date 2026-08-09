import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';

void main() {
  test('image translation settings round-trip through config JSON', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.applyBeanConfig('''
    {
      "ocrEngine": "appleLiveText",
      "appleLiveTextLanguage": "ja-JP,en-US",
      "appleLiveTextAutoSelected": true,
      "appleLiveTextUseThirdPartyApi": true,
      "lastCustomOcrEngine": "paddleOcr",
      "ocrLanguage": "jpn+eng",
      "paddleOcrLanguage": "japan"
    }
    ''');

    expect(setting.ocrEngine.value, ImageOcrEngine.appleLiveText);
    expect(setting.isAppleLiveTextMode, isTrue);
    expect(setting.appleLiveTextLanguage.value, 'ja-JP,en-US');
    expect(setting.appleLiveTextAutoSelected.value, isTrue);
    expect(setting.appleLiveTextUseThirdPartyApi.value, isTrue);
    expect(setting.lastCustomOcrEngine.value, ImageOcrEngine.paddleOcr);
    // The API toggle is on, so translation is not fully on-device.
    expect(setting.usesAppleOnDeviceTranslation, isFalse);

    final Map<String, dynamic> encoded =
        jsonDecode(setting.toConfigString()) as Map<String, dynamic>;
    expect(encoded['ocrEngine'], 'appleLiveText');
    expect(encoded['appleLiveTextLanguage'], 'ja-JP,en-US');
    expect(encoded['appleLiveTextAutoSelected'], isTrue);
    expect(encoded['appleLiveTextUseThirdPartyApi'], isTrue);
    expect(encoded['lastCustomOcrEngine'], 'paddleOcr');
  });

  test('unknown OCR engine degrades safely to the current value', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.applyBeanConfig('{"ocrEngine": "unknownEngine"}');
    expect(setting.ocrEngine.value, ImageOcrEngine.tesseract);
  });

  test('auto-translate-gallery-text setting survives a config round-trip', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    expect(setting.autoTranslateGalleryText.value, isFalse);

    setting.autoTranslateGalleryText.value = true;
    final String config = setting.toConfigString();

    final ImageTranslationSetting restored = ImageTranslationSetting();
    restored.applyBeanConfig(config);
    expect(restored.autoTranslateGalleryText.value, isTrue);
  });
}
