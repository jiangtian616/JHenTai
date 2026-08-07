import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

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
  late final TextEditingController _paddleLanguageController;
  late final TextEditingController _ocrDirectoryController;
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _targetLanguageController;
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
    _paddleLanguageController = TextEditingController(
        text: imageTranslationSetting.paddleOcrLanguage.value);
    _ocrDirectoryController = TextEditingController(
        text: imageTranslationSetting.ocrDataDirectory.value ?? '');
    _endpointController = TextEditingController(
        text: imageTranslationSetting.translatorEndpoint.value ?? '');
    _apiKeyController = TextEditingController(
        text: imageTranslationSetting.translatorApiKey.value ?? '');
    _targetLanguageController = TextEditingController(
        text: imageTranslationSetting.targetLanguage.value);
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
    _paddleLanguageController.dispose();
    _ocrDirectoryController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    _targetLanguageController.dispose();
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('imageTranslationTranslatorSection'.tr,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('imageTranslationApiTestHint'.tr,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<ImageTranslationProvider>(
            value: _provider,
            decoration: InputDecoration(
                labelText: 'imageTranslationProvider'.tr,
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: ImageTranslationProvider.openAICompatible,
                  child: Text('imageTranslationOpenAICompatible'.tr)),
              DropdownMenuItem(
                  value: ImageTranslationProvider.anthropic,
                  child: const Text('Anthropic Messages API')),
            ],
            onChanged: (value) => setState(() {
              _provider = value!;
              _availableModels = [];
              _endpointController.text =
                  _provider == ImageTranslationProvider.anthropic
                      ? 'https://api.anthropic.com/v1'
                      : 'https://api.openai.com/v1';
            }),
          ),
          const SizedBox(height: 16),
          _field(
              controller: _endpointController,
              label: 'imageTranslationApiBaseUrl'.tr,
              hint: _provider == ImageTranslationProvider.anthropic
                  ? 'https://api.anthropic.com/v1'
                  : 'https://api.openai.com/v1',
              keyboardType: TextInputType.url),
          _field(
              controller: _apiKeyController,
              label: 'apiKey'.tr,
              obscureText: true),
          FilledButton.icon(
            onPressed: _fetchingModels ? null : _fetchModels,
            icon: _fetchingModels
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            label: Text('imageTranslationTestAndFetchModels'.tr),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _availableModels
                    .contains(imageTranslationSetting.translatorModel.value)
                ? imageTranslationSetting.translatorModel.value
                : null,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'imageTranslationModel'.tr,
                hintText: 'imageTranslationFetchModelsFirst'.tr,
                border: const OutlineInputBorder()),
            items: _availableModels
                .map((model) =>
                    DropdownMenuItem(value: model, child: Text(model)))
                .toList(),
            onChanged: _availableModels.isEmpty
                ? null
                : (model) => setState(() =>
                    imageTranslationSetting.translatorModel.value = model!),
          ),
          const SizedBox(height: 16),
          _field(
              controller: _targetLanguageController,
              label: 'imageTranslationTargetLanguage'.tr),
          const SizedBox(height: 28),
          Text('imageTranslationOcrSection'.tr,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('imageTranslationOcrDownloadHint'.tr,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<ImageOcrEngine>(
            value: _ocrEngine,
            decoration: InputDecoration(
                labelText: 'imageTranslationOcrEngine'.tr,
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: ImageOcrEngine.tesseract,
                  child: const Text('Tesseract')),
              DropdownMenuItem(
                  value: ImageOcrEngine.paddleOcr,
                  child: const Text('PaddleOCR (PP-OCRv6)')),
              DropdownMenuItem(
                  value: ImageOcrEngine.paddleOcrVl16,
                  child: const Text('PaddleOCR-VL-1.6')),
            ],
            onChanged: (engine) => setState(() => _ocrEngine = engine!),
          ),
          const SizedBox(height: 16),
          if (_ocrEngine != ImageOcrEngine.tesseract) ...[
            Text('imageTranslationPaddleHint'.tr,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            _field(
                controller: _paddleLanguageController,
                label: 'imageTranslationPaddleLanguage'.tr,
                hint: 'japan / ch / en / korean'),
            Text(
                '${'imageTranslationPaddleRuntimePath'.tr}: ${imageTranslationService.paddleRuntimePath()}',
                style: Theme.of(context).textTheme.bodySmall),
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
                    Text(_paddleStage ?? 'imageTranslationPreparePaddle'.tr)),
          ] else ...[
            _field(
                controller: _ocrExecutableController,
                label: 'imageTranslationOcrExecutable'.tr,
                hint: 'tesseract'),
            Row(children: [
              Expanded(
                  child: _field(
                      controller: _ocrDirectoryController,
                      label: 'imageTranslationOcrDataDirectory'.tr,
                      hint: '…/tessdata')),
              const SizedBox(width: 8),
              IconButton(
                  tooltip: 'imageTranslationChooseDirectory'.tr,
                  onPressed: _chooseDirectory,
                  icon: const Icon(Icons.folder_open_outlined)),
            ]),
            OutlinedButton.icon(
                onPressed: _detectingOcr ? null : _detectOcr,
                icon: const Icon(Icons.manage_search_outlined),
                label: Text('imageTranslationDetectOcr'.tr)),
            const SizedBox(height: 16),
            DropdownButtonFormField<OcrModelSource>(
              value: _ocrSource,
              decoration: InputDecoration(
                  labelText: 'imageTranslationOcrModelSource'.tr,
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(
                    value: OcrModelSource.giteeMirror,
                    child: Text('imageTranslationGiteeMirror'.tr)),
                DropdownMenuItem(
                    value: OcrModelSource.githubOfficial,
                    child: Text('imageTranslationGithubOfficial'.tr)),
              ],
              onChanged: (value) => setState(() => _ocrSource = value!),
            ),
            const SizedBox(height: 12),
            ..._ocrModels.map(_ocrModelTile),
          ],
        ],
      ).withListTileTheme(context),
    );
  }

  Widget _ocrModelTile(_OcrModel model) {
    final bool downloading = _downloadProgress.containsKey(model.code);
    final bool installed = _installedLanguages.contains(model.code);
    return Card(
      child: ListTile(
        title: Text(model.label),
        subtitle: downloading
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                    value: _downloadProgress[model.code]))
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
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) =>
      Padding(
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
      paddleOcrLanguage: _paddleLanguageController.text,
      ocrLanguage: _selectedLanguages.join('+'),
      ocrDataDirectory: _ocrDirectoryController.text,
      ocrModelSource: _ocrSource,
      translatorProvider: _provider,
      translatorEndpoint: _endpointController.text,
      translatorApiKey: _apiKeyController.text,
      translatorModel: imageTranslationSetting.translatorModel.value,
      targetLanguage: _targetLanguageController.text,
    );
    if (mounted) toast('success'.tr);
  }
}
