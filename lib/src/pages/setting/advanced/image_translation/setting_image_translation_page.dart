import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:jhentai/src/widget/paddle_cli_output.dart';

class _OcrModel {
  const _OcrModel(this.code, this.label);

  final String code;
  final String label;
}

const List<_OcrModel> _ocrModels = [
  _OcrModel('jpn', '日语（横排）'),
  _OcrModel('jpn_vert', '日语（竖排）'),
  _OcrModel('chi_sim', '简体中文'),
  _OcrModel('chi_tra', '繁体中文'),
  _OcrModel('eng', '英语'),
  _OcrModel('kor', '韩语'),
];

const List<_OcrModel> _paddleLanguageOptions = [
  _OcrModel('japan', '日本語'),
  _OcrModel('ch', '简体中文'),
  _OcrModel('chinese_cht', '繁體中文'),
  _OcrModel('en', 'English'),
  _OcrModel('korean', '한국어'),
];

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
  late final TextEditingController _ocrExecutableController;
  late final TextEditingController _paddleExecutableController;
  late final TextEditingController _ocrDirectoryController;
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late String _paddleLanguage;
  late String _appleLiveTextLanguage;
  late bool _appleLiveTextUseApi;
  late String _targetLanguage;
  late ImageTranslationProvider _provider;
  late OcrModelSource _ocrSource;
  late ImageOcrEngine _ocrEngine;
  late Set<String> _selectedLanguages;
  List<String> _availableModels = [];
  Set<String> _installedLanguages = {};
  bool _fetchingModels = false;
  bool _detectingOcr = false;

  @override
  void initState() {
    super.initState();
    _ocrExecutableController = TextEditingController(
        text: imageTranslationSetting.ocrExecutable.value);
    _paddleExecutableController = TextEditingController(
        text: imageTranslationSetting.paddleOcrExecutable.value);
    _ocrDirectoryController = TextEditingController(
        text: imageTranslationSetting.ocrDataDirectory.value ?? '');
    _endpointController = TextEditingController(
        text: imageTranslationSetting.translatorEndpoint.value ?? '');
    _apiKeyController = TextEditingController(
        text: imageTranslationSetting.translatorApiKey.value ?? '');
    _paddleLanguage = imageTranslationSetting.paddleOcrLanguage.value;
    _appleLiveTextLanguage = imageTranslationSetting.appleLiveTextLanguage.value;
    _appleLiveTextUseApi =
        imageTranslationSetting.appleLiveTextUseThirdPartyApi.value;
    _targetLanguage = imageTranslationSetting.targetLanguage.value;
    _provider = imageTranslationSetting.translatorProvider.value;
    _ocrSource = imageTranslationSetting.ocrModelSource.value;
    _ocrEngine = imageTranslationSetting.ocrEngine.value;
    _selectedLanguages = imageTranslationSetting.ocrLanguage.value
        .split('+')
        .where((language) => language.isNotEmpty)
        .toSet();
    final String savedModel = imageTranslationSetting.translatorModel.value;
    if (savedModel.isNotEmpty) _availableModels = [savedModel];
    if (_ocrEngine != ImageOcrEngine.appleLiveText) {
      _detectOcr();
    }
  }

  @override
  void dispose() {
    _ocrExecutableController.dispose();
    _paddleExecutableController.dispose();
    _ocrDirectoryController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool appleMode = _ocrEngine == ImageOcrEngine.appleLiveText;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('imageTextTranslation'.tr),
        actions: [TextButton(onPressed: _save, child: Text('saveSetting'.tr))],
      ),
      body: EHAppleSettingsListView(
        safeArea: true,
        groups: [
          EHAppleSettingsGroup(
            title: 'imageTranslationMethodSection'.tr,
            children: [_buildMethodSwitch()],
          ),
          if (appleMode) ...[
            EHAppleSettingsGroup(
              title: 'imageTranslationOcrSection'.tr,
              children: [
                _buildAppleLiveTextLanguage(),
                _buildAppleLiveTextAvailability(),
              ],
            ),
            EHAppleSettingsGroup(
              title: 'imageTranslationTranslatorSection'.tr,
              children: [
                _buildTargetLanguage(),
                _buildAppleLiveTextUseApi(),
                if (_appleLiveTextUseApi) ...[
                  _buildProvider(),
                  _buildEndpoint(),
                  _buildApiKey(),
                  _buildFetchModels(),
                  _buildModel(),
                  _buildEnableThinking(),
                ] else
                  _buildOnDeviceTranslationHint(),
              ],
            ),
          ] else ...[
            EHAppleSettingsGroup(
              title: 'imageTranslationTranslatorSection'.tr,
              children: [
                _buildProvider(),
                _buildEndpoint(),
                _buildApiKey(),
                _buildFetchModels(),
                _buildModel(),
                _buildTargetLanguage(),
                _buildEnableThinking(),
              ],
            ),
            EHAppleSettingsGroup(
              title: 'imageTranslationOcrSection'.tr,
              children: [
                _buildOcrEngine(),
                if (_ocrEngine != ImageOcrEngine.tesseract) ...[
                  _buildPaddleLanguage(),
                  _buildPaddleRuntime(),
                ] else ...[
                  _buildOcrExecutable(),
                  _buildOcrDirectory(),
                  _buildDetectOcr(),
                  _buildOcrModelSource(),
                  ..._ocrModels.map(_ocrModelTile),
                ],
              ],
            ),
          ],
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
        onChanged: (value) => setState(() {
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
              child: Text('imageTranslationOpenAICompatible'.tr)),
          const DropdownMenuItem(
              value: ImageTranslationProvider.anthropic,
              child: Text('Anthropic Messages API')),
        ],
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
              isDense: true, labelStyle: TextStyle(fontSize: 12)),
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
              isDense: true, labelStyle: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildFetchModels() {
    return ListTile(
      title: Text('imageTranslationTestAndFetchModels'.tr),
      subtitle: Text('imageTranslationApiTestHint'.tr,
          style: const TextStyle(fontSize: 12)),
      trailing: _fetchingModels
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.cloud_sync_outlined),
      onTap: _fetchingModels ? null : _fetchModels,
    );
  }

  Widget _buildModel() {
    final List<String> models = _availableModels.isEmpty
        ? [imageTranslationSetting.translatorModel.value]
        : _availableModels;
    return ListTile(
      title: Text('imageTranslationModel'.tr),
      subtitle: _availableModels.isEmpty
          ? Text('imageTranslationFetchModelsFirst'.tr,
              style: const TextStyle(fontSize: 12))
          : null,
      trailing: EHCodexStyleDropdown<String>(
        value: models.contains(imageTranslationSetting.translatorModel.value)
            ? imageTranslationSetting.translatorModel.value
            : models.first,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (model) => setState(
            () => imageTranslationSetting.translatorModel.value = model!),
        items: models
            .map((model) => DropdownMenuItem(value: model, child: Text(model)))
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
        items: options
            .map((language) =>
                DropdownMenuItem(value: language, child: Text(language)))
            .toList(),
      ),
    );
  }

  Widget _buildEnableThinking() {
    return Obx(
      () => EHAppleSwitchListTile(
        title: Text('imageTranslationEnableThinking'.tr),
        subtitle: Text('imageTranslationEnableThinkingHint'.tr,
            style: const TextStyle(fontSize: 12)),
        value: imageTranslationSetting.enableThinking.value,
        onChanged: imageTranslationSetting.saveEnableThinking,
      ),
    );
  }

  Widget _buildOcrEngine() {
    return ListTile(
      title: Text('imageTranslationOcrEngine'.tr),
      subtitle: Text('imageTranslationOcrDownloadHint'.tr,
          style: const TextStyle(fontSize: 12)),
      trailing: EHCodexStyleDropdown<ImageOcrEngine>(
        value: _ocrEngine,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (engine) => setState(() => _ocrEngine = engine!),
        items: const [
          DropdownMenuItem(
              value: ImageOcrEngine.tesseract, child: Text('Tesseract')),
          DropdownMenuItem(
              value: ImageOcrEngine.paddleOcr,
              child: Text('PaddleOCR (PP-OCRv6)')),
          DropdownMenuItem(
              value: ImageOcrEngine.paddleOcrVl16,
              child: Text('PaddleOCR-VL-1.6')),
        ],
      ),
    );
  }

  Widget _buildAppleLiveTextLanguage() {
    final List<_OcrModel> options =
        _appleLanguageOptions.any((option) => option.code == _appleLiveTextLanguage)
            ? _appleLanguageOptions
            : [
                ..._appleLanguageOptions,
                _OcrModel(_appleLiveTextLanguage, _appleLiveTextLanguage)
              ];
    return ListTile(
      title: Text('imageTranslationAppleLiveTextLanguage'.tr),
      trailing: EHCodexStyleDropdown<String>(
        value: _appleLiveTextLanguage,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) => setState(() => _appleLiveTextLanguage = value!),
        items: options
            .map((option) =>
                DropdownMenuItem(value: option.code, child: Text(option.label)))
            .toList(),
      ),
    );
  }

  Widget _buildAppleLiveTextAvailability() {
    final bool available = Platform.isIOS || Platform.isMacOS;
    return ListTile(
      title: Text(available
          ? 'imageTranslationAppleLiveTextHint'.tr
          : 'imageTranslationAppleLiveTextUnavailable'.tr),
      trailing: Icon(
        available ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: available ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildMethodSwitch() {
    final bool appleMode = _ocrEngine == ImageOcrEngine.appleLiveText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.apple, size: 18),
            label: Text('imageTranslationMethodAppleLiveText'.tr),
          ),
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.tune, size: 18),
            label: Text('imageTranslationMethodCustom'.tr),
          ),
        ],
        selected: {appleMode},
        onSelectionChanged: (selection) => _setMode(selection.first),
      ),
    );
  }

  Future<void> _setMode(bool apple) async {
    if (apple) {
      await imageTranslationSetting.switchToAppleLiveTextMode();
    } else {
      await imageTranslationSetting.switchToCustomMode();
    }
    if (!mounted) return;
    setState(() {
      _ocrEngine = imageTranslationSetting.ocrEngine.value;
    });
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
    return ListTile(
      leading: const Icon(Icons.phonelink_erase, size: 20),
      title: Text('imageTranslationAppleLiveTextOnDeviceHint'.tr,
          style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildPaddleLanguage() {
    final List<_OcrModel> options =
        _paddleLanguageOptions.any((option) => option.code == _paddleLanguage)
            ? _paddleLanguageOptions
            : [
                ..._paddleLanguageOptions,
                _OcrModel(_paddleLanguage, _paddleLanguage)
              ];
    return ListTile(
      title: Text('imageTranslationPaddleLanguage'.tr),
      trailing: EHCodexStyleDropdown<String>(
        value: _paddleLanguage,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) => setState(() => _paddleLanguage = value!),
        items: options
            .map((option) =>
                DropdownMenuItem(value: option.code, child: Text(option.label)))
            .toList(),
      ),
    );
  }

  Widget _buildPaddleRuntime() {
    return GetBuilder<ImageTranslationService>(
      id: ImageTranslationService.paddlePrepareId,
      builder: (_) {
        final bool installed = imageTranslationService.isPaddleRuntimeInstalled;
        return Column(
          children: [
            if (installed)
              ListTile(
                title: Text('imageTranslationDeletePaddleRuntime'.tr),
                subtitle: Text('imageTranslationDeletePaddleHint'.tr,
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.delete_outline),
                onTap: _confirmDeletePaddle,
              )
            else
              ListTile(
                title: Text(imageTranslationService.paddleStage ??
                    'imageTranslationPreparePaddle'.tr),
                subtitle: Text(
                    '${'imageTranslationPaddleRuntimePath'.tr}: ${imageTranslationService.paddleRuntimePath()}',
                    style: const TextStyle(fontSize: 12)),
                trailing: imageTranslationService.preparingPaddle
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_for_offline_outlined),
                onTap: imageTranslationService.preparingPaddle
                    ? null
                    : _preparePaddle,
              ),
            PaddleCliOutput(lines: imageTranslationService.paddleOutput),
          ],
        );
      },
    );
  }

  Widget _buildOcrExecutable() {
    return ListTile(
      title: Text('imageTranslationOcrExecutable'.tr),
      trailing: SizedBox(
        width: 160,
        child: EHAppleTextField(
          controller: _ocrExecutableController,
          autocorrect: false,
          decoration: const InputDecoration(
              isDense: true, labelStyle: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildOcrDirectory() {
    return ListTile(
      title: Text('imageTranslationOcrDataDirectory'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            child: EHAppleTextField(
              controller: _ocrDirectoryController,
              autocorrect: false,
              decoration: const InputDecoration(
                  isDense: true, labelStyle: TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
              tooltip: 'imageTranslationChooseDirectory'.tr,
              onPressed: _chooseDirectory,
              icon: const Icon(Icons.folder_open_outlined)),
        ],
      ),
    );
  }

  Widget _buildDetectOcr() {
    return ListTile(
      title: Text('imageTranslationDetectOcr'.tr),
      trailing: _detectingOcr
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.manage_search_outlined),
      onTap: _detectingOcr ? null : _detectOcr,
    );
  }

  Widget _buildOcrModelSource() {
    return ListTile(
      title: Text('imageTranslationOcrModelSource'.tr),
      trailing: EHCodexStyleDropdown<OcrModelSource>(
        value: _ocrSource,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) => setState(() => _ocrSource = value!),
        items: [
          DropdownMenuItem(
              value: OcrModelSource.giteeMirror,
              child: Text('imageTranslationGiteeMirror'.tr)),
          DropdownMenuItem(
              value: OcrModelSource.githubOfficial,
              child: Text('imageTranslationGithubOfficial'.tr)),
        ],
      ),
    );
  }

  Widget _ocrModelTile(_OcrModel model) {
    return GetBuilder<ImageTranslationService>(
      id: imageTranslationService.ocrModelDownloadId(model.code),
      builder: (_) {
        final bool downloading =
            imageTranslationService.isDownloadingOcrModel(model.code);
        final bool installed = _installedLanguages.contains(model.code);
        return ListTile(
          title: Text(model.label),
          subtitle: downloading
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                      value: imageTranslationService
                          .ocrModelDownloadProgress(model.code)))
              : Text(installed
                  ? 'imageTranslationOcrInstalled'.tr
                  : 'imageTranslationOcrNotInstalled'.tr),
          leading: Checkbox(
            value: _selectedLanguages.contains(model.code),
            onChanged: (value) => setState(() {
              value == true
                  ? _selectedLanguages.add(model.code)
                  : _selectedLanguages.remove(model.code);
            }),
          ),
          trailing: downloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: 'download'.tr,
                  onPressed: () => _downloadModel(model),
                  icon: Icon(installed
                      ? Icons.download_done
                      : Icons.download_outlined)),
        );
      },
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
      if (!mounted) return;
      setState(() {
        _availableModels = models;
        if (!models.contains(imageTranslationSetting.translatorModel.value)) {
          imageTranslationSetting.translatorModel.value = models.first;
        }
      });
      toast('imageTranslationApiTestSuccess'
          .trParams({'count': '${models.length}'}));
    } on ImageTranslationException catch (error) {
      toast('imageTranslationApiTestFailed'.trParams({'error': error.code}));
    } catch (_) {
      toast(
          'imageTranslationApiTestFailed'.trParams({'error': 'NETWORK_ERROR'}));
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _chooseDirectory() async {
    final String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null && mounted)
      setState(() => _ocrDirectoryController.text = path);
  }

  Future<void> _detectOcr() async {
    setState(() => _detectingOcr = true);
    try {
      final String executable = _ocrExecutableController.text.trim().isEmpty
          ? 'tesseract'
          : _ocrExecutableController.text.trim();
      final String? directory =
          await imageTranslationService.discoverTessdataDirectory(executable);
      final List<String> installed = await imageTranslationService
          .installedOcrLanguages(executable: executable);
      if (!mounted) return;
      setState(() {
        if (_ocrDirectoryController.text.trim().isEmpty && directory != null) {
          _ocrDirectoryController.text = directory;
        }
        _installedLanguages = installed.toSet();
      });
    } catch (_) {
      if (mounted) {
        toast('imageTranslationOcrDetectFailed'.tr);
      }
    } finally {
      if (mounted) setState(() => _detectingOcr = false);
    }
  }

  Future<void> _preparePaddle() async {
    try {
      await imageTranslationService.preparePaddleRuntime(
        downloadVl16: _ocrEngine == ImageOcrEngine.paddleOcrVl16,
      );
      if (mounted) toast('imageTranslationPaddleReady'.tr);
    } on ImageTranslationException catch (error) {
      if (mounted) {
        toast('imageTranslationPaddlePrepareFailed'
            .trParams({'error': error.code}));
      }
    }
  }

  Future<void> _confirmDeletePaddle() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('imageTranslationDeletePaddleRuntime'.tr),
        content: Text('imageTranslationDeletePaddleConfirm'.tr),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('cancel'.tr)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('OK'.tr)),
        ],
      ),
    );
    if (confirmed == true) {
      await imageTranslationService.deletePaddleRuntime();
    }
  }

  Future<void> _downloadModel(_OcrModel model) async {
    String directory = _ocrDirectoryController.text.trim();
    if (directory.isEmpty) {
      await _detectOcr();
      directory = _ocrDirectoryController.text.trim();
    }
    if (directory.isEmpty ||
        !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      toast('imageTranslationOcrDirectoryRequired'.tr);
      return;
    }
    try {
      await imageTranslationService.downloadOcrModel(
        languageCode: model.code,
        source: _ocrSource,
        dataDirectory: directory,
      );
      if (!mounted) return;
      setState(() {
        _installedLanguages.add(model.code);
        _selectedLanguages.add(model.code);
      });
      toast('imageTranslationOcrDownloadSuccess'.tr);
    } catch (_) {
      if (mounted) toast('imageTranslationOcrDownloadFailed'.tr);
    }
  }

  Future<void> _save() async {
    final bool appleMode = _ocrEngine == ImageOcrEngine.appleLiveText;
    final bool needsApi = !appleMode || _appleLiveTextUseApi;
    if (needsApi && _availableModels.isEmpty) {
      toast('imageTranslationFetchModelsFirst'.tr);
      return;
    }
    await imageTranslationSetting.save(
      ocrExecutable: _ocrExecutableController.text,
      ocrEngine: _ocrEngine,
      paddleOcrExecutable: _paddleExecutableController.text,
      paddleOcrLanguage: _paddleLanguage,
      appleLiveTextLanguage: _appleLiveTextLanguage,
      ocrLanguage: _selectedLanguages.join('+'),
      ocrDataDirectory: _ocrDirectoryController.text,
      ocrModelSource: _ocrSource,
      translatorProvider: _provider,
      translatorEndpoint: _endpointController.text,
      translatorApiKey: _apiKeyController.text,
      translatorModel: imageTranslationSetting.translatorModel.value,
      targetLanguage: _targetLanguage,
      enableThinking: imageTranslationSetting.enableThinking.value,
      translateSubsequentPages:
          imageTranslationSetting.translateSubsequentPages.value,
    );
    if (mounted) toast('success'.tr);
  }
}
