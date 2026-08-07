import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.label);

  final String code;
  final String label;
}

const List<_LanguageOption> _ocrLanguageOptions = [
  _LanguageOption('jpn+eng', '日语 + 英语'),
  _LanguageOption('jpn', '日语（横排）'),
  _LanguageOption('jpn_vert', '日语（竖排）'),
  _LanguageOption('chi_sim', '简体中文'),
  _LanguageOption('chi_tra', '繁体中文'),
  _LanguageOption('eng', '英语'),
  _LanguageOption('kor', '韩语'),
  _LanguageOption('chi_sim+eng', '简中 + 英语'),
  _LanguageOption('chi_tra+eng', '繁中 + 英语'),
];

const List<_LanguageOption> _paddleLanguageOptions = [
  _LanguageOption('japan', '日本語'),
  _LanguageOption('ch', '简体中文'),
  _LanguageOption('chinese_cht', '繁體中文'),
  _LanguageOption('en', 'English'),
  _LanguageOption('korean', '한국어'),
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

/// Quick image-translation config panel, used by the read page toolbar button.
/// Shows the translation API settings plus OCR options and can optionally
/// translate the current page directly.
class ImageTranslationConfigSheet extends StatefulWidget {
  /// Called when the user taps "translate current page". The sheet pops itself
  /// before invoking this callback.
  final VoidCallback? onTranslateCurrentImage;

  /// When provided (desktop/tablet drawer), tapping "advanced settings" pushes
  /// the full settings page inside the drawer's own navigator instead of
  /// closing the panel and routing to the hidden right pane.
  final VoidCallback? onOpenAdvancedSettings;

  /// Called when the close button is tapped. When null, the sheet pops itself.
  final VoidCallback? onClose;

  const ImageTranslationConfigSheet(
      {super.key,
      this.onTranslateCurrentImage,
      this.onOpenAdvancedSettings,
      this.onClose});

  @override
  State<ImageTranslationConfigSheet> createState() =>
      _ImageTranslationConfigSheetState();
}

class _ImageTranslationConfigSheetState
    extends State<ImageTranslationConfigSheet> {
  late ImageTranslationProvider _provider;
  late ImageOcrEngine _ocrEngine;
  late OcrModelSource _ocrModelSource;
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late String _targetLanguage;
  late String _ocrLanguage;
  late String _paddleLanguage;

  bool _fetchingModels = false;
  bool _preparingPaddle = false;
  String? _paddleStage;

  @override
  void initState() {
    super.initState();
    _provider = imageTranslationSetting.translatorProvider.value;
    _ocrEngine = imageTranslationSetting.ocrEngine.value;
    _ocrModelSource = imageTranslationSetting.ocrModelSource.value;
    _endpointController = TextEditingController(
        text: imageTranslationSetting.translatorEndpoint.value ?? '');
    _apiKeyController = TextEditingController(
        text: imageTranslationSetting.translatorApiKey.value ?? '');
    _modelController = TextEditingController(
        text: imageTranslationSetting.translatorModel.value);
    _targetLanguage = imageTranslationSetting.targetLanguage.value;
    _ocrLanguage = imageTranslationSetting.ocrLanguage.value;
    _paddleLanguage = imageTranslationSetting.paddleOcrLanguage.value;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.of(context).orientation == Orientation.portrait)
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: Text('imageTextTranslation'.tr,
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Text('imageTranslationTranslatorSection'.tr,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('imageTranslationApiTestHint'.tr,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _dropdownRow(
                  'imageTranslationProvider'.tr,
                  EHCodexStyleDropdown<ImageTranslationProvider>(
                    value: _provider,
                    onChanged: (value) => setState(() {
                      _provider = value!;
                      _endpointController.text =
                          _provider == ImageTranslationProvider.anthropic
                              ? 'https://api.anthropic.com/v1'
                              : 'https://api.openai.com/v1';
                    }),
                    items: [
                      DropdownMenuItem(
                          value: ImageTranslationProvider.openAICompatible,
                          child: Text('imageTranslationOpenAICompatible'.tr)),
                      const DropdownMenuItem(
                          value: ImageTranslationProvider.anthropic,
                          child: Text('Anthropic Messages API')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                    controller: _endpointController,
                    label: 'imageTranslationApiBaseUrl'.tr,
                    keyboardType: TextInputType.url),
                _field(
                    controller: _apiKeyController,
                    label: 'apiKey'.tr,
                    obscureText: true),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                          controller: _modelController,
                          label: 'imageTranslationModel'.tr,
                          hint: 'gpt-4.1-mini'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _fetchingModels ? null : _fetchModels,
                      icon: _fetchingModels
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_sync_outlined, size: 18),
                      label: Text('imageTranslationTestAndFetchModels'.tr),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _dropdownRow(
                  'imageTranslationTargetLanguage'.tr,
                  EHCodexStyleDropdown<String>(
                    value: _targetLanguage,
                    onChanged: (value) =>
                        setState(() => _targetLanguage = value!),
                    items: [
                      ..._targetLanguageOptions.map((language) =>
                          DropdownMenuItem(
                              value: language, child: Text(language))),
                      if (!_targetLanguageOptions.contains(_targetLanguage))
                        DropdownMenuItem(
                            value: _targetLanguage,
                            child: Text(_targetLanguage)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('imageTranslationOcrSection'.tr,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('imageTranslationOcrHint'.tr,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _dropdownRow(
                  'imageTranslationOcrEngine'.tr,
                  EHCodexStyleDropdown<ImageOcrEngine>(
                    value: _ocrEngine,
                    onChanged: (engine) => setState(() => _ocrEngine = engine!),
                    items: const [
                      DropdownMenuItem(
                          value: ImageOcrEngine.tesseract,
                          child: Text('Tesseract')),
                      DropdownMenuItem(
                          value: ImageOcrEngine.paddleOcr,
                          child: Text('PaddleOCR (PP-OCRv6)')),
                      DropdownMenuItem(
                          value: ImageOcrEngine.paddleOcrVl16,
                          child: Text('PaddleOCR-VL-1.6')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_ocrEngine == ImageOcrEngine.tesseract) ...[
                  _dropdownRow(
                    'imageTranslationOcrLanguage'.tr,
                    EHCodexStyleDropdown<String>(
                      value: _ocrLanguage,
                      onChanged: (value) =>
                          setState(() => _ocrLanguage = value!),
                      items: [
                        ..._ocrLanguageOptions.map((option) => DropdownMenuItem(
                            value: option.code, child: Text(option.label))),
                        if (!_ocrLanguageOptions
                            .any((option) => option.code == _ocrLanguage))
                          DropdownMenuItem(
                              value: _ocrLanguage, child: Text(_ocrLanguage)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _dropdownRow(
                    'imageTranslationOcrModelSource'.tr,
                    EHCodexStyleDropdown<OcrModelSource>(
                      value: _ocrModelSource,
                      onChanged: (value) =>
                          setState(() => _ocrModelSource = value!),
                      items: [
                        DropdownMenuItem(
                            value: OcrModelSource.giteeMirror,
                            child: Text('imageTranslationGiteeMirror'.tr)),
                        DropdownMenuItem(
                            value: OcrModelSource.githubOfficial,
                            child: Text('imageTranslationGithubOfficial'.tr)),
                      ],
                    ),
                  ),
                ] else
                  _dropdownRow(
                    'imageTranslationPaddleLanguage'.tr,
                    EHCodexStyleDropdown<String>(
                      value: _paddleLanguage,
                      onChanged: (value) =>
                          setState(() => _paddleLanguage = value!),
                      items: [
                        ..._paddleLanguageOptions.map((option) =>
                            DropdownMenuItem(
                                value: option.code, child: Text(option.label))),
                        if (!_paddleLanguageOptions
                            .any((option) => option.code == _paddleLanguage))
                          DropdownMenuItem(
                              value: _paddleLanguage,
                              child: Text(_paddleLanguage)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text('imageTranslationPaddleRuntimePath'.tr +
                    ': ${imageTranslationService.paddleRuntimePath()}'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _preparingPaddle ? null : _preparePaddle,
                  icon: _preparingPaddle
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_for_offline_outlined),
                  label:
                      Text(_paddleStage ?? 'imageTranslationPreparePaddle'.tr),
                ),
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
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onTranslateCurrentImage!();
                    },
                    icon: const Icon(Icons.translate),
                    label: Text('translateImageText'.tr),
                  ),
                TextButton(
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
                TextButton(
                  onPressed: _save,
                  child: Text('saveSetting'.tr),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
      {required TextEditingController controller,
      required String label,
      String? hint,
      bool obscureText = false,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EHAppleTextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !obscureText,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _dropdownRow(String label, Widget dropdown) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
      if (!models.contains(_modelController.text.trim())) {
        _modelController.text = models.first;
      }
      setState(() {});
      toast('imageTranslationApiTestSuccess'
          .trParams({'count': '${models.length}'}));
    } on ImageTranslationException catch (error) {
      toast('imageTranslationApiTestFailed'.trParams({'error': error.code}));
    } catch (_) {
      toast(
          'imageTranslationApiTestFailed'.trParams({'error': 'NETWORK_ERROR'}));
    } finally {
      if (mounted) {
        setState(() => _fetchingModels = false);
      }
    }
  }

  Future<void> _save() async {
    if (_modelController.text.trim().isEmpty) {
      toast('imageTranslationFetchModelsFirst'.tr);
      return;
    }
    await imageTranslationSetting.save(
      ocrExecutable: imageTranslationSetting.ocrExecutable.value,
      ocrEngine: _ocrEngine,
      paddleOcrExecutable: imageTranslationSetting.paddleOcrExecutable.value,
      paddleOcrLanguage: _paddleLanguage,
      ocrLanguage: _ocrLanguage,
      ocrDataDirectory: imageTranslationSetting.ocrDataDirectory.value ?? '',
      ocrModelSource: _ocrModelSource,
      translatorProvider: _provider,
      translatorEndpoint: _endpointController.text,
      translatorApiKey: _apiKeyController.text,
      translatorModel: _modelController.text,
      targetLanguage: _targetLanguage,
    );
    if (mounted) {
      Navigator.of(context).pop();
      toast('saveSuccess'.tr);
    }
  }

  Future<void> _preparePaddle() async {
    setState(() => _preparingPaddle = true);
    try {
      await imageTranslationService.preparePaddleRuntime(
        downloadVl16: _ocrEngine == ImageOcrEngine.paddleOcrVl16,
        onStage: (stage) {
          if (mounted) setState(() => _paddleStage = stage);
        },
      );
      if (mounted) {
        toast('imageTranslationPaddleReady'.tr);
      }
    } on ImageTranslationException catch (error) {
      if (mounted) {
        toast('imageTranslationPaddlePrepareFailed'
            .trParams({'error': error.code}));
      }
    } finally {
      if (mounted) {
        setState(() {
          _preparingPaddle = false;
          _paddleStage = null;
        });
      }
    }
  }
}
