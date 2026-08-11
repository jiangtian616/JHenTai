import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/engine/context_translation_contract.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/image_inpainting_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:jhentai/src/widget/gguf_model_manager.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.label);

  final String code;
  final String label;
}

const List<_LanguageOption> _appleLanguageOptions = [
  _LanguageOption('auto', '自动检测 / Auto'),
  _LanguageOption('ja-JP', '日本語'),
  _LanguageOption('en-US', 'English'),
  _LanguageOption('ja-JP,en-US', '日本語 + English'),
  _LanguageOption('zh-Hans', '简体中文'),
  _LanguageOption('zh-Hant', '繁體中文'),
  _LanguageOption('ko-KR', '한국어'),
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

/// Simple read-page translation panel. Only exposes the frequently used
/// choices; API/OCR installation details stay in the full settings page.
class ImageTranslationConfigSheet extends StatefulWidget {
  final VoidCallback? onTranslateCurrentImage;
  final VoidCallback? onOpenAdvancedSettings;
  final VoidCallback? onClose;

  const ImageTranslationConfigSheet({
    super.key,
    this.onTranslateCurrentImage,
    this.onOpenAdvancedSettings,
    this.onClose,
  });

  @override
  State<ImageTranslationConfigSheet> createState() =>
      _ImageTranslationConfigSheetState();
}

class _ImageTranslationConfigSheetState
    extends State<ImageTranslationConfigSheet> {
  late ImageOcrEngine _ocrEngine;
  late ImageTranslationEngine _translatorEngine;
  late String _model;
  late String _appleLiveTextLanguage;
  late String _targetLanguage;
  late bool _enableThinking;
  late bool _translateSubsequentPages;
  late ImageProcessingDisplayMode _imageProcessingDisplayMode;

  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _ocrEngine = imageTranslationSetting.ocrEngine.value;
    _translatorEngine = imageTranslationSetting.translatorEngine.value;
    _model = imageTranslationSetting.translatorModel.value;
    _appleLiveTextLanguage =
        imageTranslationSetting.appleLiveTextLanguage.value;
    _targetLanguage = imageTranslationSetting.targetLanguage.value;
    _enableThinking = imageTranslationSetting.enableThinking.value;
    _translateSubsequentPages =
        imageTranslationSetting.translateSubsequentPages.value;
    _imageProcessingDisplayMode =
        imageTranslationSetting.imageProcessingDisplayMode.value;
    _availableModels = [_model];
    if (_translatorEngine == ImageTranslationEngine.api) {
      _fetchModels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool appleOcr = _ocrEngine == ImageOcrEngine.appleLiveText;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'imageTextTranslation'.tr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                EHAppleIconButton(
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _buildOcrEngine(),
                if (appleOcr) _buildOcrLanguage(),
                _buildTranslatorEngine(),
                if (_translatorEngine == ImageTranslationEngine.api) ...[
                  _buildModel(),
                  _buildEnableThinking(),
                ],
                if (_translatorEngine == ImageTranslationEngine.appleOnDevice)
                  _buildOnDeviceTranslationHint(),
                if (_translatorEngine == ImageTranslationEngine.localGguf)
                  _buildLocalTranslationSettings(),
                _buildTargetLanguage(),
                _buildTranslateScope(),
                _buildContextBatchSize(),
                _buildImageProcessingMode(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onTranslateCurrentImage != null)
                  EHAppleFilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onTranslateCurrentImage!();
                    },
                    icon: const Icon(Icons.translate),
                    label: Text('translateImageText'.tr),
                  ),
                EHAppleTextButton(
                  onPressed: () {
                    if (widget.onOpenAdvancedSettings != null) {
                      widget.onOpenAdvancedSettings!();
                    } else {
                      Navigator.of(context).pop();
                      toRoute(Routes.imageTranslation);
                    }
                  },
                  child: Text('advancedSetting'.tr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModel() {
    return _dropdownRow(
      'imageTranslationModel'.tr,
      EHCodexStyleDropdown<String>(
        value: _model,
        onChanged: (value) {
          setState(() => _model = value!);
          imageTranslationSetting.saveTranslatorModel(_model);
        },
        items:
            _availableModels
                .map(
                  (model) => DropdownMenuItem(value: model, child: Text(model)),
                )
                .toList(),
      ),
    );
  }

  Widget _buildEnableThinking() {
    return EHAppleSwitchListTile(
      title: Text('imageTranslationEnableThinking'.tr),
      subtitle: Text(
        'imageTranslationEnableThinkingHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
      value: _enableThinking,
      onChanged: (value) {
        setState(() => _enableThinking = value);
        imageTranslationSetting.saveEnableThinking(value);
      },
    );
  }

  Widget _buildImageProcessingMode() {
    return _dropdownRow(
      'imageTranslationImageProcessingMode'.tr,
      EHCodexStyleDropdown<ImageProcessingDisplayMode>(
        key: const ValueKey('image-translation-image-processing-mode'),
        value: _imageProcessingDisplayMode,
        onChanged: (ImageProcessingDisplayMode? value) {
          if (value == null) {
            return;
          }
          setState(() => _imageProcessingDisplayMode = value);
          imageTranslationSetting.saveImageProcessingDisplayMode(value);
          imageInpaintingService.setDisplayMode(value);
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
    );
  }

  Widget _buildOnDeviceTranslationHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'imageTranslationAppleLiveTextOnDeviceHint'.tr,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalTranslationSettings() {
    return GgufModelManagerPanel(
      selectedModelId: imageTranslationSetting.localModelId.value,
      onSelectModel: (String modelId) {
        setState(() {});
        imageTranslationSetting.saveLocalModelId(modelId);
      },
      llamaServerPath: imageTranslationSetting.localLlamaServerPath.value,
      onSaveLlamaServerPath: imageTranslationSetting.saveLocalLlamaServerPath,
    );
  }

  Widget _buildOcrEngine() {
    return _dropdownRow(
      'imageTranslationOcrEngine'.tr,
      EHCodexStyleDropdown<ImageOcrEngine>(
        key: const ValueKey('image-translation-ocr-engine'),
        value: _ocrEngine,
        onChanged: (value) {
          final ImageOcrEngine next = value!;
          setState(() => _ocrEngine = next);
          imageTranslationSetting.saveOcrEngine(next);
        },
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

  Widget _buildTranslatorEngine() {
    return _dropdownRow(
      'imageTranslationTranslatorEngine'.tr,
      EHCodexStyleDropdown<ImageTranslationEngine>(
        key: const ValueKey('image-translation-translator-engine'),
        value: _translatorEngine,
        onChanged: (value) {
          final ImageTranslationEngine next = value!;
          setState(() => _translatorEngine = next);
          imageTranslationSetting.saveTranslatorEngine(next);
          if (next == ImageTranslationEngine.api) {
            _fetchModels();
          }
        },
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

  Widget _buildOcrLanguage() {
    return _dropdownRow(
      'imageTranslationAppleLiveTextLanguage'.tr,
      EHCodexStyleDropdown<String>(
        value: _appleLiveTextLanguage,
        onChanged: (value) {
          setState(() => _appleLiveTextLanguage = value!);
          imageTranslationSetting.saveAppleLiveTextLanguage(
            _appleLiveTextLanguage,
          );
        },
        items: [
          ..._appleLanguageOptions.map(
            (option) =>
                DropdownMenuItem(value: option.code, child: Text(option.label)),
          ),
          if (!_appleLanguageOptions.any(
            (option) => option.code == _appleLiveTextLanguage,
          ))
            DropdownMenuItem(
              value: _appleLiveTextLanguage,
              child: Text(_appleLiveTextLanguage),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetLanguage() {
    return _dropdownRow(
      'imageTranslationTargetLanguage'.tr,
      EHCodexStyleDropdown<String>(
        value: _targetLanguage,
        onChanged: (value) {
          setState(() => _targetLanguage = value!);
          imageTranslationSetting.saveTargetLanguage(_targetLanguage);
        },
        items: [
          ..._targetLanguageOptions.map(
            (language) =>
                DropdownMenuItem(value: language, child: Text(language)),
          ),
          if (!_targetLanguageOptions.contains(_targetLanguage))
            DropdownMenuItem(
              value: _targetLanguage,
              child: Text(_targetLanguage),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslateScope() {
    return _dropdownRow(
      'imageTranslationTranslateScope'.tr,
      EHCodexStyleDropdown<bool>(
        value: _translateSubsequentPages,
        onChanged: (value) {
          final bool next = value!;
          setState(() => _translateSubsequentPages = next);
          imageTranslationSetting.saveTranslateSubsequentPages(next);
        },
        items: [
          DropdownMenuItem(
            value: false,
            child: Text('imageTranslationScopeCurrent'.tr),
          ),
          DropdownMenuItem(
            value: true,
            child: Text('imageTranslationScopeSubsequent'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBatchSize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdownRow(
          'imageTranslationContextPages'.tr,
          EHCodexStyleDropdown<ContextBatchSize>(
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
                        _translatorEngine !=
                            ImageTranslationEngine.appleOnDevice ||
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
        ),
        if (_translatorEngine == ImageTranslationEngine.appleOnDevice)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'imageTranslationContextAppleUnsupported'.tr,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _dropdownRow(String label, Widget dropdown) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          dropdown,
        ],
      ),
    );
  }

  Future<void> _fetchModels() async {
    try {
      final List<String> models = await imageTranslationService.fetchModels(
        provider: imageTranslationSetting.translatorProvider.value,
        apiBaseUrl: imageTranslationSetting.translatorEndpoint.value ?? '',
        apiKey: imageTranslationSetting.translatorApiKey.value ?? '',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels =
            models.contains(_model) ? models : [_model, ...models];
      });
    } catch (_) {
      // Keep the saved model; endpoint/key may not be configured here.
    }
  }
}
