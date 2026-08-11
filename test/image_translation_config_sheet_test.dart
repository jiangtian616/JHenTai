import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/setting/advanced/image_translation/setting_image_translation_page.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:jhentai/src/widget/image_translation_config_sheet.dart';

void main() {
  late ImageTranslationSetting originalSetting;

  setUp(() {
    originalSetting = imageTranslationSetting;
  });

  tearDown(() {
    imageTranslationSetting = originalSetting;
  });

  testWidgets('quick sheet exposes independent OCR and translator selectors', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.ocrEngine.value = ImageOcrEngine.onnx;
    setting.translatorEngine.value = ImageTranslationEngine.appleOnDevice;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );

    final EHCodexStyleDropdown<ImageOcrEngine> ocr = tester.widget(
      find.byKey(const ValueKey('image-translation-ocr-engine')),
    );
    final EHCodexStyleDropdown<ImageTranslationEngine> translator = tester
        .widget(
          find.byKey(const ValueKey('image-translation-translator-engine')),
        );

    expect(ocr.value, ImageOcrEngine.onnx);
    expect(translator.value, ImageTranslationEngine.appleOnDevice);
  });

  testWidgets('advanced page keeps OCR and translator as separate controls', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.ocrEngine.value = ImageOcrEngine.appleLiveText;
    setting.translatorEngine.value = ImageTranslationEngine.api;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: SettingImageTranslationPage()),
    );

    final EHCodexStyleDropdown<ImageOcrEngine> ocr = tester.widget(
      find.byKey(const ValueKey('image-translation-ocr-engine')),
    );
    final EHCodexStyleDropdown<ImageTranslationEngine> translator = tester
        .widget(
          find.byKey(const ValueKey('image-translation-translator-engine')),
        );

    expect(ocr.value, ImageOcrEngine.appleLiveText);
    expect(translator.value, ImageTranslationEngine.api);
  });

  testWidgets('Apple translator exposes only one-page context mode', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.translatorEngine.value = ImageTranslationEngine.appleOnDevice;
    setting.contextBatchSize.value = ContextBatchSize.four;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );

    final EHCodexStyleDropdown<ContextBatchSize> context = tester.widget(
      find.byKey(const ValueKey('image-translation-context-batch-size')),
    );
    expect(context.value, ContextBatchSize.one);
    final List<DropdownMenuItem<ContextBatchSize>> items =
        context.items.cast<DropdownMenuItem<ContextBatchSize>>();
    expect(items.first.enabled, isTrue);
    expect(items.skip(1).every((item) => !item.enabled), isTrue);
    expect(
      find.text('imageTranslationContextAppleUnsupported'),
      findsOneWidget,
    );
  });
}
