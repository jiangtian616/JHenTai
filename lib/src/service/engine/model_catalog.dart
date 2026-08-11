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
  });

  final String id;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final List<ModelSourceDescriptor> sources;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
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

  Future<void> cancel(String taskId);
  Future<void> delete(String modelId);
}
