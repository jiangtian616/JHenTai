import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';

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
  late String _model;
  late String _appleLiveTextLanguage;
  late bool _appleLiveTextUseApi;
  late String _targetLanguage;
  late bool _enableThinking;
  late bool _translateSubsequentPages;

  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    _ocrEngine = imageTranslationSetting.ocrEngine.value;
    _model = imageTranslationSetting.translatorModel.value;
    _appleLiveTextLanguage =
        imageTranslationSetting.appleLiveTextLanguage.value;
    _appleLiveTextUseApi =
        imageTranslationSetting.appleLiveTextUseThirdPartyApi.value;
    _targetLanguage = imageTranslationSetting.targetLanguage.value;
    _enableThinking = imageTranslationSetting.enableThinking.value;
    _translateSubsequentPages =
        imageTranslationSetting.translateSubsequentPages.value;
    _availableModels = [_model];
    _fetchModels();
  }

  @override
  Widget build(BuildContext context) {
    final bool appleMode = _ocrEngine == ImageOcrEngine.appleLiveText;
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
                    child: Text('imageTextTranslation'.tr,
                        style: Theme.of(context).textTheme.titleLarge)),
                EHAppleIconButton(
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (!appleMode) ...[
                  _buildModel(),
                  _buildEnableThinking(),
                  _buildOcrEngine(),
                ] else if (_appleLiveTextUseApi) ...[
                  _buildModel(),
                  _buildEnableThinking(),
                ],
                if (appleMode) _buildOcrLanguage(),
                _buildTargetLanguage(),
                if (appleMode) _buildAppleLiveTextUseApi(),
                if (appleMode && !_appleLiveTextUseApi)
                  _buildOnDeviceTranslationHint(),
                _buildTranslateScope(),
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
        items: _availableModels
            .map((model) => DropdownMenuItem(value: model, child: Text(model)))
            .toList(),
      ),
    );
  }

  Widget _buildEnableThinking() {
    return EHAppleSwitchListTile(
      title: Text('imageTranslationEnableThinking'.tr),
      subtitle: Text('imageTranslationEnableThinkingHint'.tr,
          style: const TextStyle(fontSize: 12)),
      value: _enableThinking,
      onChanged: (value) {
        setState(() => _enableThinking = value);
        imageTranslationSetting.saveEnableThinking(value);
      },
    );
  }

  Widget _buildAppleLiveTextUseApi() {
    return EHAppleSwitchListTile(
      title: Text('imageTranslationAppleLiveTextUseApi'.tr),
      subtitle: Text('imageTranslationAppleLiveTextUseApiHint'.tr,
          style: const TextStyle(fontSize: 12)),
      value: _appleLiveTextUseApi,
      onChanged: (value) {
        setState(() => _appleLiveTextUseApi = value);
        imageTranslationSetting.saveAppleLiveTextUseThirdPartyApi(value);
      },
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
            child: Text('imageTranslationAppleLiveTextOnDeviceHint'.tr,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrEngine() {
    return _dropdownRow(
      'imageTranslationOcrEngine'.tr,
      EHCodexStyleDropdown<ImageOcrEngine>(
        value: _ocrEngine,
        onChanged: (value) {
          final ImageOcrEngine next = value!;
          final bool wasApple =
              _ocrEngine == ImageOcrEngine.appleLiveText;
          setState(() => _ocrEngine = next);
          if (next == ImageOcrEngine.appleLiveText) {
            imageTranslationSetting.switchToAppleLiveTextMode();
          } else if (wasApple) {
            imageTranslationSetting.switchToCustomMode();
          } else {
            imageTranslationSetting.saveOcrEngine(next);
          }
        },
        items: [
          DropdownMenuItem(
              value: ImageOcrEngine.onnx,
              child: Text('imageTranslationOcrEngineOnnx'.tr)),
          DropdownMenuItem(
              value: ImageOcrEngine.appleLiveText,
              child: Text('imageTranslationOcrEngineAppleLiveText'.tr)),
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
          imageTranslationSetting
              .saveAppleLiveTextLanguage(_appleLiveTextLanguage);
        },
        items: [
          ..._appleLanguageOptions.map((option) =>
              DropdownMenuItem(value: option.code, child: Text(option.label))),
          if (!_appleLanguageOptions
              .any((option) => option.code == _appleLiveTextLanguage))
            DropdownMenuItem(
                value: _appleLiveTextLanguage,
                child: Text(_appleLiveTextLanguage)),
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
          ..._targetLanguageOptions.map((language) =>
              DropdownMenuItem(value: language, child: Text(language))),
          if (!_targetLanguageOptions.contains(_targetLanguage))
            DropdownMenuItem(
                value: _targetLanguage, child: Text(_targetLanguage)),
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
              value: false, child: Text('imageTranslationScopeCurrent'.tr)),
          DropdownMenuItem(
              value: true, child: Text('imageTranslationScopeSubsequent'.tr)),
        ],
      ),
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
