import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../service/engine/engine_contract.dart';
import '../service/engine/gguf_model_store.dart';
import '../service/engine/local_translation_model_catalog.dart';
import '../service/engine/llama_runtime_store.dart';
import '../service/engine/model_catalog.dart';
import 'eh_apple_controls.dart';
import 'eh_apple_glass_toolbar.dart';
import 'eh_codex_style_dropdown.dart';

/// Renders a byte-rate as a compact human label, e.g. "12.3 MB/s".
String formatDownloadSpeed(double bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }
  return '${bytesPerSecond.toStringAsFixed(0)} B/s';
}

/// Long-lived GGUF download state. Navigating away from settings does not
/// cancel a large model download; reopening the page reconnects to this state.
class GgufModelManagerController extends GetxController {
  GgufModelManagerController({
    GgufModelStore? store,
    GgufModelDownloadManager? downloads,
    LlamaRuntimeStore? runtimeStore,
  }) : store = store ?? GgufModelStore.instance,
       downloads = downloads ?? GgufModelDownloadManager(),
       runtimeStore = runtimeStore ?? LlamaRuntimeStore.instance;

  static GgufModelManagerController? _instance;

  static GgufModelManagerController get instance =>
      _instance ??= GgufModelManagerController();

  final GgufModelStore store;
  final GgufModelDownloadManager downloads;
  final LlamaRuntimeStore runtimeStore;
  final Map<String, ModelInstallState> states = <String, ModelInstallState>{};
  final Map<String, double> progress = <String, double>{};
  final Map<String, String> progressArtifact = <String, String>{};
  final Map<String, double> progressSpeed = <String, double>{};
  final Map<String, String> errors = <String, String>{};
  final Map<String, EngineTask<ModelInstallResult>> _tasks =
      <String, EngineTask<ModelInstallResult>>{};
  final Map<String, StreamSubscription<EngineTaskProgress>> _subscriptions =
      <String, StreamSubscription<EngineTaskProgress>>{};
  ModelInstallState runtimeState = ModelInstallState.notInstalled;
  double runtimeProgress = 0;
  String? runtimeError;
  bool runtimeDownloading = false;
  bool _initialized = false;

  bool isDownloading(String modelId) => _tasks.containsKey(modelId);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await Future.wait(<Future<void>>[refreshStates(), refreshRuntimeState()]);
  }

  Future<void> refreshRuntimeState() async {
    try {
      runtimeState = await runtimeStore.installState();
      runtimeError = null;
    } on Object catch (error) {
      runtimeState = ModelInstallState.invalid;
      runtimeError = error.toString();
    }
    update(<Object>['llama-runtime']);
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
    if (runtimeStore.artifact != null &&
        runtimeState != ModelInstallState.ready &&
        !runtimeDownloading) {
      unawaited(downloadRuntime());
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
      progressSpeed[modelId] = event.speedBytesPerSecond;
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
      progressSpeed.remove(modelId);
      update(<Object>[modelId, 'gguf-model-list']);
    }
  }

  Future<void> downloadRuntime() async {
    if (runtimeDownloading || runtimeStore.artifact == null) {
      return;
    }
    runtimeDownloading = true;
    runtimeProgress = 0;
    runtimeError = null;
    runtimeState = ModelInstallState.validating;
    update(<Object>['llama-runtime']);
    try {
      await runtimeStore.download(
        onProgress: (double value) {
          runtimeProgress = value;
          update(<Object>['llama-runtime']);
        },
      );
      runtimeState = ModelInstallState.ready;
    } on LlamaRuntimeDownloadCancelled {
      runtimeState = await runtimeStore.installState();
    } on Object catch (error) {
      runtimeError = error.toString();
      runtimeState = await runtimeStore.installState();
    } finally {
      runtimeDownloading = false;
      update(<Object>['llama-runtime']);
    }
  }

  void cancelRuntime() {
    runtimeStore.cancel();
  }

  Future<void> deleteRuntime() async {
    await runtimeStore.delete();
    runtimeState = ModelInstallState.notInstalled;
    runtimeProgress = 0;
    runtimeError = null;
    update(<Object>['llama-runtime']);
  }

  Future<void> reinstallRuntime() async {
    await deleteRuntime();
    await downloadRuntime();
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
  });

  final String selectedModelId;
  final ValueChanged<String> onSelectModel;

  @override
  State<GgufModelManagerPanel> createState() => _GgufModelManagerPanelState();
}

class _GgufModelManagerPanelState extends State<GgufModelManagerPanel> {
  final GgufModelManagerController _manager =
      GgufModelManagerController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_manager.initialize());
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
            // The panel lives on the right side of the screen (reader drawer /
            // right settings pane); the expanded menu must open toward the
            // bottom-left so it stays inside the panel.
            menuAlignment: GlassMenuAlignment.topRight,
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
          GetBuilder<GgufModelManagerController>(
            init: _manager,
            global: true,
            autoRemove: false,
            id: 'llama-runtime',
            builder: _buildManagedRuntimeTile,
          )
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      manager.progressArtifact[model.id]!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(formatDownloadSpeed(manager.progressSpeed[model.id] ?? 0)),
                ],
              ),
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
              ? EHAppleGlassToolbar(
                materialSpacing: 0,
                items: <EHAppleToolbarItem>[
                  EHAppleToolbarItem(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'inferenceRefresh'.tr,
                    onPressed:
                        () => manager.download(model.id, forceUpdate: true),
                  ),
                  EHAppleToolbarItem(
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

  Widget _buildManagedRuntimeTile(GgufModelManagerController manager) {
    final LlamaRuntimeArtifact? artifact = manager.runtimeStore.artifact;
    final String status =
        manager.runtimeDownloading
            ? 'imageTranslationLocalModelDownloading'.trParams(<String, String>{
              'progress':
                  '${(manager.runtimeProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            })
            : switch (manager.runtimeState) {
              ModelInstallState.notInstalled =>
                'inferenceModelNotDownloaded'.tr,
              ModelInstallState.validating => 'inferenceModelValidating'.tr,
              ModelInstallState.ready => 'inferenceModelReady'.tr,
              ModelInstallState.invalid => 'inferenceModelInvalid'.tr,
            };
    return ListTile(
      key: const ValueKey('image-translation-managed-llama-runtime'),
      leading: const Icon(Icons.terminal),
      title: Text('imageTranslationLlamaRuntime'.tr),
      subtitle: Text(
        artifact == null
            ? 'imageTranslationLlamaRuntimeUnsupported'.tr
            : '${'imageTranslationLlamaRuntimeHint'.tr}\n$status'
                '${manager.runtimeError == null ? '' : '\n${manager.runtimeError}'}',
      ),
      trailing:
          artifact == null
              ? null
              : manager.runtimeDownloading
              ? EHAppleIconButton(
                icon: const Icon(Icons.close),
                tooltip: 'cancel'.tr,
                onPressed: manager.cancelRuntime,
              )
              : manager.runtimeState == ModelInstallState.ready
              ? EHAppleGlassToolbar(
                materialSpacing: 0,
                items: <EHAppleToolbarItem>[
                  EHAppleToolbarItem(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'inferenceRefresh'.tr,
                    onPressed: manager.reinstallRuntime,
                  ),
                  EHAppleToolbarItem(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'delete'.tr,
                    onPressed: manager.deleteRuntime,
                  ),
                ],
              )
              : EHAppleIconButton(
                icon: const Icon(Icons.download),
                tooltip: 'download'.tr,
                onPressed: manager.downloadRuntime,
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
