import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../service/engine/engine_contract.dart';
import '../service/engine/gguf_model_store.dart';
import '../service/engine/local_translation_model_catalog.dart';
import '../service/engine/model_catalog.dart';
import 'eh_apple_controls.dart';
import 'eh_codex_style_dropdown.dart';

/// Long-lived GGUF download state. Navigating away from settings does not
/// cancel a large model download; reopening the page reconnects to this state.
class GgufModelManagerController extends GetxController {
  GgufModelManagerController({
    GgufModelStore? store,
    GgufModelDownloadManager? downloads,
  }) : store = store ?? GgufModelStore.instance,
       downloads = downloads ?? GgufModelDownloadManager();

  static GgufModelManagerController? _instance;

  static GgufModelManagerController get instance =>
      _instance ??= GgufModelManagerController();

  final GgufModelStore store;
  final GgufModelDownloadManager downloads;
  final Map<String, ModelInstallState> states = <String, ModelInstallState>{};
  final Map<String, double> progress = <String, double>{};
  final Map<String, String> progressArtifact = <String, String>{};
  final Map<String, String> errors = <String, String>{};
  final Map<String, EngineTask<ModelInstallResult>> _tasks =
      <String, EngineTask<ModelInstallResult>>{};
  final Map<String, StreamSubscription<EngineTaskProgress>> _subscriptions =
      <String, StreamSubscription<EngineTaskProgress>>{};
  bool _initialized = false;

  bool isDownloading(String modelId) => _tasks.containsKey(modelId);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await refreshStates();
  }

  Future<void> refreshStates([String? modelId]) async {
    final Iterable<ModelDescriptor> models =
        modelId == null
            ? store.catalog.models
            : store.catalog.models.where(
              (ModelDescriptor model) => model.id == modelId,
            );
    for (final ModelDescriptor model in models) {
      try {
        states[model.id] = await store.installState(model.id);
      } on Object catch (error) {
        states[model.id] = ModelInstallState.notInstalled;
        errors[model.id] = error.toString();
      }
      update(<Object>[model.id, 'gguf-model-list']);
    }
  }

  Future<void> download(String modelId, {bool forceUpdate = false}) async {
    if (_tasks.containsKey(modelId)) {
      return;
    }
    errors.remove(modelId);
    progress[modelId] = 0;
    states[modelId] = ModelInstallState.validating;
    final EngineTask<ModelInstallResult> task =
        forceUpdate ? downloads.update(modelId) : downloads.download(modelId);
    _tasks[modelId] = task;
    _subscriptions[modelId] = task.progress.listen((EngineTaskProgress event) {
      progress[modelId] = event.fraction;
      if (event.message != null) {
        progressArtifact[modelId] = event.message!;
      }
      update(<Object>[modelId, 'gguf-model-list']);
    });
    update(<Object>[modelId, 'gguf-model-list']);
    try {
      final ModelInstallResult result = await task.future;
      states[modelId] = result.state;
      progress[modelId] = 1;
    } on EngineTaskCancelledException {
      states[modelId] = await store.installState(modelId);
    } on EngineException catch (error) {
      errors[modelId] = error.message;
      states[modelId] = await store.installState(modelId);
    } on Object catch (error) {
      errors[modelId] = error.toString();
      states[modelId] = await store.installState(modelId);
    } finally {
      await _subscriptions.remove(modelId)?.cancel();
      _tasks.remove(modelId);
      progressArtifact.remove(modelId);
      update(<Object>[modelId, 'gguf-model-list']);
    }
  }

  void cancel(String modelId) {
    _tasks[modelId]?.cancel('GGUF download cancelled');
  }

  Future<void> delete(String modelId) async {
    cancel(modelId);
    await downloads.delete(modelId);
    errors.remove(modelId);
    progress.remove(modelId);
    states[modelId] = ModelInstallState.notInstalled;
    update(<Object>[modelId, 'gguf-model-list']);
  }
}

class GgufModelManagerPanel extends StatefulWidget {
  const GgufModelManagerPanel({
    super.key,
    required this.selectedModelId,
    required this.onSelectModel,
    required this.llamaServerPath,
    required this.onSaveLlamaServerPath,
  });

  final String selectedModelId;
  final ValueChanged<String> onSelectModel;
  final String? llamaServerPath;
  final ValueChanged<String> onSaveLlamaServerPath;

  @override
  State<GgufModelManagerPanel> createState() => _GgufModelManagerPanelState();
}

class _GgufModelManagerPanelState extends State<GgufModelManagerPanel> {
  late final TextEditingController _runtimePathController;
  final GgufModelManagerController _manager =
      GgufModelManagerController.instance;

  @override
  void initState() {
    super.initState();
    _runtimePathController = TextEditingController(
      text: widget.llamaServerPath ?? '',
    );
    unawaited(_manager.initialize());
  }

  @override
  void didUpdateWidget(covariant GgufModelManagerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.llamaServerPath != widget.llamaServerPath &&
        _runtimePathController.text != (widget.llamaServerPath ?? '')) {
      _runtimePathController.text = widget.llamaServerPath ?? '';
    }
  }

  @override
  void dispose() {
    _runtimePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ModelDescriptor> models = LocalTranslationModelCatalog().models;
    final ModelDescriptor selected = models.firstWhere(
      (ModelDescriptor model) => model.id == widget.selectedModelId,
      orElse: () => models.first,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          title: Text('imageTranslationLocalModel'.tr),
          trailing: EHCodexStyleDropdown<String>(
            key: const ValueKey('image-translation-local-model'),
            value: selected.id,
            onChanged: (String? value) {
              if (value != null) {
                widget.onSelectModel(value);
              }
            },
            items: models
                .map(
                  (ModelDescriptor model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.displayName),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        _ModelDetails(model: selected),
        GetBuilder<GgufModelManagerController>(
          init: _manager,
          global: true,
          autoRemove: false,
          id: selected.id,
          builder:
              (GgufModelManagerController manager) =>
                  _buildDownloadTile(selected, manager),
        ),
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          _buildDesktopRuntimeTile()
        else
          ListTile(
            leading: const Icon(Icons.developer_board_outlined),
            title: Text('imageTranslationLocalFfiRuntime'.tr),
            subtitle: Text('imageTranslationLocalFfiRuntimeHint'.tr),
          ),
      ],
    );
  }

  Widget _buildDownloadTile(
    ModelDescriptor model,
    GgufModelManagerController manager,
  ) {
    final ModelInstallState state =
        manager.states[model.id] ?? ModelInstallState.notInstalled;
    final bool downloading = manager.isDownloading(model.id);
    final double value = manager.progress[model.id] ?? 0;
    final String? error = manager.errors[model.id];
    final String status =
        downloading
            ? 'imageTranslationLocalModelDownloading'.trParams(<String, String>{
              'progress': '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
            })
            : switch (state) {
              ModelInstallState.notInstalled =>
                'inferenceModelNotDownloaded'.tr,
              ModelInstallState.validating => 'inferenceModelValidating'.tr,
              ModelInstallState.ready => 'inferenceModelReady'.tr,
              ModelInstallState.invalid => 'inferenceModelInvalid'.tr,
            };
    return ListTile(
      key: const ValueKey('image-translation-local-model-download'),
      title: Text(status),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (downloading) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: value > 0 ? value : null),
            if (manager.progressArtifact[model.id] != null)
              Text(manager.progressArtifact[model.id]!),
          ],
          if (error != null)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      trailing:
          downloading
              ? EHAppleIconButton(
                icon: const Icon(Icons.close),
                tooltip: 'cancel'.tr,
                onPressed: () => manager.cancel(model.id),
              )
              : state == ModelInstallState.ready
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  EHAppleIconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'inferenceRefresh'.tr,
                    onPressed:
                        () => manager.download(model.id, forceUpdate: true),
                  ),
                  EHAppleIconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'delete'.tr,
                    onPressed: () => manager.delete(model.id),
                  ),
                ],
              )
              : EHAppleIconButton(
                icon: const Icon(Icons.download),
                tooltip: 'download'.tr,
                onPressed: () => manager.download(model.id),
              ),
    );
  }

  Widget _buildDesktopRuntimeTile() {
    return ListTile(
      leading: const Icon(Icons.terminal),
      title: Text('imageTranslationLlamaServerPath'.tr),
      subtitle: TextField(
        key: const ValueKey('image-translation-llama-server-path'),
        controller: _runtimePathController,
        decoration: InputDecoration(
          hintText: 'imageTranslationLlamaServerPathHint'.tr,
        ),
        onSubmitted: widget.onSaveLlamaServerPath,
      ),
      trailing: EHAppleIconButton(
        icon: const Icon(Icons.folder_open),
        tooltip: 'imageTranslationBrowseRuntime'.tr,
        onPressed: () async {
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
          );
          final String? path = result?.files.single.path;
          if (path != null) {
            _runtimePathController.text = path;
            widget.onSaveLlamaServerPath(path);
          }
        },
      ),
    );
  }
}

class _ModelDetails extends StatelessWidget {
  const _ModelDetails({required this.model});

  final ModelDescriptor model;

  @override
  Widget build(BuildContext context) {
    final String sizes = model.artifacts
        .map(
          (ModelArtifactDescriptor artifact) =>
              artifact.sizeLabel ?? _formatBytes(artifact.sizeBytes),
        )
        .join(' + ');
    return ListTile(
      leading: const Icon(Icons.smart_toy_outlined),
      title: Text(model.displayName),
      subtitle: Text(
        '${model.description}\n$sizes · ${model.licenseName}\n'
        '${model.minimumMemoryHint ?? ''}',
      ),
      isThreeLine: true,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '—';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
