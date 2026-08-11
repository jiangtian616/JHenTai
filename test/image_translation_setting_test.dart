import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';

class _MemoryImageTranslationSetting extends ImageTranslationSetting {
  int saveCount = 0;

  @override
  Future<int> saveBeanConfig() async => ++saveCount;
}

void main() {
  test('image translation settings round-trip through config JSON', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.applyBeanConfig('''
    {
      "ocrEngine": "appleLiveText",
      "appleLiveTextLanguage": "ja-JP,en-US",
      "appleLiveTextAutoSelected": true,
      "appleLiveTextUseThirdPartyApi": true,
      "lastCustomOcrEngine": "paddleOcr"
    }
    ''');

    expect(setting.ocrEngine.value, ImageOcrEngine.appleLiveText);
    expect(setting.isAppleLiveTextMode, isTrue);
    expect(setting.appleLiveTextLanguage.value, 'ja-JP,en-US');
    expect(setting.appleLiveTextAutoSelected.value, isTrue);
    expect(setting.appleLiveTextUseThirdPartyApi.value, isTrue);
    // "paddleOcr" no longer exists in the enum; custom mode is fixed to ONNX.
    expect(setting.lastCustomOcrEngine.value, ImageOcrEngine.onnx);
    // The API toggle is on, so translation is not fully on-device.
    expect(setting.usesAppleOnDeviceTranslation, isFalse);

    final Map<String, dynamic> encoded =
        jsonDecode(setting.toConfigString()) as Map<String, dynamic>;
    expect(encoded['ocrEngine'], 'appleLiveText');
    expect(encoded['appleLiveTextLanguage'], 'ja-JP,en-US');
    expect(encoded['appleLiveTextAutoSelected'], isTrue);
    expect(encoded['appleLiveTextUseThirdPartyApi'], isTrue);
    expect(encoded['translatorEngine'], 'api');
    expect(encoded['lastCustomOcrEngine'], 'onnx');
  });

  test('unknown OCR engine degrades safely to the current value', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.applyBeanConfig('{"ocrEngine": "unknownEngine"}');
    expect(setting.ocrEngine.value, ImageOcrEngine.onnx);
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

  test('context batch size round-trips only through fixed values', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.contextBatchSize.value = ContextBatchSize.eight;

    final ImageTranslationSetting restored = ImageTranslationSetting();
    restored.applyBeanConfig(setting.toConfigString());
    expect(restored.contextBatchSize.value, ContextBatchSize.eight);

    restored.applyBeanConfig('{"contextBatchSize":"unsupported"}');
    expect(restored.contextBatchSize.value, ContextBatchSize.one);
  });

  test(
    'image-processing mode persists and rejects unavailable raster mode',
    () {
      final ImageTranslationSetting setting = ImageTranslationSetting();
      expect(
        setting.imageProcessingDisplayMode.value,
        ImageProcessingDisplayMode.overlay,
        reason: 'CTD and MI-GAN must remain opt-in',
      );
      setting.imageProcessingDisplayMode.value =
          ImageProcessingDisplayMode.repairedBackgroundEmbeddedText;

      final ImageTranslationSetting restored = ImageTranslationSetting();
      restored.applyBeanConfig(setting.toConfigString());
      expect(
        restored.imageProcessingDisplayMode.value,
        ImageProcessingDisplayMode.repairedBackgroundEmbeddedText,
      );

      restored.applyBeanConfig(
        '{"imageProcessingDisplayMode":"translatedImage"}',
      );
      expect(
        restored.imageProcessingDisplayMode.value,
        ImageProcessingDisplayMode.overlay,
      );
    },
  );

  test('Apple translator resets unsupported context batching', () async {
    final _MemoryImageTranslationSetting setting =
        _MemoryImageTranslationSetting();
    setting.contextBatchSize.value = ContextBatchSize.four;

    await setting.saveTranslatorEngine(ImageTranslationEngine.appleOnDevice);

    expect(setting.contextBatchSize.value, ContextBatchSize.one);
  });

  test('Apple Live Text auto language survives a config round-trip', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.appleLiveTextLanguage.value = 'auto';

    final ImageTranslationSetting restored = ImageTranslationSetting();
    restored.applyBeanConfig(setting.toConfigString());

    expect(restored.appleLiveTextLanguage.value, 'auto');
  });

  test('ONNX OCR can select Apple Translation independently', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.applyBeanConfig('''
    {
      "ocrEngine": "onnx",
      "translatorEngine": "appleOnDevice"
    }
    ''');

    expect(setting.isAppleLiveTextMode, isFalse);
    expect(
      setting.translatorEngine.value,
      ImageTranslationEngine.appleOnDevice,
    );
    expect(setting.usesAppleOnDeviceTranslation, isTrue);
  });

  test('changing OCR preserves the selected translation engine', () async {
    final _MemoryImageTranslationSetting setting =
        _MemoryImageTranslationSetting();
    setting.translatorEngine.value = ImageTranslationEngine.appleOnDevice;

    await setting.saveOcrEngine(ImageOcrEngine.appleLiveText);
    await setting.saveOcrEngine(ImageOcrEngine.onnx);

    expect(setting.ocrEngine.value, ImageOcrEngine.onnx);
    expect(
      setting.translatorEngine.value,
      ImageTranslationEngine.appleOnDevice,
    );
    expect(setting.saveCount, 2);
  });

  test('changing translator preserves the selected OCR engine', () async {
    final _MemoryImageTranslationSetting setting =
        _MemoryImageTranslationSetting();
    setting.ocrEngine.value = ImageOcrEngine.appleLiveText;

    await setting.saveTranslatorEngine(ImageTranslationEngine.api);
    await setting.saveTranslatorEngine(ImageTranslationEngine.localGguf);

    expect(setting.ocrEngine.value, ImageOcrEngine.appleLiveText);
    expect(setting.translatorEngine.value, ImageTranslationEngine.localGguf);
    expect(setting.saveCount, 2);
  });

  test(
    'combined save persists OCR and translator without deriving either',
    () async {
      final _MemoryImageTranslationSetting setting =
          _MemoryImageTranslationSetting();

      await setting.save(
        ocrEngine: ImageOcrEngine.onnx,
        appleLiveTextLanguage: 'auto',
        translatorEngine: ImageTranslationEngine.appleOnDevice,
        translatorProvider: ImageTranslationProvider.openAICompatible,
        translatorEndpoint: '',
        translatorApiKey: '',
        translatorModel: 'unused',
        targetLanguage: '简体中文',
      );

      expect(setting.ocrEngine.value, ImageOcrEngine.onnx);
      expect(
        setting.translatorEngine.value,
        ImageTranslationEngine.appleOnDevice,
      );
      expect(setting.saveCount, 1);
    },
  );
}
