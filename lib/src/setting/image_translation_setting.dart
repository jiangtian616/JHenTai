import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../enum/config_enum.dart';
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

  /// In Apple Live Text mode, whether to translate with the shared third-party
  /// API (the same provider/endpoint/key/model as the custom mode) instead of
  /// Apple's on-device translation.
  final RxBool appleLiveTextUseThirdPartyApi = false.obs;

  /// The OCR engine to restore when switching back from Apple Live Text mode to
  /// the custom mode (always ONNX now that it is the only custom engine).
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
  final RxBool translateSubsequentPages = false.obs;

  /// Whether to auto-translate gallery titles and comments as they appear on
  /// screen. Only functional in Apple Live Text mode with on-device
  /// translation (see [usesAppleOnDeviceTranslation]).
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
    translateSubsequentPages.value =
        config['translateSubsequentPages'] ?? translateSubsequentPages.value;
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
    'translateSubsequentPages': translateSubsequentPages.value,
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

  /// Whether translation runs entirely on-device in Apple Live Text mode:
  /// recognition via Vision and translation via Apple's Translation framework,
  /// with no third-party API involved.
  bool get usesAppleOnDeviceTranslation =>
      translatorEngine.value == ImageTranslationEngine.appleOnDevice;

  /// Switch to the self-contained Apple Live Text mode, remembering the current
  /// custom engine so it can be restored later.
  Future<void> switchToAppleLiveTextMode() async {
    if (!isAppleLiveTextMode) {
      lastCustomOcrEngine.value = ocrEngine.value;
      ocrEngine.value = ImageOcrEngine.appleLiveText;
      translatorEngine.value = ImageTranslationEngine.appleOnDevice;
      await saveBeanConfig();
    }
  }

  /// Switch back to the custom mode (Tesseract / PaddleOCR + API).
  Future<void> switchToCustomMode() async {
    final bool changed =
        ocrEngine.value != lastCustomOcrEngine.value ||
        translatorEngine.value != ImageTranslationEngine.api;
    if (ocrEngine.value != lastCustomOcrEngine.value) {
      ocrEngine.value = lastCustomOcrEngine.value;
    }
    translatorEngine.value = ImageTranslationEngine.api;
    if (changed) {
      await saveBeanConfig();
    }
  }

  Future<void> save({
    required ImageOcrEngine ocrEngine,
    required String appleLiveTextLanguage,
    required ImageTranslationProvider translatorProvider,
    required String translatorEndpoint,
    required String translatorApiKey,
    required String translatorModel,
    required String targetLanguage,
    bool? enableThinking,
    bool? translateSubsequentPages,
  }) async {
    log.debug('Save image translation settings');
    this.ocrEngine.value = ocrEngine;
    this.appleLiveTextLanguage.value = appleLiveTextLanguage.trim().isEmpty
        ? 'auto'
        : appleLiveTextLanguage.trim();
    this.translatorProvider.value = translatorProvider;
    this.translatorEndpoint.value = translatorEndpoint.trim().isEmpty
        ? null
        : translatorEndpoint.trim();
    this.translatorApiKey.value = translatorApiKey.trim().isEmpty
        ? null
        : translatorApiKey.trim();
    this.translatorModel.value = translatorModel.trim();
    this.targetLanguage.value = targetLanguage.trim().isEmpty
        ? '简体中文'
        : targetLanguage.trim();
    if (enableThinking != null) {
      this.enableThinking.value = enableThinking;
    }
    if (translateSubsequentPages != null) {
      this.translateSubsequentPages.value = translateSubsequentPages;
    }
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

  Future<void> saveAutoTranslateGalleryText(bool value) async {
    autoTranslateGalleryText.value = value;
    await saveBeanConfig();
  }

  Future<void> saveTranslatorModel(String value) async {
    translatorModel.value = value.trim().isEmpty
        ? 'gpt-4.1-mini'
        : value.trim();
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

  Future<void> saveAppleLiveTextUseThirdPartyApi(bool value) async {
    appleLiveTextUseThirdPartyApi.value = value;
    translatorEngine.value = value
        ? ImageTranslationEngine.api
        : ImageTranslationEngine.appleOnDevice;
    await saveBeanConfig();
  }

  Future<void> saveTranslatorEngine(ImageTranslationEngine value) async {
    translatorEngine.value = value;
    appleLiveTextUseThirdPartyApi.value = value == ImageTranslationEngine.api;
    await saveBeanConfig();
  }

  Future<void> saveLocalModelId(String value) async {
    if (value.trim().isEmpty) return;
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
