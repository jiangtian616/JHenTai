import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/setting/advanced/image_translation/setting_image_translation_page.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/image_translation_config_sheet.dart';

void main() {
  late ImageTranslationSetting originalSetting;

  setUp(() {
    originalSetting = imageTranslationSetting;
  });

  tearDown(() {
    imageTranslationSetting = originalSetting;
  });

  test('text merge preference is serialized and restored', () {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    // Manual single-line mode remains available when bubble detection is off.
    setting.enableBubbleDetection.value = false;
    setting.autoMergeText.value = false;
    final ImageTranslationSetting restored = ImageTranslationSetting();

    restored.applyBeanConfig(setting.toConfigString());

    expect(restored.autoMergeText.value, isFalse);
  });

  testWidgets('advanced settings apply changes without a save button', (
    WidgetTester tester,
  ) async {
    final _ImmediateSetting setting = _ImmediateSetting();
    setting.ocrEngine.value = ImageOcrEngine.appleLiveText;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: SettingImageTranslationPage()),
    );

    expect(find.text('saveSetting'), findsNothing);

    final EHCodexStyleDropdown<ImageOcrEngine> ocr = tester.widget(
      find.byKey(const ValueKey('image-translation-ocr-engine')),
    );
    ocr.onChanged?.call(ImageOcrEngine.appleLiveText);
    await tester.pump();

    expect(setting.ocrEngine.value, ImageOcrEngine.appleLiveText);
    expect(setting.saveCount, 1);
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

  testWidgets('quick sheet exposes the text merge switch', (
    WidgetTester tester,
  ) async {
    final _ImmediateSetting setting = _ImmediateSetting();
    setting.enableBubbleDetection.value = false;
    setting.autoMergeText.value = true;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();

    final EHAppleSwitchListTile tile = tester.widget(
      find.byKey(const ValueKey('image-translation-auto-merge-text')),
    );
    expect(tile.value, isTrue);
    tile.onChanged!(false);
    await tester.pump();
    expect(setting.autoMergeText.value, isFalse);
    expect(setting.saveCount, 1);
  });

  testWidgets('Apple on-device translation exposes the image language picker', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.ocrEngine.value = ImageOcrEngine.onnx;
    setting.translatorEngine.value = ImageTranslationEngine.appleOnDevice;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );

    expect(
      find.byKey(const ValueKey('image-translation-apple-live-text-language')),
      findsOneWidget,
    );
  });

  testWidgets('image language picker is hidden outside Apple OCR/translation', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.ocrEngine.value = ImageOcrEngine.onnx;
    setting.translatorEngine.value = ImageTranslationEngine.api;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );

    expect(
      find.byKey(const ValueKey('image-translation-apple-live-text-language')),
      findsNothing,
    );
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
    expect(find.text('imageTranslationMethodSection'), findsNothing);
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

  testWidgets('CTD and MI-GAN display mode is opt-in', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final EHCodexStyleDropdown<ImageProcessingDisplayMode> processing = tester
        .widget(
          find.byKey(const ValueKey('image-translation-image-processing-mode')),
        );
    expect(processing.value, ImageProcessingDisplayMode.overlay);
    final List<DropdownMenuItem<ImageProcessingDisplayMode>> items =
        processing.items.cast<DropdownMenuItem<ImageProcessingDisplayMode>>();
    expect(items, hasLength(2));
    expect(
      items.map(
        (DropdownMenuItem<ImageProcessingDisplayMode> item) => item.value,
      ),
      isNot(contains(ImageProcessingDisplayMode.translatedImage)),
    );
  });

  testWidgets('local GGUF exposes model download and runtime configuration', (
    WidgetTester tester,
  ) async {
    final ImageTranslationSetting setting = ImageTranslationSetting();
    setting.translatorEngine.value = ImageTranslationEngine.localGguf;
    imageTranslationSetting = setting;

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ImageTranslationConfigSheet())),
    );
    await tester.pump();

    final EHCodexStyleDropdown<String> model = tester.widget(
      find.byKey(const ValueKey('image-translation-local-model')),
    );
    expect(model.value, setting.localModelId.value);
    expect(
      find.byKey(const ValueKey('image-translation-local-model-download')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('image-translation-managed-llama-runtime')),
      findsOneWidget,
    );
  });
}

class _ImmediateSetting extends ImageTranslationSetting {
  int saveCount = 0;

  @override
  Future<int> saveBeanConfig() async => ++saveCount;
}
