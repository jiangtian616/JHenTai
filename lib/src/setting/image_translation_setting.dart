import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '../enum/config_enum.dart';
import '../service/jh_service.dart';
import '../service/log.dart';

ImageTranslationSetting imageTranslationSetting = ImageTranslationSetting();

enum ImageTranslationProvider { openAICompatible, anthropic }

enum OcrModelSource { giteeMirror, githubOfficial }

enum ImageOcrEngine {
  tesseract,
  paddleOcr,
  paddleOcrVl16,

  /// 端侧 ONNX 推理（走统一"推理后端"入口，框架阶段尚未接入模型）。
  onnx,
  appleLiveText,
}

class ImageTranslationSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  final RxString ocrExecutable = 'tesseract'.obs;
  final Rx<ImageOcrEngine> ocrEngine = ImageOcrEngine.tesseract.obs;
  final RxString paddleOcrExecutable = 'paddleocr'.obs;
  final RxString paddleOcrLanguage = 'japan'.obs;
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
  /// the custom mode.
  final Rx<ImageOcrEngine> lastCustomOcrEngine = ImageOcrEngine.tesseract.obs;
  final RxString ocrLanguage = 'jpn+eng'.obs;
  final RxnString ocrDataDirectory = RxnString();
  final Rx<OcrModelSource> ocrModelSource = OcrModelSource.giteeMirror.obs;
  final Rx<ImageTranslationProvider> translatorProvider =
      ImageTranslationProvider.openAICompatible.obs;
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

  @override
  ConfigEnum get configEnum => ConfigEnum.imageTranslationSetting;

  @override
  void applyBeanConfig(String configString) {
    final Map<String, dynamic> config = jsonDecode(configString);
    ocrExecutable.value = config['ocrExecutable'] ?? ocrExecutable.value;
    ocrEngine.value = ImageOcrEngine.values.firstWhere(
        (engine) => engine.name == config['ocrEngine'],
        orElse: () => ocrEngine.value);
    paddleOcrExecutable.value =
        config['paddleOcrExecutable'] ?? paddleOcrExecutable.value;
    paddleOcrLanguage.value =
        config['paddleOcrLanguage'] ?? paddleOcrLanguage.value;
    appleLiveTextLanguage.value =
        config['appleLiveTextLanguage'] ?? appleLiveTextLanguage.value;
    appleLiveTextAutoSelected.value =
        config['appleLiveTextAutoSelected'] ?? appleLiveTextAutoSelected.value;
    appleLiveTextUseThirdPartyApi.value =
        config['appleLiveTextUseThirdPartyApi'] ??
            appleLiveTextUseThirdPartyApi.value;
    lastCustomOcrEngine.value = ImageOcrEngine.values.firstWhere(
        (engine) => engine.name == config['lastCustomOcrEngine'],
        orElse: () => lastCustomOcrEngine.value);
    ocrLanguage.value = config['ocrLanguage'] ?? ocrLanguage.value;
    ocrDataDirectory.value = config['ocrDataDirectory'];
    ocrModelSource.value = OcrModelSource.values.firstWhere(
        (source) => source.name == config['ocrModelSource'],
        orElse: () => ocrModelSource.value);
    translatorProvider.value = ImageTranslationProvider.values.firstWhere(
        (provider) => provider.name == config['translatorProvider'],
        orElse: () => translatorProvider.value);
    translatorEndpoint.value = config['translatorEndpoint'];
    translatorApiKey.value = config['translatorApiKey'];
    translatorModel.value = config['translatorModel'] ?? translatorModel.value;
    targetLanguage.value = config['targetLanguage'] ?? targetLanguage.value;
    enableThinking.value = config['enableThinking'] ?? enableThinking.value;
    translateSubsequentPages.value =
        config['translateSubsequentPages'] ?? translateSubsequentPages.value;
    autoTranslateGalleryText.value =
        config['autoTranslateGalleryText'] ?? autoTranslateGalleryText.value;
  }

  @override
  String toConfigString() => jsonEncode({
        'ocrExecutable': ocrExecutable.value,
        'ocrEngine': ocrEngine.value.name,
        'paddleOcrExecutable': paddleOcrExecutable.value,
        'paddleOcrLanguage': paddleOcrLanguage.value,
        'appleLiveTextLanguage': appleLiveTextLanguage.value,
        'appleLiveTextAutoSelected': appleLiveTextAutoSelected.value,
        'appleLiveTextUseThirdPartyApi': appleLiveTextUseThirdPartyApi.value,
        'lastCustomOcrEngine': lastCustomOcrEngine.value.name,
        'ocrLanguage': ocrLanguage.value,
        'ocrDataDirectory': ocrDataDirectory.value,
        'ocrModelSource': ocrModelSource.value.name,
        'translatorProvider': translatorProvider.value.name,
        'translatorEndpoint': translatorEndpoint.value,
        'translatorApiKey': translatorApiKey.value,
        'translatorModel': translatorModel.value,
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
      isAppleLiveTextMode && !appleLiveTextUseThirdPartyApi.value;

  /// Switch to the self-contained Apple Live Text mode, remembering the current
  /// custom engine so it can be restored later.
  Future<void> switchToAppleLiveTextMode() async {
    if (!isAppleLiveTextMode) {
      lastCustomOcrEngine.value = ocrEngine.value;
      ocrEngine.value = ImageOcrEngine.appleLiveText;
      await saveBeanConfig();
    }
  }

  /// Switch back to the custom mode (Tesseract / PaddleOCR + API).
  Future<void> switchToCustomMode() async {
    if (ocrEngine.value != lastCustomOcrEngine.value) {
      ocrEngine.value = lastCustomOcrEngine.value;
      await saveBeanConfig();
    }
  }

  Future<void> save({
    required String ocrExecutable,
    required ImageOcrEngine ocrEngine,
    required String paddleOcrExecutable,
    required String paddleOcrLanguage,
    required String appleLiveTextLanguage,
    required String ocrLanguage,
    required String ocrDataDirectory,
    required OcrModelSource ocrModelSource,
    required ImageTranslationProvider translatorProvider,
    required String translatorEndpoint,
    required String translatorApiKey,
    required String translatorModel,
    required String targetLanguage,
    bool? enableThinking,
    bool? translateSubsequentPages,
  }) async {
    log.debug('Save image translation settings');
    this.ocrExecutable.value =
        ocrExecutable.trim().isEmpty ? 'tesseract' : ocrExecutable.trim();
    this.ocrEngine.value = ocrEngine;
    this.paddleOcrExecutable.value = paddleOcrExecutable.trim().isEmpty
        ? 'paddleocr'
        : paddleOcrExecutable.trim();
    this.paddleOcrLanguage.value =
        paddleOcrLanguage.trim().isEmpty ? 'japan' : paddleOcrLanguage.trim();
    this.appleLiveTextLanguage.value = appleLiveTextLanguage.trim().isEmpty
        ? 'auto'
        : appleLiveTextLanguage.trim();
    this.ocrLanguage.value =
        ocrLanguage.trim().isEmpty ? 'jpn+eng' : ocrLanguage.trim();
    this.ocrDataDirectory.value =
        ocrDataDirectory.trim().isEmpty ? null : ocrDataDirectory.trim();
    this.ocrModelSource.value = ocrModelSource;
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
    translatorModel.value =
        value.trim().isEmpty ? 'gpt-4.1-mini' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveTargetLanguage(String value) async {
    targetLanguage.value = value.trim().isEmpty ? '简体中文' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveOcrLanguage(String value) async {
    ocrLanguage.value = value.trim().isEmpty ? 'jpn+eng' : value.trim();
    await saveBeanConfig();
  }

  Future<void> savePaddleOcrLanguage(String value) async {
    paddleOcrLanguage.value = value.trim().isEmpty ? 'japan' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveAppleLiveTextLanguage(String value) async {
    appleLiveTextLanguage.value = value.trim().isEmpty ? 'auto' : value.trim();
    await saveBeanConfig();
  }

  Future<void> saveAppleLiveTextUseThirdPartyApi(bool value) async {
    appleLiveTextUseThirdPartyApi.value = value;
    await saveBeanConfig();
  }

  Future<void> saveOcrEngine(ImageOcrEngine value) async {
    ocrEngine.value = value;
    await saveBeanConfig();
  }
}
