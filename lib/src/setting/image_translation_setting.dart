import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../enum/config_enum.dart';
import '../service/engine/context_translation_contract.dart';
import '../service/engine/engine_contract.dart';
import '../service/inference/onnx_model_store.dart';
import '../service/jh_service.dart';
import '../service/log.dart';

ImageTranslationSetting imageTranslationSetting = ImageTranslationSetting();

enum ImageTranslationProvider { openAICompatible, anthropic }

/// Translation is selected independently from OCR. The legacy
/// [appleLiveTextUseThirdPartyApi] flag remains serialized and synchronized so
/// existing settings continue to load without making Apple OCR imply Apple
/// Translation.
enum ImageTranslationEngine { api, appleOnDevice, localGguf }

enum ImageOcrEngine {
  /// 端侧 ONNX 推理（PP-OCRv6，走统一"推理后端"入口）。
  onnx,

  /// Independent manga-OCR adapter. It currently falls back to ONNX until
  /// the official vocabulary hash and five-platform runtime are verified.
  mangaOcr,

  /// Apple Vision framework 的 Live Text 识别（仅 Apple 平台）。
  appleLiveText,
}

class ImageTranslationSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  final Rx<ImageOcrEngine> ocrEngine = ImageOcrEngine.onnx.obs;

  /// The active ONNX OCR model manifest id (e.g. PP-OCRv6 small vs tiny). The
  /// engine resolves model files lazily against this id.
  final RxString onnxModelId = RxString(OnnxModelStore.ocrManifestId);

  /// Allows the service to offer manga-OCR for Japanese tategaki once the
  /// adapter reports ready. The current blocked adapter leaves existing OCR
  /// results untouched.
  final RxBool mangaOcrAutoSuggest = true.obs;

  /// Apple Live Text recognition languages, as a comma-separated list of
  /// BCP-47 codes, or 'auto' for on-device auto detection (iOS 16 / macOS 13+).
  final RxString appleLiveTextLanguage = 'auto'.obs;

  /// True once the engine has been auto-switched to [ImageOcrEngine.appleLiveText]
  /// on an Apple platform, so the one-time migration does not fight a later
  /// manual engine choice.
  final RxBool appleLiveTextAutoSelected = false.obs;

  /// Legacy compatibility mirror for settings written before OCR and
  /// translation became independent. New UI must use [translatorEngine].
  final RxBool appleLiveTextUseThirdPartyApi = false.obs;

  /// Legacy compatibility value retained while older configs are migrated.
  final Rx<ImageOcrEngine> lastCustomOcrEngine = ImageOcrEngine.onnx.obs;
  final Rx<ImageTranslationProvider> translatorProvider =
      ImageTranslationProvider.openAICompatible.obs;
  final Rx<ImageTranslationEngine> translatorEngine =
      ImageTranslationEngine.api.obs;

  /// Verified GGUF catalog id used by the local llama.cpp adapter.
  final RxString localModelId = 'qwen35-0.8b-q4-k-m'.obs;

  /// Desktop llama-server executable. Mobile never reads this path and uses
  /// the maintained FFI bridge instead.
  final RxnString localLlamaServerPath = RxnString();
  final RxnString translatorEndpoint = RxnString();
  final RxnString translatorApiKey = RxnString();
  final RxString translatorModel = 'gpt-4.1-mini'.obs;
  final RxString targetLanguage = '简体中文'.obs;
  final RxBool enableThinking = false.obs;

  /// Merge OCR lines from the same bubble/text box into one translation unit.
  /// Enabled by default to preserve the bubble-aware translation behavior.
  final RxBool autoMergeText = true.obs;
  /// Detect complete speech bubbles before OCR so lines can share one layout
  /// container. If the detector is unavailable, OCR falls back to full-image
  /// recognition.
  final RxBool enableBubbleDetection = true.obs;
  /// Color of the backing plate drawn behind translated text.
  final Rx<Color> translationBackgroundColor = Colors.white.obs;
  /// Opacity of the backing plate, independent from the selected color.
  final RxDouble translationBackgroundOpacity = 0.9.obs;
  final RxBool translateSubsequentPages = false.obs;
  final Rx<ContextBatchSize> contextBatchSize = ContextBatchSize.one.obs;
  final Rx<ImageProcessingDisplayMode> imageProcessingDisplayMode =
      ImageProcessingDisplayMode.overlay.obs;

  /// Whether to auto-translate gallery titles and comments as they appear on
  /// screen. This currently requires Apple on-device translation, independent
  /// of the selected OCR engine (see [usesAppleOnDeviceTranslation]).
  final RxBool autoTranslateGalleryText = false.obs;

  bool get isTranslatorConfigured =>
      translatorEndpoint.value?.trim().isNotEmpty == true &&
      translatorApiKey.value?.trim().isNotEmpty == true &&
      translatorModel.value.trim().isNotEmpty;

  bool get isLocalTranslationSelected =>
      translatorEngine.value == ImageTranslationEngine.localGguf;

  @override
  ConfigEnum get configEnum => ConfigEnum.imageTranslationSetting;

  @override
  void applyBeanConfig(String configString) {
    final Map<String, dynamic> config = jsonDecode(configString);
    // Custom mode is fixed to ONNX; stored values for removed engines
    // (tesseract/paddle) fall back to the current default via orElse.
    ocrEngine.value = ImageOcrEngine.values.firstWhere(
      (engine) => engine.name == config['ocrEngine'],
      orElse: () => ocrEngine.value,
    );
    onnxModelId.value = config['onnxModelId'] ?? onnxModelId.value;
    mangaOcrAutoSuggest.value =
        config['mangaOcrAutoSuggest'] ?? mangaOcrAutoSuggest.value;
    appleLiveTextLanguage.value =
        config['appleLiveTextLanguage'] ?? appleLiveTextLanguage.value;
    appleLiveTextAutoSelected.value =
        config['appleLiveTextAutoSelected'] ?? appleLiveTextAutoSelected.value;
    appleLiveTextUseThirdPartyApi.value =
        config['appleLiveTextUseThirdPartyApi'] ??
        appleLiveTextUseThirdPartyApi.value;
    lastCustomOcrEngine.value = ImageOcrEngine.values.firstWhere(
      (engine) => engine.name == config['lastCustomOcrEngine'],
      orElse: () => lastCustomOcrEngine.value,
    );
    translatorProvider.value = ImageTranslationProvider.values.firstWhere(
      (provider) => provider.name == config['translatorProvider'],
      orElse: () => translatorProvider.value,
    );
    final String? configuredTranslatorEngine =
        config['translatorEngine'] as String?;
    if (configuredTranslatorEngine != null) {
      translatorEngine.value = ImageTranslationEngine.values.firstWhere(
        (engine) => engine.name == configuredTranslatorEngine,
        orElse: () => translatorEngine.value,
      );
      appleLiveTextUseThirdPartyApi.value =
          translatorEngine.value == ImageTranslationEngine.api;
    } else if (ocrEngine.value == ImageOcrEngine.appleLiveText) {
      // P0 settings only had the Apple OCR mode plus this API toggle. Migrate
      // that representation to the independent translator selection.
      translatorEngine.value =
          (config['appleLiveTextUseThirdPartyApi'] as bool? ?? false)
              ? ImageTranslationEngine.api
              : ImageTranslationEngine.appleOnDevice;
    }
    translatorEndpoint.value = config['translatorEndpoint'];
    translatorApiKey.value = config['translatorApiKey'];
    translatorModel.value = config['translatorModel'] ?? translatorModel.value;
    localModelId.value = config['localModelId'] ?? localModelId.value;
    localLlamaServerPath.value = config['localLlamaServerPath'];
    targetLanguage.value = config['targetLanguage'] ?? targetLanguage.value;
    enableThinking.value = config['enableThinking'] ?? enableThinking.value;
    autoMergeText.value = config['autoMergeText'] ?? autoMergeText.value;
    enableBubbleDetection.value =
        config['enableBubbleDetection'] ?? enableBubbleDetection.value;
    if (enableBubbleDetection.value) {
      autoMergeText.value = true;
    }
    final Object? configuredBackgroundColor =
        config['translationBackgroundColor'];
    if (configuredBackgroundColor is num) {
      translationBackgroundColor.value =
          Color(configuredBackgroundColor.toInt()).withAlpha(255);
    }
    final Object? configuredOpacity = config['translationBackgroundOpacity'];
    if (configuredOpacity is num) {
      translationBackgroundOpacity.value =
          configuredOpacity.toDouble().clamp(0.0, 1.0).toDouble();
    }
    translateSubsequentPages.value =
        config['translateSubsequentPages'] ?? translateSubsequentPages.value;
    contextBatchSize.value = ContextBatchSize.values.firstWhere(
      (ContextBatchSize size) => size.name == config['contextBatchSize'],
      orElse: () => ContextBatchSize.one,
    );
    imageProcessingDisplayMode.value = ImageProcessingDisplayMode.values
        .firstWhere(
          (ImageProcessingDisplayMode mode) =>
              mode.name == config['imageProcessingDisplayMode'] &&
              mode != ImageProcessingDisplayMode.translatedImage,
          orElse: () => ImageProcessingDisplayMode.overlay,
        );
    if (translatorEngine.value == ImageTranslationEngine.appleOnDevice) {
      contextBatchSize.value = ContextBatchSize.one;
    }
    autoTranslateGalleryText.value =
        config['autoTranslateGalleryText'] ?? autoTranslateGalleryText.value;
  }

  @override
  String toConfigString() => jsonEncode({
    'ocrEngine': ocrEngine.value.name,
    'onnxModelId': onnxModelId.value,
    'mangaOcrAutoSuggest': mangaOcrAutoSuggest.value,
    'appleLiveTextLanguage': appleLiveTextLanguage.value,
    'appleLiveTextAutoSelected': appleLiveTextAutoSelected.value,
    'appleLiveTextUseThirdPartyApi': appleLiveTextUseThirdPartyApi.value,
    'lastCustomOcrEngine': lastCustomOcrEngine.value.name,
    'translatorProvider': translatorProvider.value.name,
    'translatorEngine': translatorEngine.value.name,
    'translatorEndpoint': translatorEndpoint.value,
    'translatorApiKey': translatorApiKey.value,
    'translatorModel': translatorModel.value,
    'localModelId': localModelId.value,
    'localLlamaServerPath': localLlamaServerPath.value,
    'targetLanguage': targetLanguage.value,
    'enableThinking': enableThinking.value,
    'autoMergeText': autoMergeText.value,
    'enableBubbleDetection': enableBubbleDetection.value,
    'translationBackgroundColor':
        translationBackgroundColor.value.withAlpha(255).toARGB32(),
    'translationBackgroundOpacity': translationBackgroundOpacity.value,
    'translateSubsequentPages': translateSubsequentPages.value,
    'contextBatchSize': contextBatchSize.value.name,
    'imageProcessingDisplayMode': imageProcessingDisplayMode.value.name,
    'autoTranslateGalleryText': autoTranslateGalleryText.value,
  });

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {
    await _autoSelectAppleLiveTextIfNeeded();
  }

  /// On Apple platforms, switch the OCR engine to the on-device Apple Live Text
  /// engine once (and only once) so image translation works out of the box.
  /// A later manual engine choice is never overridden again.
  Future<void> _autoSelectAppleLiveTextIfNeeded() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    if (appleLiveTextAutoSelected.value) {
      return;
    }
    if (ocrEngine.value != ImageOcrEngine.appleLiveText) {
      lastCustomOcrEngine.value = ocrEngine.value;
      ocrEngine.value = ImageOcrEngine.appleLiveText;
    }
    appleLiveTextAutoSelected.value = true;
    await saveBeanConfig();
  }

  bool get isAppleLiveTextMode =>
      ocrEngine.value == ImageOcrEngine.appleLiveText;

  /// Whether translation uses Apple's on-device Translation framework.
  bool get usesAppleOnDeviceTranslation =>
      translatorEngine.value == ImageTranslationEngine.appleOnDevice;

  Future<void> save({
    required ImageOcrEngine ocrEngine,
    required String appleLiveTextLanguage,
    required ImageTranslationEngine translatorEngine,
    required ImageTranslationProvider translatorProvider,
    required String translatorEndpoint,
    required String translatorApiKey,
    required String translatorModel,
    required String targetLanguage,
    bool? enableThinking,
    bool? translateSubsequentPages,
  }) async {
    this.ocrEngine.value = ocrEngine;
    this.appleLiveTextLanguage.value =
        appleLiveTextLanguage.trim().isEmpty
            ? 'auto'
            : appleLiveTextLanguage.trim();
    this.translatorEngine.value = translatorEngine;
    if (translatorEngine == ImageTranslationEngine.appleOnDevice) {
      contextBatchSize.value = ContextBatchSize.one;
    }
    appleLiveTextUseThirdPartyApi.value =
        translatorEngine == ImageTranslationEngine.api;
    this.translatorProvider.value = translatorProvider;
    this.translatorEndpoint.value =
        translatorEndpoint.trim().isEmpty ? null : translatorEndpoint.trim();
    this.translatorApiKey.value =
        translatorApiKey.trim().isEmpty ? null : translatorApiKey.trim();
    this.translatorModel.value = translatorModel.trim();
    this.targetLanguage.value =
        targetLanguage.trim().isEmpty ? '简体中文' : targetLanguage.trim();
    if (enableThinking != null) {
      this.enableThinking.value = enableThinking;
    }
    if (translateSubsequentPages != null) {
      this.translateSubsequentPages.value = translateSubsequentPages;
    }
    await saveBeanConfig();
  }

  Future<void> saveAutoMergeText(bool value) async {
    if (enableBubbleDetection.value && !value) {
      // Bubble detection always renders one translation block per bubble.
      // Ignore an incompatible attempt to disable merging while it is on.
      autoMergeText.value = true;
      await saveBeanConfig();
      return;
    }
    autoMergeText.value = value;
    await saveBeanConfig();
  }

  Future<void> saveEnableBubbleDetection(bool value) async {
    enableBubbleDetection.value = value;
    if (value) {
      // A detected bubble is the unit of translation and layout. Keeping this
      // invariant in the setting layer prevents the compact and advanced
      // panels from creating incompatible combinations.
      autoMergeText.value = true;
    }
    await saveBeanConfig();
  }

  Future<void> saveTranslationBackgroundColor(Color value) async {
    translationBackgroundColor.value = value.withAlpha(255);
    await saveBeanConfig();
  }

  Future<void> saveTranslationBackgroundOpacity(double value) async {
    translationBackgroundOpacity.value = value.clamp(0.0, 1.0).toDouble();
    await saveBeanConfig();
  }

  Future<void> saveEnableThinking(bool value) async {
    enableThinking.value = value;
    await saveBeanConfig();
  }

  Future<void> saveTranslateSubsequentPages(bool value) async {
    translateSubsequentPages.value = value;
    await saveBeanConfig();
  }

  Future<void> saveContextBatchSize(ContextBatchSize value) async {
    contextBatchSize.value = value;
    await saveBeanConfig();
  }

  Future<void> saveImageProcessingDisplayMode(
    ImageProcessingDisplayMode value,
  ) async {
    imageProcessingDisplayMode.value =
        value == ImageProcessingDisplayMode.translatedImage
            ? ImageProcessingDisplayMode.overlay
            : value;
    await saveBeanConfig();
  }

  Future<void> saveAutoTranslateGalleryText(bool value) async {
    autoTranslateGalleryText.value = value;
    await saveBeanConfig();
  }

  Future<void> saveTranslatorModel(String value) async {
    translatorModel.value =
        value.trim().isEmpty ? 'gpt-4.1-mini' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveTargetLanguage(String value) async {
    targetLanguage.value = value.trim().isEmpty ? '简体中文' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveAppleLiveTextLanguage(String value) async {
    appleLiveTextLanguage.value = value.trim().isEmpty ? 'auto' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveTranslatorEngine(ImageTranslationEngine value) async {
    translatorEngine.value = value;
    if (value == ImageTranslationEngine.appleOnDevice) {
      contextBatchSize.value = ContextBatchSize.one;
    }
    appleLiveTextUseThirdPartyApi.value = value == ImageTranslationEngine.api;
    await saveBeanConfig();
  }

  Future<void> saveTranslatorProvider(ImageTranslationProvider value) async {
    translatorProvider.value = value;
    await saveBeanConfig();
  }

  Future<void> saveTranslatorEndpoint(String value) async {
    translatorEndpoint.value = value.trim().isEmpty ? null : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveTranslatorApiKey(String value) async {
    translatorApiKey.value = value.trim().isEmpty ? null : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveLocalModelId(String value) async {
    if (value.trim().isEmpty) {
      return;
    }
    localModelId.value = value.trim();
    await saveBeanConfig();
  }

  Future<void> saveLocalLlamaServerPath(String value) async {
    localLlamaServerPath.value = value.trim().isEmpty ? null : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveOcrEngine(ImageOcrEngine value) async {
    ocrEngine.value = value;
    await saveBeanConfig();
  }

  Future<void> saveOnnxModelId(String modelId) async {
    log.debug('saveOnnxModelId:$modelId');
    onnxModelId.value = modelId;
    await saveBeanConfig();
  }

  Future<void> saveMangaOcrAutoSuggest(bool value) async {
    mangaOcrAutoSuggest.value = value;
    await saveBeanConfig();
  }
}
