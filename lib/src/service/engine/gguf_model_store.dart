import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../path_service.dart';
import 'engine_contract.dart';
import 'local_translation_model_catalog.dart';
import 'model_catalog.dart';

typedef GgufDiskSpaceProbe = Future<int?> Function(String path);

class GgufDownloadProgress {
  const GgufDownloadProgress({
    required this.artifactId,
    required this.receivedBytes,
    required this.artifactTotalBytes,
    required this.totalReceivedBytes,
    required this.totalBytes,
  });

  final String artifactId;
  final int receivedBytes;
  final int artifactTotalBytes;
  final int totalReceivedBytes;
  final int totalBytes;
}

/// Resumable, hash-checked storage for the GGUF translation catalog.
///
/// A failed request intentionally leaves `.partial/<model>/*.part` in place.
/// A successful set is moved into the final model directory in one rename, so
/// an update cannot expose a half-installed model to an engine process.
class GgufModelStore {
  GgufModelStore({
    ModelCatalog? catalog,
    Directory? rootDirectory,
    HttpClient? client,
    GgufDiskSpaceProbe? diskSpaceProbe,
  }) : catalog = catalog ?? LocalTranslationModelCatalog(),
       _rootDirectory = rootDirectory,
       _client = client ?? HttpClient(),
       _diskSpaceProbe = diskSpaceProbe ?? _defaultDiskSpaceProbe;

  static GgufModelStore? _instance;

  static GgufModelStore get instance =>
      _instance ??= GgufModelStore(catalog: LocalTranslationModelCatalog());

  final ModelCatalog catalog;
  final Directory? _rootDirectory;
  final HttpClient _client;
  final GgufDiskSpaceProbe _diskSpaceProbe;
  final Map<String, HttpClientRequest> _activeRequests =
      <String, HttpClientRequest>{};

  Directory get rootDirectory {
    final Directory? explicit = _rootDirectory;
    if (explicit != null) return explicit;
    try {
      return Directory(p.join(pathService.jhTranslationModelDir.path, 'gguf'));
    } on Object {
      throw StateError(
        'PathService must be initialized before using the GGUF model store.',
      );
    }
  }

  Future<ModelInstallState> installState(String modelId) async {
    final ModelDescriptor model = _model(modelId);
    final Directory directory = _finalDirectory(model.id);
    final File marker = File(p.join(directory.path, 'install.json'));
    if (!await marker.exists()) return ModelInstallState.notInstalled;
    try {
      final Map<dynamic, dynamic> record =
          jsonDecode(await marker.readAsString()) as Map<dynamic, dynamic>;
      if (record['fingerprint'] != model.fingerprint) {
        return ModelInstallState.invalid;
      }
      final List<dynamic> files = record['files'] as List<dynamic>? ?? const [];
      for (final ModelArtifactDescriptor artifact in model.artifacts) {
        final File file = File(p.join(directory.path, artifact.fileName));
        final Map<dynamic, dynamic>? saved = files
            .whereType<Map>()
            .cast<Map<dynamic, dynamic>?>()
            .firstWhere(
              (Map<dynamic, dynamic>? item) =>
                  item?['id']?.toString() == artifact.id,
              orElse: () => null,
            );
        if (saved == null || !await file.exists()) {
          return ModelInstallState.invalid;
        }
        final int expected = (saved['sizeBytes'] as num?)?.toInt() ?? -1;
        if (expected <= 0 || await file.length() != expected) {
          return ModelInstallState.invalid;
        }
      }
      return ModelInstallState.ready;
    } on Object {
      return ModelInstallState.invalid;
    }
  }

  /// Performs the expensive hash validation used immediately before loading a
  /// model into a runtime. The fast [installState] check is suitable for UI.
  Future<void> validateInstalled(String modelId) async {
    final ModelDescriptor model = _model(modelId);
    if (await installState(modelId) != ModelInstallState.ready) {
      throw StateError('GGUF model is not installed: $modelId');
    }
    final Directory directory = _finalDirectory(model.id);
    for (final ModelArtifactDescriptor artifact in model.artifacts) {
      final File file = File(p.join(directory.path, artifact.fileName));
      final Digest digest = await sha256.bind(file.openRead()).first;
      if (digest.toString().toLowerCase() != artifact.sha256.toLowerCase()) {
        throw StateError('SHA-256 mismatch for ${artifact.fileName}.');
      }
    }
  }

  bool isInstalledSync(String modelId) {
    try {
      final ModelDescriptor model = _model(modelId);
      final Directory directory = _finalDirectory(model.id);
      final File marker = File(p.join(directory.path, 'install.json'));
      if (!marker.existsSync()) return false;
      final Map<dynamic, dynamic> record =
          jsonDecode(marker.readAsStringSync()) as Map<dynamic, dynamic>;
      if (record['fingerprint'] != model.fingerprint) return false;
      for (final ModelArtifactDescriptor artifact in model.artifacts) {
        if (!File(p.join(directory.path, artifact.fileName)).existsSync()) {
          return false;
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  String artifactPath(String modelId, String artifactId) {
    final ModelDescriptor model = _model(modelId);
    final ModelArtifactDescriptor artifact = model.artifacts.firstWhere(
      (ModelArtifactDescriptor item) => item.id == artifactId,
      orElse: () => throw ArgumentError.value(artifactId, 'artifactId'),
    );
    return p.join(_finalDirectory(model.id).path, artifact.fileName);
  }

  Future<void> download(
    String modelId, {
    String? sourceId,
    bool forceUpdate = false,
    void Function(GgufDownloadProgress progress)? onProgress,
  }) async {
    final ModelDescriptor model = _model(modelId);
    if (!forceUpdate &&
        await installState(modelId) == ModelInstallState.ready) {
      return;
    }
    final Directory partial = _partialDirectory(model.id);
    await partial.create(recursive: true);
    final List<_ArtifactPlan> plans = <_ArtifactPlan>[];
    for (final ModelArtifactDescriptor artifact in model.artifacts) {
      final ModelSourceDescriptor source = _source(artifact, sourceId);
      final File part = File(p.join(partial.path, '${artifact.fileName}.part'));
      final int existing = await part.exists() ? await part.length() : 0;
      final int total =
          artifact.sizeBytes > 0
              ? artifact.sizeBytes
              : await _resolveRemoteLength(source.url);
      if (total <= 0) {
        throw StateError(
          'The source did not expose a usable Content-Length: ${source.url}',
        );
      }
      plans.add(
        _ArtifactPlan(
          artifact: artifact,
          source: source,
          part: part,
          existingBytes: existing > total ? 0 : existing,
          totalBytes: total,
        ),
      );
    }

    final int requiredBytes = plans.fold<int>(
      0,
      (int total, _ArtifactPlan plan) =>
          total + plan.totalBytes - plan.existingBytes,
    );
    final int? freeBytes = await _diskSpaceProbe(rootDirectory.path);
    if (freeBytes != null && freeBytes < requiredBytes + _safetyReserveBytes) {
      throw StateError(
        'Insufficient disk space: need $requiredBytes bytes plus reserve, have $freeBytes bytes.',
      );
    }

    final Map<String, int> received = <String, int>{
      for (final _ArtifactPlan plan in plans)
        plan.artifact.id: plan.existingBytes,
    };
    final int totalBytes = plans.fold<int>(
      0,
      (int total, _ArtifactPlan plan) => total + plan.totalBytes,
    );
    for (final _ArtifactPlan plan in plans) {
      await _downloadArtifact(
        modelId,
        plan,
        onProgress: (int value) {
          received[plan.artifact.id] = value;
          onProgress?.call(
            GgufDownloadProgress(
              artifactId: plan.artifact.id,
              receivedBytes: value,
              artifactTotalBytes: plan.totalBytes,
              totalReceivedBytes: received.values.fold<int>(
                0,
                (int sum, int item) => sum + item,
              ),
              totalBytes: totalBytes,
            ),
          );
        },
      );
      final Digest digest = await sha256.bind(plan.part.openRead()).first;
      if (digest.toString().toLowerCase() !=
          plan.artifact.sha256.toLowerCase()) {
        await plan.part.delete();
        throw StateError('SHA-256 mismatch for ${plan.artifact.fileName}.');
      }
    }

    for (final _ArtifactPlan plan in plans) {
      final File destination = File(
        p.join(partial.path, plan.artifact.fileName),
      );
      if (await destination.exists()) await destination.delete();
      await plan.part.rename(destination.path);
    }
    await File(p.join(partial.path, 'install.json')).writeAsString(
      jsonEncode(<String, dynamic>{
        'fingerprint': model.fingerprint,
        'files': plans
            .map(
              (_ArtifactPlan plan) => <String, dynamic>{
                'id': plan.artifact.id,
                'fileName': plan.artifact.fileName,
                'sizeBytes': plan.totalBytes,
                'sha256': plan.artifact.sha256,
              },
            )
            .toList(growable: false),
      }),
      flush: true,
    );
    await _promote(partial, _finalDirectory(model.id));
  }

  Future<void> cancel(String modelId) async {
    _activeRequests.remove(modelId)?.abort('model download cancelled');
  }

  Future<void> delete(String modelId) async {
    final ModelDescriptor model = _model(modelId);
    final Directory finalDirectory = _finalDirectory(model.id);
    final Directory partialDirectory = _partialDirectory(model.id);
    if (await finalDirectory.exists())
      await finalDirectory.delete(recursive: true);
    if (await partialDirectory.exists()) {
      await partialDirectory.delete(recursive: true);
    }
  }

  Future<void> _downloadArtifact(
    String modelId,
    _ArtifactPlan plan, {
    required void Function(int receivedBytes) onProgress,
  }) async {
    int offset = plan.existingBytes;
    HttpClientRequest request = await _client.getUrl(
      Uri.parse(plan.source.url),
    );
    if (offset > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
    }
    _activeRequests[modelId] = request;
    try {
      HttpClientResponse response = await request.close();
      if (offset > 0 &&
          response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await response.drain<void>();
        if (offset == plan.totalBytes) {
          onProgress(offset);
          return;
        }
        offset = 0;
        request = await _client.getUrl(Uri.parse(plan.source.url));
        _activeRequests[modelId] = request;
        response = await request.close();
      }
      final bool append =
          offset > 0 && response.statusCode == HttpStatus.partialContent;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw StateError(
          'HTTP ${response.statusCode} while downloading ${plan.artifact.fileName}.',
        );
      }
      if (!append) offset = 0;
      final IOSink sink = plan.part.openWrite(
        mode: append ? FileMode.append : FileMode.writeOnly,
      );
      int received = offset;
      onProgress(received);
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != plan.totalBytes) {
        throw StateError(
          'Incomplete download for ${plan.artifact.fileName}: $received/${plan.totalBytes}.',
        );
      }
    } finally {
      if (identical(_activeRequests[modelId], request)) {
        _activeRequests.remove(modelId);
      }
    }
  }

  Future<int> _resolveRemoteLength(String url) async {
    final HttpClientRequest head = await _client.openUrl(
      'HEAD',
      Uri.parse(url),
    );
    final HttpClientResponse headResponse = await head.close();
    final int headLength = headResponse.contentLength;
    await headResponse.drain<void>();
    if (headResponse.statusCode >= 200 &&
        headResponse.statusCode < 400 &&
        headLength > 0) {
      return headLength;
    }
    final HttpClientRequest probe = await _client.getUrl(Uri.parse(url));
    probe.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final HttpClientResponse probeResponse = await probe.close();
    final int? fromRange = _contentRangeTotal(
      probeResponse.headers.value(HttpHeaders.contentRangeHeader),
    );
    await probeResponse.drain<void>();
    if (fromRange != null && fromRange > 0) return fromRange;
    if (probeResponse.contentLength > 0) return probeResponse.contentLength;
    throw StateError('Unable to resolve remote file length: $url');
  }

  Future<void> _promote(Directory partial, Directory destination) async {
    final Directory root = rootDirectory;
    final Directory? backup =
        await destination.exists()
            ? Directory(
              p.join(
                root.path,
                '.backup-${p.basename(destination.path)}-${DateTime.now().microsecondsSinceEpoch}',
              ),
            )
            : null;
    if (backup != null) await destination.rename(backup.path);
    try {
      await partial.rename(destination.path);
      if (backup != null && await backup.exists()) {
        await backup.delete(recursive: true);
      }
    } catch (_) {
      if (backup != null &&
          await backup.exists() &&
          !await destination.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
  }

  ModelDescriptor _model(String modelId) =>
      catalog.find(modelId) ??
      (throw ArgumentError.value(modelId, 'modelId', 'Unknown GGUF model.'));

  ModelSourceDescriptor _source(
    ModelArtifactDescriptor artifact,
    String? sourceId,
  ) {
    if (artifact.sources.isEmpty) {
      throw StateError('No verified source for ${artifact.fileName}.');
    }
    if (sourceId == null) return artifact.sources.first;
    return artifact.sources.firstWhere(
      (ModelSourceDescriptor source) => source.id == sourceId,
      orElse:
          () =>
              throw StateError(
                'Unknown source $sourceId for ${artifact.fileName}.',
              ),
    );
  }

  Directory _finalDirectory(String modelId) =>
      Directory(p.join(rootDirectory.path, modelId));

  Directory _partialDirectory(String modelId) =>
      Directory(p.join(rootDirectory.path, '.partial', modelId));

  static int? _contentRangeTotal(String? value) {
    if (value == null) return null;
    final RegExpMatch? match = RegExp(r'/([0-9]+)$').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static Future<int?> _defaultDiskSpaceProbe(String path) async {
    if (Platform.isAndroid || Platform.isIOS) return null;
    try {
      final ProcessResult result = await Process.run('df', <String>[
        '-Pk',
        path,
      ]);
      if (result.exitCode != 0) return null;
      final List<String> lines = result.stdout.toString().trim().split('\n');
      if (lines.length < 2) return null;
      final List<String> fields = lines.last.trim().split(RegExp(r'\s+'));
      if (fields.length < 4) return null;
      final int? availableKiB = int.tryParse(fields[3]);
      return availableKiB == null ? null : availableKiB * 1024;
    } on Object {
      return null;
    }
  }

  static const int _safetyReserveBytes = 64 * 1024 * 1024;
}

class _ArtifactPlan {
  const _ArtifactPlan({
    required this.artifact,
    required this.source,
    required this.part,
    required this.existingBytes,
    required this.totalBytes,
  });

  final ModelArtifactDescriptor artifact;
  final ModelSourceDescriptor source;
  final File part;
  final int existingBytes;
  final int totalBytes;
}

class GgufModelDownloadManager implements ModelDownloadManager {
  GgufModelDownloadManager({GgufModelStore? store})
    : _store = store ?? GgufModelStore.instance;

  final GgufModelStore _store;
  final Map<String, String> _taskModels = <String, String>{};

  @override
  EngineTask<ModelInstallResult> download(String modelId, {String? sourceId}) =>
      _start(modelId, sourceId: sourceId, forceUpdate: false);

  @override
  EngineTask<ModelInstallResult> update(String modelId, {String? sourceId}) =>
      _start(modelId, sourceId: sourceId, forceUpdate: true);

  EngineTask<ModelInstallResult> _start(
    String modelId, {
    required String? sourceId,
    required bool forceUpdate,
  }) {
    final EngineTask<ModelInstallResult> task = EngineTask.start(
      operation: (EngineTaskContext context) async {
        final subscription = context.cancellation.onCancel.listen(
          (_) => _store.cancel(modelId),
        );
        try {
          await _store.download(
            modelId,
            sourceId: sourceId,
            forceUpdate: forceUpdate,
            onProgress: (GgufDownloadProgress progress) {
              final double fraction =
                  progress.totalBytes == 0
                      ? 0
                      : progress.totalReceivedBytes / progress.totalBytes;
              context.report(
                EngineTaskStage.processing,
                fraction,
                message: progress.artifactId,
              );
            },
          );
          context.report(EngineTaskStage.finalizing, 1);
          return ModelInstallResult(
            modelId: modelId,
            state: ModelInstallState.ready,
          );
        } on StateError catch (error) {
          throw EngineException(
            code: 'download_failed',
            message: error.message,
            engineId: 'gguf-model-download',
            cause: error,
          );
        } finally {
          await subscription.cancel();
        }
      },
    );
    _taskModels[task.id] = modelId;
    task.future.then<void>(
      (_) => _taskModels.remove(task.id),
      onError: (Object _, StackTrace __) => _taskModels.remove(task.id),
    );
    return task;
  }

  @override
  Future<void> cancel(String taskId) async {
    final String? modelId = _taskModels[taskId];
    if (modelId != null) await _store.cancel(modelId);
  }

  @override
  Future<void> delete(String modelId) => _store.delete(modelId);
}
