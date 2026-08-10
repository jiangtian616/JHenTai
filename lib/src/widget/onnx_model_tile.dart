import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class OnnxModelTile extends StatelessWidget {
  const OnnxModelTile({
    super.key,
    required this.manifestId,
    required this.title,
  });

  final String manifestId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OnnxModelStore>(
      builder: (OnnxModelStore store) {
        final OnnxModelManifest manifest = store.manifestOf(manifestId)!;
        final List<OnnxModelSource> sources = store.availableSources(
          manifestId,
        );
        final OnnxModelSource selected = store.preferredSource(manifestId);
        final bool downloaded = store.isManifestDownloaded(manifestId);
        final bool downloading =
            store.downloadState.value == LoadingState.loading &&
            store.downloadingManifestId.value == manifestId;
        final bool anotherDownload =
            store.downloadState.value == LoadingState.loading &&
            store.downloadingManifestId.value != manifestId;
        final OnnxModelInstallState state =
            store.installStates[manifestId] ??
            OnnxModelInstallState.notInstalled;
        final String status =
            downloading
                ? '${store.downloadingFileId.value ?? ''} ${store.downloadProgress.value}'
                : downloaded
                ? 'inferenceModelReady'.tr
                : state == OnnxModelInstallState.validating
                ? 'inferenceRefresh'.tr
                : state == OnnxModelInstallState.invalid
                ? (store.lastError.value ?? 'failed'.tr)
                : store.downloadState.value == LoadingState.error &&
                    store.lastError.value != null
                ? store.lastError.value!
                : 'inferenceModelNotDownloaded'.tr;
        return ListTile(
          title: Text(title),
          subtitle: Text(
            '$status\n${manifest.version} · ${selected.displayName} · ${manifest.licenseName}',
            style: const TextStyle(fontSize: 12),
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (sources.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<OnnxModelSource>(
                    value: selected,
                    items: sources
                        .map(
                          (OnnxModelSource source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              source.displayName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        downloading || anotherDownload
                            ? null
                            : (OnnxModelSource? source) {
                              if (source != null) {
                                store.selectSource(manifestId, source);
                              }
                            },
                  ),
                ),
              if (downloading)
                EHAppleIconButton(
                  tooltip: 'cancel'.tr,
                  icon: const Icon(Icons.close),
                  onPressed: store.cancelDownload,
                )
              else if (state == OnnxModelInstallState.validating)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: CupertinoActivityIndicator(),
                )
              else if (downloaded)
                EHAppleIconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      anotherDownload
                          ? null
                          : () => store.deleteManifest(manifestId),
                )
              else
                EHAppleIconButton(
                  icon: const Icon(Icons.download),
                  onPressed:
                      anotherDownload
                          ? null
                          : () => unawaited(
                            store
                                .downloadManifest(manifestId, source: selected)
                                .catchError((Object _) {}),
                          ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Lists every model of [kind] (e.g. 'ocr', 'superResolution') with its
/// description — how that tier differs in speed / size / accuracy — below the
/// name, and a radio marking the currently active one. Tapping a row selects it
/// via [onSelect].
class OnnxModelPicker extends StatelessWidget {
  const OnnxModelPicker({
    super.key,
    required this.kind,
    required this.activeId,
    required this.onSelect,
  });

  final String kind;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<OnnxModelManifest> models =
        OnnxModelStore.instance.manifestsOfKind(kind);
    if (models.isEmpty) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final OnnxModelManifest model in models)
          InkWell(
            onTap: () => onSelect(model.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      model.id == activeId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(model.displayName),
                        const SizedBox(height: 2),
                        Text(
                          model.description.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
