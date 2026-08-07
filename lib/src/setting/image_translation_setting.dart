import 'dart:convert';

import 'package:get/get.dart';

import '../enum/config_enum.dart';
import '../service/jh_service.dart';
import '../service/log.dart';

ImageTranslationSetting imageTranslationSetting = ImageTranslationSetting();

enum ImageTranslationProvider { openAICompatible, anthropic }

enum OcrModelSource { giteeMirror, githubOfficial }

enum ImageOcrEngine { tesseract, paddleOcr, paddleOcrVl16 }

class ImageTranslationSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  final RxString ocrExecutable = 'tesseract'.obs;
  final Rx<ImageOcrEngine> ocrEngine = ImageOcrEngine.tesseract.obs;
  final RxString paddleOcrExecutable = 'paddleocr'.obs;
  final RxString paddleOcrLanguage = 'japan'.obs;
  final RxString ocrLanguage = 'jpn+eng'.obs;
  final RxnString ocrDataDirectory = RxnString();
  final Rx<OcrModelSource> ocrModelSource = OcrModelSource.giteeMirror.obs;
  final Rx<ImageTranslationProvider> translatorProvider =
      ImageTranslationProvider.openAICompatible.obs;
  final RxnString translatorEndpoint = RxnString();
  final RxnString translatorApiKey = RxnString();
  final RxString translatorModel = 'gpt-4.1-mini'.obs;
  final RxString targetLanguage = '简体中文'.obs;

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
  }

  @override
  String toConfigString() => jsonEncode({
        'ocrExecutable': ocrExecutable.value,
        'ocrEngine': ocrEngine.value.name,
        'paddleOcrExecutable': paddleOcrExecutable.value,
        'paddleOcrLanguage': paddleOcrLanguage.value,
        'ocrLanguage': ocrLanguage.value,
        'ocrDataDirectory': ocrDataDirectory.value,
        'ocrModelSource': ocrModelSource.value.name,
        'translatorProvider': translatorProvider.value.name,
        'translatorEndpoint': translatorEndpoint.value,
        'translatorApiKey': translatorApiKey.value,
        'translatorModel': translatorModel.value,
        'targetLanguage': targetLanguage.value,
      });

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> save({
    required String ocrExecutable,
    required ImageOcrEngine ocrEngine,
    required String paddleOcrExecutable,
    required String paddleOcrLanguage,
    required String ocrLanguage,
    required String ocrDataDirectory,
    required OcrModelSource ocrModelSource,
    required ImageTranslationProvider translatorProvider,
    required String translatorEndpoint,
    required String translatorApiKey,
    required String translatorModel,
    required String targetLanguage,
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
    await saveBeanConfig();
  }
}
