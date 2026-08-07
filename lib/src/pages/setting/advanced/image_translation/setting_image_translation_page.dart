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
  late String _targetLanguage;
  late ImageTranslationProvider _provider;
  late OcrModelSource _ocrSource;
  late ImageOcrEngine _ocrEngine;
  late Set<String> _selectedLanguages;
  List<String> _availableModels = [];
  Set<String> _installedLanguages = {};
  final Map<String, double?> _downloadProgress = {};
  bool _fetchingModels = false;
  bool _detectingOcr = false;
  bool _preparingPaddle = false;
  String? _paddleStage;

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
    _detectOcr();
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
            title: 'imageTranslationTranslatorSection'.tr,
            children: [
              _buildProvider(),
              _buildEndpoint(),
              _buildApiKey(),
              _buildFetchModels(),
              _buildModel(),
              _buildTargetLanguage(),
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
    return ListTile(
      title: Text(_paddleStage ?? 'imageTranslationPreparePaddle'.tr),
      subtitle: Text(
          '${'imageTranslationPaddleRuntimePath'.tr}: ${imageTranslationService.paddleRuntimePath()}',
          style: const TextStyle(fontSize: 12)),
      trailing: _preparingPaddle
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download_for_offline_outlined),
      onTap: _preparingPaddle ? null : _preparePaddle,
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
    final bool downloading = _downloadProgress.containsKey(model.code);
    final bool installed = _installedLanguages.contains(model.code);
    return ListTile(
      title: Text(model.label),
      subtitle: downloading
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  LinearProgressIndicator(value: _downloadProgress[model.code]))
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
              icon: Icon(
                  installed ? Icons.download_done : Icons.download_outlined)),
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
    setState(() => _preparingPaddle = true);
    try {
      await imageTranslationService.preparePaddleRuntime(
        downloadVl16: _ocrEngine == ImageOcrEngine.paddleOcrVl16,
        onStage: (stage) {
          if (mounted) setState(() => _paddleStage = stage);
        },
      );
      if (mounted) toast('imageTranslationPaddleReady'.tr);
    } on ImageTranslationException catch (error) {
      if (mounted)
        toast('imageTranslationPaddlePrepareFailed'
            .trParams({'error': error.code}));
    } finally {
      if (mounted)
        setState(() {
          _preparingPaddle = false;
          _paddleStage = null;
        });
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
    setState(() => _downloadProgress[model.code] = null);
    try {
      await imageTranslationService.downloadOcrModel(
        languageCode: model.code,
        source: _ocrSource,
        dataDirectory: directory,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _downloadProgress[model.code] = received / total);
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _installedLanguages.add(model.code);
        _selectedLanguages.add(model.code);
      });
      toast('imageTranslationOcrDownloadSuccess'.tr);
    } catch (_) {
      if (mounted) toast('imageTranslationOcrDownloadFailed'.tr);
    } finally {
      if (mounted) setState(() => _downloadProgress.remove(model.code));
    }
  }

  Future<void> _save() async {
    if (_availableModels.isEmpty) {
      toast('imageTranslationFetchModelsFirst'.tr);
      return;
    }
    await imageTranslationSetting.save(
      ocrExecutable: _ocrExecutableController.text,
      ocrEngine: _ocrEngine,
      paddleOcrExecutable: _paddleExecutableController.text,
      paddleOcrLanguage: _paddleLanguage,
      ocrLanguage: _selectedLanguages.join('+'),
      ocrDataDirectory: _ocrDirectoryController.text,
      ocrModelSource: _ocrSource,
      translatorProvider: _provider,
      translatorEndpoint: _endpointController.text,
      translatorApiKey: _apiKeyController.text,
      translatorModel: imageTranslationSetting.translatorModel.value,
      targetLanguage: _targetLanguage,
    );
    if (mounted) toast('success'.tr);
  }
}
