import 'dart:async';

import 'engine_contract.dart';

const int modelCatalogSchemaVersion = 1;

enum ModelInstallState { notInstalled, validating, ready, invalid }

class ModelSourceDescriptor {
  const ModelSourceDescriptor({required this.id, required this.url});

  final String id;
  final String url;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'url': url};

  factory ModelSourceDescriptor.fromJson(Map<dynamic, dynamic> json) =>
      ModelSourceDescriptor(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}

class ModelArtifactDescriptor {
  const ModelArtifactDescriptor({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.sources,
    this.sizeLabel,
  });

  final String id;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final List<ModelSourceDescriptor> sources;

  /// Human-readable upstream size when the repository only publishes a
  /// rounded value. A zero [sizeBytes] means the downloader must resolve the
  /// exact Content-Length before reserving disk space.
  final String? sizeLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    if (sizeLabel != null) 'sizeLabel': sizeLabel,
    'sha256': sha256,
    'sources':
        sources.map((ModelSourceDescriptor source) => source.toJson()).toList(),
  };

  factory ModelArtifactDescriptor.fromJson(Map<dynamic, dynamic> json) =>
      ModelArtifactDescriptor(
        id: json['id']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256']?.toString() ?? '',
        sizeLabel: json['sizeLabel']?.toString(),
        sources: (json['sources'] as List? ?? const [])
            .whereType<Map>()
            .map(ModelSourceDescriptor.fromJson)
            .toList(growable: false),
      );
}

class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.kind,
    required this.version,
    required this.displayName,
    required this.description,
    required this.licenseName,
    required this.licenseUrl,
    required this.sourceProjectUrl,
    required this.artifacts,
    required this.engineIds,
    this.quantization,
    this.languages = const <String>[],
    this.supportsImages = false,
    this.minimumMemoryHint,
    this.imageProjectorArtifactId,
    this.runtimeRequirements = const <String>[],
  });

  final String id;
  final String kind;
  final String version;
  final String displayName;
  final String description;
  final String licenseName;
  final String licenseUrl;
  final String sourceProjectUrl;
  final List<ModelArtifactDescriptor> artifacts;
  final List<String> engineIds;
  final String? quantization;
  final List<String> languages;
  final bool supportsImages;
  final String? minimumMemoryHint;
  final String? imageProjectorArtifactId;
  final List<String> runtimeRequirements;

  int get totalBytes => artifacts.fold<int>(
    0,
    (int total, ModelArtifactDescriptor artifact) => total + artifact.sizeBytes,
  );

  String get fingerprint =>
      '$id@$version:${artifacts.map((ModelArtifactDescriptor a) => a.sha256).join(':')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': modelCatalogSchemaVersion,
    'id': id,
    'kind': kind,
    'version': version,
    'displayName': displayName,
    'description': description,
    'licenseName': licenseName,
    'licenseUrl': licenseUrl,
    'sourceProjectUrl': sourceProjectUrl,
    'artifacts':
        artifacts.map((ModelArtifactDescriptor a) => a.toJson()).toList(),
    'engineIds': engineIds,
    if (quantization != null) 'quantization': quantization,
    'languages': languages,
    'supportsImages': supportsImages,
    if (minimumMemoryHint != null) 'minimumMemoryHint': minimumMemoryHint,
    if (imageProjectorArtifactId != null)
      'imageProjectorArtifactId': imageProjectorArtifactId,
    'runtimeRequirements': runtimeRequirements,
  };

  factory ModelDescriptor.fromJson(Map<dynamic, dynamic> json) =>
      ModelDescriptor(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        version: json['version']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        licenseName: json['licenseName']?.toString() ?? '',
        licenseUrl: json['licenseUrl']?.toString() ?? '',
        sourceProjectUrl: json['sourceProjectUrl']?.toString() ?? '',
        artifacts: (json['artifacts'] as List? ?? const [])
            .whereType<Map>()
            .map(ModelArtifactDescriptor.fromJson)
            .toList(growable: false),
        engineIds: (json['engineIds'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        quantization: json['quantization']?.toString(),
        languages: (json['languages'] as List? ?? const [])
            .map((Object? value) => value?.toString() ?? '')
            .where((String value) => value.isNotEmpty)
            .toList(growable: false),
        supportsImages: json['supportsImages'] == true,
        minimumMemoryHint: json['minimumMemoryHint']?.toString(),
        imageProjectorArtifactId: json['imageProjectorArtifactId']?.toString(),
        runtimeRequirements: (json['runtimeRequirements'] as List? ?? const [])
            .map((Object? value) => value?.toString() ?? '')
            .where((String value) => value.isNotEmpty)
            .toList(growable: false),
      );
}

abstract class ModelCatalog {
  List<ModelDescriptor> get models;

  ModelDescriptor? find(String id) {
    for (final ModelDescriptor model in models) {
      if (model.id == id) return model;
    }
    return null;
  }
}

class ModelInstallResult {
  const ModelInstallResult({required this.modelId, required this.state});

  final String modelId;
  final ModelInstallState state;
}

abstract class ModelDownloadManager {
  EngineTask<ModelInstallResult> download(String modelId, {String? sourceId});

  /// Re-fetches the pinned artifact set while preserving the previous
  /// installed directory until the replacement has passed validation.
  EngineTask<ModelInstallResult> update(String modelId, {String? sourceId}) =>
      download(modelId, sourceId: sourceId);

  Future<void> cancel(String taskId);
  Future<void> delete(String modelId);
}

/// Keeps the existing ONNX catalog and the GGUF catalog behind the single
/// wave-1 contract. A caller cannot accidentally request an artifact from the
/// wrong store because routing is by the verified descriptor id.
class CompositeModelCatalog extends ModelCatalog {
  CompositeModelCatalog(this.catalogs);

  final List<ModelCatalog> catalogs;

  @override
  List<ModelDescriptor> get models => catalogs
      .expand((ModelCatalog catalog) => catalog.models)
      .toList(growable: false);
}

class CompositeModelDownloadManager implements ModelDownloadManager {
  CompositeModelDownloadManager({
    required this.catalog,
    required Map<String, ModelDownloadManager> routes,
  }) : routes = Map<String, ModelDownloadManager>.unmodifiable(routes);

  final ModelCatalog catalog;
  final Map<String, ModelDownloadManager> routes;
  final Map<String, ModelDownloadManager> _taskManagers =
      <String, ModelDownloadManager>{};

  ModelDownloadManager _managerFor(String modelId) {
    final ModelDownloadManager? manager = routes[modelId];
    if (manager == null || catalog.find(modelId) == null) {
      throw ArgumentError.value(modelId, 'modelId', 'Unknown model id.');
    }
    return manager;
  }

  @override
  EngineTask<ModelInstallResult> download(String modelId, {String? sourceId}) {
    final ModelDownloadManager manager = _managerFor(modelId);
    final EngineTask<ModelInstallResult> task = manager.download(
      modelId,
      sourceId: sourceId,
    );
    _taskManagers[task.id] = manager;
    unawaited(task.future.whenComplete(() => _taskManagers.remove(task.id)));
    return task;
  }

  @override
  EngineTask<ModelInstallResult> update(String modelId, {String? sourceId}) {
    final ModelDownloadManager manager = _managerFor(modelId);
    final EngineTask<ModelInstallResult> task = manager.update(
      modelId,
      sourceId: sourceId,
    );
    _taskManagers[task.id] = manager;
    unawaited(task.future.whenComplete(() => _taskManagers.remove(task.id)));
    return task;
  }

  @override
  Future<void> cancel(String taskId) async {
    await _taskManagers[taskId]?.cancel(taskId);
  }

  @override
  Future<void> delete(String modelId) => _managerFor(modelId).delete(modelId);
}
