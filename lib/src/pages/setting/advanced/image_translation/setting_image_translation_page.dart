import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/image_inpainting_service.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/inference_setting.dart';
import 'package:jhentai/src/utils/app_icons.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:jhentai/src/widget/onnx_model_tile.dart';

class _OcrModel {
  const _OcrModel(this.code, this.label);

  final String code;
  final String label;
}

const List<_OcrModel> _appleLanguageOptions = [
  _OcrModel('auto', '自动检测 / Auto'),
  _OcrModel('ja-JP', '日本語'),
  _OcrModel('en-US', 'English'),
  _OcrModel('ja-JP,en-US', '日本語 + English'),
  _OcrModel('zh-Hans', '简体中文'),
  _OcrModel('zh-Hant', '繁體中文'),
  _OcrModel('ko-KR', '한국어'),
];

const List<String> _targetLanguageOptions = [
  '简体中文',
  '繁體中文',
  'English',
  '日本語',
  '한국어',
  'Português',
  'Русский',
];

class SettingImageTranslationPage extends StatefulWidget {
  const SettingImageTranslationPage({super.key});

  @override
  State<SettingImageTranslationPage> createState() =>
      _SettingImageTranslationPageState();
}

class _SettingImageTranslationPageState
    extends State<SettingImageTranslationPage> {
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late String _appleLiveTextLanguage;
  late String _targetLanguage;
  late ImageTranslationProvider _provider;
  late ImageOcrEngine _ocrEngine;
  late ImageTranslationEngine _translatorEngine;
  List<String> _availableModels = [];
  bool _fetchingModels = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(
      text: imageTranslationSetting.translatorEndpoint.value ?? '',
    );
    _apiKeyController = TextEditingController(
      text: imageTranslationSetting.translatorApiKey.value ?? '',
    );
    _appleLiveTextLanguage =
        imageTranslationSetting.appleLiveTextLanguage.value;
    _targetLanguage = imageTranslationSetting.targetLanguage.value;
    _provider = imageTranslationSetting.translatorProvider.value;
    _ocrEngine = imageTranslationSetting.ocrEngine.value;
    _translatorEngine = imageTranslationSetting.translatorEngine.value;
    final String savedModel = imageTranslationSetting.translatorModel.value;
    if (savedModel.isNotEmpty) {
      _availableModels = [savedModel];
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('imageTextTranslation'.tr),
        actions: [
          EHAppleTextButton(onPressed: _save, child: Text('saveSetting'.tr)),
        ],
      ),
      body: EHAppleSettingsListView(
        safeArea: true,
        groups: [
          EHAppleSettingsGroup(
            title: 'imageTranslationMethodSection'.tr,
            children: [
              _buildOcrEngineSelector(),
              _buildTranslatorEngineSelector(),
            ],
          ),
          EHAppleSettingsGroup(
            title: 'imageTranslationOcrSection'.tr,
            children: [
              if (_ocrEngine == ImageOcrEngine.appleLiveText) ...[
                _buildAppleLiveTextLanguage(),
                _buildAppleLiveTextAvailability(),
              ] else if (_ocrEngine == ImageOcrEngine.onnx) ...[
                _buildOnnxLanguage(),
                _buildOnnxModelPicker(),
                _buildOnnxModelTile(),
                _buildOnnxRuntime(),
              ] else
                ListTile(title: Text('imageTranslationOcrEngineMangaOcr'.tr)),
            ],
          ),
          EHAppleSettingsGroup(
            title: 'imageTranslationTranslatorSection'.tr,
            children: [
              _buildTargetLanguage(),
              _buildContextBatchSize(),
              if (_translatorEngine == ImageTranslationEngine.api) ...[
                _buildProvider(),
                _buildEndpoint(),
                _buildApiKey(),
                _buildFetchModels(),
                _buildModel(),
                _buildEnableThinking(),
              ] else if (_translatorEngine ==
                  ImageTranslationEngine.appleOnDevice) ...[
                _buildOnDeviceTranslationHint(),
                _buildAutoTranslateGalleryText(),
              ] else
                _buildLocalTranslationHint(),
            ],
          ),
          EHAppleSettingsGroup(
            title: 'imageTranslationImageProcessingSection'.tr,
            children: [
              _buildImageProcessingDisplayMode(),
              Obx(
                () =>
                    imageTranslationSetting.imageProcessingDisplayMode.value ==
                            ImageProcessingDisplayMode
                                .repairedBackgroundEmbeddedText
                        ? Column(
                          children: [
                            OnnxModelTile(
                              manifestId: OnnxModelStore.ctdDetectionManifestId,
                              title: 'imageTranslationCtdModel'.tr,
                            ),
                            OnnxModelTile(
                              manifestId: OnnxModelStore.miganInpaintManifestId,
                              title: 'imageTranslationMiganModel'.tr,
                            ),
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: Text(
                                'imageTranslationCtdLicenseNotice'.tr,
                              ),
                              subtitle: Text(
                                'imageTranslationCtdFallbackHint'.tr,
                              ),
                            ),
                          ],
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProvider() {
    return ListTile(
      title: Text('imageTranslationProvider'.tr),
      trailing: EHCodexStyleDropdown<ImageTranslationProvider>(
        value: _provider,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged:
            (value) => setState(() {
              _provider = value!;
              _availableModels = [];
              _endpointController.text =
                  _provider == ImageTranslationProvider.anthropic
                      ? 'https://api.anthropic.com/v1'
                      : 'https://api.openai.com/v1';
            }),
        items: [
          DropdownMenuItem(
            value: ImageTranslationProvider.openAICompatible,
            child: Text('imageTranslationOpenAICompatible'.tr),
          ),
          const DropdownMenuItem(
            value: ImageTranslationProvider.anthropic,
            child: Text('Anthropic Messages API'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageProcessingDisplayMode() {
    return Obx(
      () => ListTile(
        title: Text('imageTranslationImageProcessingMode'.tr),
        subtitle: Text(
          'imageTranslationImageProcessingHint'.tr,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: EHCodexStyleDropdown<ImageProcessingDisplayMode>(
          value: imageTranslationSetting.imageProcessingDisplayMode.value,
          onChanged: (ImageProcessingDisplayMode? value) {
            if (value != null) {
              imageTranslationSetting.saveImageProcessingDisplayMode(value);
              imageInpaintingService.setDisplayMode(value);
            }
          },
          items: <DropdownMenuItem<ImageProcessingDisplayMode>>[
            DropdownMenuItem(
              value: ImageProcessingDisplayMode.overlay,
              child: Text('imageTranslationDisplayOverlay'.tr),
            ),
            DropdownMenuItem(
              value: ImageProcessingDisplayMode.repairedBackgroundEmbeddedText,
              child: Text('imageTranslationDisplayCtdMigan'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpoint() {
    return ListTile(
      title: Text('imageTranslationApiBaseUrl'.tr),
      trailing: SizedBox(
        width: 240,
        child: EHAppleTextField(
          controller: _endpointController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            isDense: true,
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKey() {
    return ListTile(
      title: Text('apiKey'.tr),
      trailing: SizedBox(
        width: 180,
        child: EHAppleTextField(
          controller: _apiKeyController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            isDense: true,
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFetchModels() {
    return ListTile(
      title: Text('imageTranslationTestAndFetchModels'.tr),
      subtitle: Text(
        'imageTranslationApiTestHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
      trailing:
          _fetchingModels
              ? SizedBox(
                width: 20,
                height: 20,
                child:
                    ThemeConfig.isApple
                        ? const GlassProgressIndicator.circular(strokeWidth: 2)
                        : const CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.cloud_sync_outlined),
      onTap: _fetchingModels ? null : _fetchModels,
    );
  }

  Widget _buildModel() {
    final List<String> models =
        _availableModels.isEmpty
            ? [imageTranslationSetting.translatorModel.value]
            : _availableModels;
    return ListTile(
      title: Text('imageTranslationModel'.tr),
      subtitle:
          _availableModels.isEmpty
              ? Text(
                'imageTranslationFetchModelsFirst'.tr,
                style: const TextStyle(fontSize: 12),
              )
              : null,
      trailing: EHCodexStyleDropdown<String>(
        value:
            models.contains(imageTranslationSetting.translatorModel.value)
                ? imageTranslationSetting.translatorModel.value
                : models.first,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged:
            (model) => setState(
              () => imageTranslationSetting.translatorModel.value = model!,
            ),
        items:
            models
                .map(
                  (model) => DropdownMenuItem(value: model, child: Text(model)),
                )
                .toList(),
      ),
    );
  }

  Widget _buildTargetLanguage() {
    final List<String> options =
        _targetLanguageOptions.contains(_targetLanguage)
            ? _targetLanguageOptions
            : [..._targetLanguageOptions, _targetLanguage];
    return ListTile(
      title: Text('imageTranslationTargetLanguage'.tr),
      trailing: EHCodexStyleDropdown<String>(
        value: _targetLanguage,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) => setState(() => _targetLanguage = value!),
        items:
            options
                .map(
                  (language) =>
                      DropdownMenuItem(value: language, child: Text(language)),
                )
                .toList(),
      ),
    );
  }

  Widget _buildContextBatchSize() {
    return ListTile(
      title: Text('imageTranslationContextPages'.tr),
      subtitle:
          _translatorEngine == ImageTranslationEngine.appleOnDevice
              ? Text('imageTranslationContextAppleUnsupported'.tr)
              : null,
      trailing: EHCodexStyleDropdown<ContextBatchSize>(
        key: const ValueKey('image-translation-context-batch-size'),
        value:
            _translatorEngine == ImageTranslationEngine.appleOnDevice
                ? ContextBatchSize.one
                : imageTranslationSetting.contextBatchSize.value,
        onChanged: (value) {
          if (value != null &&
              (_translatorEngine != ImageTranslationEngine.appleOnDevice ||
                  value == ContextBatchSize.one)) {
            setState(() {
              imageTranslationSetting.contextBatchSize.value = value;
            });
            imageTranslationSetting.saveContextBatchSize(value);
          }
        },
        items: ContextBatchSize.values
            .map(
              (ContextBatchSize size) => DropdownMenuItem<ContextBatchSize>(
                value: size,
                enabled:
                    _translatorEngine != ImageTranslationEngine.appleOnDevice ||
                    size == ContextBatchSize.one,
                child: Text(
                  'imageTranslationContextPagesValue'.trParams({
                    'count': '${size.pageCount}',
                  }),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildEnableThinking() {
    return Obx(
      () => EHAppleSwitchListTile(
        title: Text('imageTranslationEnableThinking'.tr),
        subtitle: Text(
          'imageTranslationEnableThinkingHint'.tr,
          style: const TextStyle(fontSize: 12),
        ),
        value: imageTranslationSetting.enableThinking.value,
        onChanged: imageTranslationSetting.saveEnableThinking,
      ),
    );
  }

  Widget _buildAppleLiveTextLanguage() {
    final List<_OcrModel> options =
        _appleLanguageOptions.any(
              (option) => option.code == _appleLiveTextLanguage,
            )
            ? _appleLanguageOptions
            : [
              ..._appleLanguageOptions,
              _OcrModel(_appleLiveTextLanguage, _appleLiveTextLanguage),
            ];
    return ListTile(
      title: Text('imageTranslationAppleLiveTextLanguage'.tr),
      trailing: EHCodexStyleDropdown<String>(
        value: _appleLiveTextLanguage,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) async {
          if (value == null) {
            return;
          }
          setState(() => _appleLiveTextLanguage = value);
          await imageTranslationSetting.saveAppleLiveTextLanguage(value);
        },
        items:
            options
                .map(
                  (option) => DropdownMenuItem(
                    value: option.code,
                    child: Text(option.label),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildAppleLiveTextAvailability() {
    final bool available = Platform.isIOS || Platform.isMacOS;
    return ListTile(
      title: Text(
        available
            ? 'imageTranslationAppleLiveTextHint'.tr
            : 'imageTranslationAppleLiveTextUnavailable'.tr,
      ),
      trailing: Icon(
        available ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: available ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildOcrEngineSelector() {
    return ListTile(
      title: Text('imageTranslationOcrEngine'.tr),
      trailing: EHCodexStyleDropdown<ImageOcrEngine>(
        key: const ValueKey('image-translation-ocr-engine'),
        value: _ocrEngine,
        onChanged: (value) => setState(() => _ocrEngine = value!),
        items: [
          DropdownMenuItem(
            value: ImageOcrEngine.onnx,
            child: Text('imageTranslationOcrEngineOnnx'.tr),
          ),
          DropdownMenuItem(
            value: ImageOcrEngine.mangaOcr,
            child: Text('imageTranslationOcrEngineMangaOcr'.tr),
          ),
          DropdownMenuItem(
            value: ImageOcrEngine.appleLiveText,
            enabled: Platform.isIOS || Platform.isMacOS,
            child: Text('imageTranslationOcrEngineAppleLiveText'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslatorEngineSelector() {
    return ListTile(
      title: Text('imageTranslationTranslatorEngine'.tr),
      trailing: EHCodexStyleDropdown<ImageTranslationEngine>(
        key: const ValueKey('image-translation-translator-engine'),
        value: _translatorEngine,
        onChanged: (value) => setState(() => _translatorEngine = value!),
        items: [
          DropdownMenuItem(
            value: ImageTranslationEngine.api,
            child: Text('imageTranslationTranslatorEngineApi'.tr),
          ),
          DropdownMenuItem(
            value: ImageTranslationEngine.appleOnDevice,
            enabled: Platform.isIOS || Platform.isMacOS,
            child: Text('imageTranslationTranslatorEngineApple'.tr),
          ),
          DropdownMenuItem(
            value: ImageTranslationEngine.localGguf,
            child: Text('imageTranslationTranslatorEngineLocal'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildOnDeviceTranslationHint() {
    return ListTile(
      leading: const Icon(Icons.phonelink_erase, size: 20),
      title: Text(
        'imageTranslationAppleLiveTextOnDeviceHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildLocalTranslationHint() {
    return ListTile(
      leading: const Icon(Icons.memory_outlined, size: 20),
      title: Text(
        'imageTranslationLocalGgufHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildAutoTranslateGalleryText() {
    return Obx(
      () => EHAppleSwitchListTile(
        title: Text('autoTranslateGalleryText'.tr),
        subtitle: Text(
          'autoTranslateGalleryTextHint'.tr,
          style: const TextStyle(fontSize: 12),
        ),
        value: imageTranslationSetting.autoTranslateGalleryText.value,
        onChanged: imageTranslationSetting.saveAutoTranslateGalleryText,
      ),
    );
  }

  /// PP-OCRv6 small uses one multilingual dictionary and detects the script
  /// automatically; a language selector would only pretend to change models.
  Widget _buildOnnxLanguage() {
    return ListTile(
      title: Text('imageTranslationOcrLanguage'.tr),
      subtitle: Text(
        'inferenceOcrLanguageAuto'.tr,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// ONNX OCR 模型选择：列出所有 PP-OCRv6 档位，名字下方标注速度/体积/精度
  /// 差异，单选切换活动模型。
  Widget _buildOnnxModelPicker() {
    return Obx(() {
      final String active = imageTranslationSetting.onnxModelId.value;
      final List<OnnxModelManifest> models = OnnxModelStore.instance
          .manifestsOfKind('ocr');
      final bool activeKnown = models.any(
        (OnnxModelManifest model) => model.id == active,
      );
      return OnnxModelPicker(
        kind: 'ocr',
        activeId: activeKnown || models.isEmpty ? active : models.first.id,
        onSelect: imageTranslationSetting.saveOnnxModelId,
      );
    });
  }

  /// 活动 ONNX OCR 模型（PP-OCRv6）的下载/删除/状态。
  Widget _buildOnnxModelTile() {
    return Obx(() {
      final List<OnnxModelManifest> models = OnnxModelStore.instance
          .manifestsOfKind('ocr');
      final String active = imageTranslationSetting.onnxModelId.value;
      final bool activeKnown = models.any(
        (OnnxModelManifest model) => model.id == active,
      );
      final String manifestId =
          activeKnown || models.isEmpty ? active : models.first.id;
      return OnnxModelTile(
        manifestId: manifestId,
        title: 'inferenceOcrModel'.tr,
      );
    });
  }

  /// ONNX 端侧引擎的运行入口：显示当前生效后端与模型接入状态，跳转"推理后端"。
  Widget _buildOnnxRuntime() {
    return ListTile(
      title: Text('inferenceBackend'.tr),
      subtitle: Obx(
        () => Text(
          '${inferenceService.resolveBackendFor(InferenceDomain.ocr)?.label ?? 'inferenceDeviceNotDetected'.tr} · '
          '${inferenceService.ocrEngine.isReady ? 'inferenceModelReady'.tr : 'inferenceModelNotIntegrated'.tr}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      trailing: Icon(AppIcons.chevronRight).marginOnly(right: 4),
      onTap: () => toRoute(Routes.inference),
    );
  }

  Future<void> _fetchModels() async {
    setState(() => _fetchingModels = true);
    try {
      final List<String> models = await imageTranslationService.fetchModels(
        provider: _provider,
        apiBaseUrl: _endpointController.text,
        apiKey: _apiKeyController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = models;
        if (!models.contains(imageTranslationSetting.translatorModel.value)) {
          imageTranslationSetting.translatorModel.value = models.first;
        }
      });
      toast(
        'imageTranslationApiTestSuccess'.trParams({
          'count': '${models.length}',
        }),
      );
    } on ImageTranslationException catch (error) {
      toast('imageTranslationApiTestFailed'.trParams({'error': error.code}));
    } catch (_) {
      toast(
        'imageTranslationApiTestFailed'.trParams({'error': 'NETWORK_ERROR'}),
      );
    } finally {
      if (mounted) {
        setState(() => _fetchingModels = false);
      }
    }
  }

  Future<void> _save() async {
    final bool needsApi = _translatorEngine == ImageTranslationEngine.api;
    if (needsApi && _availableModels.isEmpty) {
      toast('imageTranslationFetchModelsFirst'.tr);
      return;
    }
    await imageTranslationSetting.save(
      ocrEngine: _ocrEngine,
      appleLiveTextLanguage: _appleLiveTextLanguage,
      translatorEngine: _translatorEngine,
      translatorProvider: _provider,
      translatorEndpoint: _endpointController.text,
      translatorApiKey: _apiKeyController.text,
      translatorModel: imageTranslationSetting.translatorModel.value,
      targetLanguage: _targetLanguage,
      enableThinking: imageTranslationSetting.enableThinking.value,
      translateSubsequentPages:
          imageTranslationSetting.translateSubsequentPages.value,
    );
    if (mounted) {
      toast('success'.tr);
    }
  }
}
