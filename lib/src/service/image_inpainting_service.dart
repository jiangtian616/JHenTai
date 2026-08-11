import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';

import 'engine/engine.dart';
import 'inference_service.dart';
import 'jh_service.dart';
import 'path_service.dart';

enum InpaintingStatus { idle, queued, running, success, canceled, failed }

class InpaintingResult {
  const InpaintingResult({
    required this.status,
    this.outputPath,
    this.translatedImagePath,
    this.errorCode,
    this.fromCache = false,
    this.fallbackToOverlay = false,
    this.sourceHash,
  });

  const InpaintingResult.idle() : this(status: InpaintingStatus.idle);

  final InpaintingStatus status;
  final String? outputPath;
  final String? translatedImagePath;
  final String? errorCode;
  final bool fromCache;
  final bool fallbackToOverlay;
  final String? sourceHash;

  InpaintingResult copyWith({
    InpaintingStatus? status,
    String? outputPath,
    String? translatedImagePath,
    String? errorCode,
    bool? fromCache,
    bool? fallbackToOverlay,
    String? sourceHash,
  }) => InpaintingResult(
    status: status ?? this.status,
    outputPath: outputPath ?? this.outputPath,
    translatedImagePath: translatedImagePath ?? this.translatedImagePath,
    errorCode: errorCode,
    fromCache: fromCache ?? this.fromCache,
    fallbackToOverlay: fallbackToOverlay ?? this.fallbackToOverlay,
    sourceHash: sourceHash ?? this.sourceHash,
  );
}

/// Owns only derived inpainting artifacts. It never replaces or writes the
/// source image, so switching display modes cannot destroy the original page.
class ImageInpaintingService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  ImageInpaintingService({EngineRegistry? registry})
    : engineRegistry = registry ?? EngineRegistry();

  final EngineRegistry engineRegistry;
  final Map<String, InpaintingResult> _results = <String, InpaintingResult>{};
  final Map<String, String> _artifactKeys = <String, String>{};
  final Map<String, EngineTask<String>> _activeTasks =
      <String, EngineTask<String>>{};
  final Map<String, EngineTask<DetectionResult>> _activeDetectionTasks =
      <String, EngineTask<DetectionResult>>{};
  final Map<String, String> _translatedImagePaths = <String, String>{};
  Directory? _cacheDirectoryOverride;

  ImageProcessingDisplayMode displayMode = ImageProcessingDisplayMode.overlay;

  Directory get _cacheDirectory =>
      _cacheDirectoryOverride ??
      Directory(join(pathService.jhOcrModelDir.path, 'inpainting-cache'));

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..add(inferenceService);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  InpaintingResult resultFor(String requestKey) =>
      _results[requestKey] ?? const InpaintingResult.idle();

  @visibleForTesting
  void setCacheDirectoryForTesting(Directory? directory) {
    _cacheDirectoryOverride = directory;
  }

  void setDisplayMode(ImageProcessingDisplayMode mode) {
    displayMode = mode;
    update();
  }

  /// Returns the derived image for the selected display mode, or null when
  /// normal overlay rendering must remain the fallback.
  String? displayPathFor(String requestKey) {
    final InpaintingResult result = resultFor(requestKey);
    if (displayMode == ImageProcessingDisplayMode.overlay) {
      return null;
    }
    if (displayMode == ImageProcessingDisplayMode.translatedImage) {
      final String? translated =
          _translatedImagePaths[requestKey] ?? result.translatedImagePath;
      if (translated != null && File(translated).existsSync()) {
        return translated;
      }
    }
    final String? repaired = result.outputPath;
    return result.status == InpaintingStatus.success &&
            repaired != null &&
            File(repaired).existsSync()
        ? repaired
        : null;
  }

  bool shouldDrawTranslationOverlay(String requestKey) =>
      !(displayMode == ImageProcessingDisplayMode.translatedImage &&
          displayPathFor(requestKey) != null &&
          _translatedImagePaths[requestKey] != null);

  void publishTranslatedImage(String requestKey, String path) {
    if (!File(path).existsSync()) {
      return;
    }
    _translatedImagePaths[requestKey] = path;
    final InpaintingResult current = resultFor(requestKey);
    _results[requestKey] = current.copyWith(translatedImagePath: path);
    update([requestKey]);
  }

  /// Runs the complete optional CTD -> MI-GAN pipeline. CTD polygons are the
  /// only accepted masks: OCR rectangles are never substituted because that
  /// would erase artwork outside the actual text glyphs.
  Future<InpaintingResult> detectAndRepair({
    required String requestKey,
    required String sourcePath,
    bool force = false,
  }) async {
    _set(requestKey, const InpaintingResult(status: InpaintingStatus.queued));
    final File source = File(sourcePath);
    if (!await source.exists()) {
      return _fail(requestKey, 'source_unavailable');
    }
    final DetectionEngine? detector = engineRegistry.findDetection(
      'ctd-detection',
    );
    if (detector == null || !detector.isReady) {
      return _fail(requestKey, 'ctd_not_ready');
    }
    final EngineTask<DetectionResult> task = detector.detect(
      EngineImageRequest(imagePath: sourcePath),
    );
    _activeDetectionTasks[requestKey] = task;
    _set(requestKey, const InpaintingResult(status: InpaintingStatus.running));
    try {
      final DetectionResult detection = await task.future;
      if (detection.polygonMasks.isEmpty) {
        return _fail(requestKey, 'ctd_no_text');
      }
      return repair(
        requestKey: requestKey,
        sourcePath: sourcePath,
        polygonMasks: detection.polygonMasks,
        force: force,
      );
    } on EngineTaskCancelledException {
      const InpaintingResult result = InpaintingResult(
        status: InpaintingStatus.canceled,
        errorCode: 'canceled',
        fallbackToOverlay: true,
      );
      _set(requestKey, result);
      return result;
    } on EngineException catch (error) {
      return _fail(requestKey, error.code);
    } catch (_) {
      return _fail(requestKey, 'ctd_failed');
    } finally {
      if (identical(_activeDetectionTasks[requestKey], task)) {
        _activeDetectionTasks.remove(requestKey);
      }
    }
  }

  Future<InpaintingResult> repair({
    required String requestKey,
    required String sourcePath,
    required List<PolygonMask> polygonMasks,
    bool force = false,
  }) async {
    _set(requestKey, const InpaintingResult(status: InpaintingStatus.queued));
    final File source = File(sourcePath);
    if (!await source.exists()) {
      return _fail(requestKey, 'source_unavailable');
    }
    if (polygonMasks.isEmpty ||
        polygonMasks.any((PolygonMask mask) => !mask.isValid)) {
      return _fail(requestKey, 'polygon_mask_required');
    }

    final String sourceHash = await _sha256(source);
    final String maskHash = _maskHash(polygonMasks);
    final ModelDescriptor? descriptor = engineRegistry.modelCatalog.find(
      'migan-pipeline-v2',
    );
    final String modelFingerprint = descriptor?.fingerprint ?? 'unverified';
    final String artifactKey = _artifactKey(
      sourceHash,
      maskHash,
      modelFingerprint,
    );
    _artifactKeys[requestKey] = artifactKey;
    final File output = File(join(_cacheDirectory.path, '$artifactKey.png'));
    final File metadata = File(join(_cacheDirectory.path, '$artifactKey.json'));

    if (!force) {
      final InpaintingResult? cached = await _readCache(
        metadata,
        output,
        sourceHash: sourceHash,
        maskHash: maskHash,
        modelFingerprint: modelFingerprint,
      );
      if (cached != null) {
        _set(requestKey, cached);
        return cached;
      }
    }

    final InpaintEngine? engine = engineRegistry.findInpaint(
      'onnx-migan-inpaint',
    );
    if (engine == null || !engine.isReady) {
      return _fail(requestKey, 'inpaint_not_ready', sourceHash: sourceHash);
    }
    final EngineTask<String> task = engine.inpaint(
      ImageProcessingRequest(
        imagePath: sourcePath,
        outputPath: output.path,
        polygonMasks: polygonMasks,
        configuration: <String, dynamic>{
          'modelFingerprint': modelFingerprint,
          'maskFingerprint': maskHash,
        },
      ),
    );
    _activeTasks[requestKey] = task;
    _set(
      requestKey,
      InpaintingResult(
        status: InpaintingStatus.running,
        sourceHash: sourceHash,
      ),
    );
    try {
      final String outputPath = await task.future;
      if (!await File(outputPath).exists()) {
        return _fail(requestKey, 'output_missing', sourceHash: sourceHash);
      }
      final String outputHash = await _sha256(File(outputPath));
      await _writeMetadata(metadata, <String, dynamic>{
        'schemaVersion': 1,
        'sourceHash': sourceHash,
        'maskHash': maskHash,
        'modelFingerprint': modelFingerprint,
        'outputHash': outputHash,
        'outputPath': outputPath,
      });
      final InpaintingResult result = InpaintingResult(
        status: InpaintingStatus.success,
        outputPath: outputPath,
        sourceHash: sourceHash,
      );
      _set(requestKey, result);
      return result;
    } on EngineTaskCancelledException {
      final InpaintingResult result = InpaintingResult(
        status: InpaintingStatus.canceled,
        sourceHash: sourceHash,
        errorCode: 'canceled',
        fallbackToOverlay: true,
      );
      _set(requestKey, result);
      return result;
    } on EngineException catch (error) {
      return _fail(requestKey, error.code, sourceHash: sourceHash);
    } catch (_) {
      return _fail(requestKey, 'inpaint_failed', sourceHash: sourceHash);
    } finally {
      if (identical(_activeTasks[requestKey], task)) {
        _activeTasks.remove(requestKey);
      }
    }
  }

  void cancel(String requestKey) {
    _activeDetectionTasks[requestKey]?.cancel('detection cancelled');
    _activeTasks[requestKey]?.cancel('inpainting cancelled');
  }

  Future<void> clearCache({String? requestKey}) async {
    if (requestKey == null) {
      if (await _cacheDirectory.exists()) {
        await for (final FileSystemEntity entity in _cacheDirectory.list()) {
          if (entity is File &&
              (entity.path.endsWith('.png') || entity.path.endsWith('.json'))) {
            await entity.delete();
          }
        }
      }
      _results.clear();
      _artifactKeys.clear();
      _translatedImagePaths.clear();
      update();
      return;
    }
    final String? artifactKey = _artifactKeys.remove(requestKey);
    if (artifactKey != null) {
      for (final String suffix in const <String>['.png', '.json']) {
        final File file = File(
          join(_cacheDirectory.path, '$artifactKey$suffix'),
        );
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    _results.remove(requestKey);
    _translatedImagePaths.remove(requestKey);
    update([requestKey]);
  }

  InpaintingResult _fail(String requestKey, String code, {String? sourceHash}) {
    final InpaintingResult result = InpaintingResult(
      status: InpaintingStatus.failed,
      errorCode: code,
      sourceHash: sourceHash,
      fallbackToOverlay: true,
    );
    _set(requestKey, result);
    return result;
  }

  void _set(String requestKey, InpaintingResult result) {
    _results[requestKey] = result;
    update([requestKey]);
  }

  Future<InpaintingResult?> _readCache(
    File metadata,
    File output, {
    required String sourceHash,
    required String maskHash,
    required String modelFingerprint,
  }) async {
    if (!await metadata.exists() || !await output.exists()) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(await metadata.readAsString());
      if (decoded is! Map ||
          decoded['sourceHash'] != sourceHash ||
          decoded['maskHash'] != maskHash ||
          decoded['modelFingerprint'] != modelFingerprint ||
          decoded['outputPath'] != output.path) {
        return null;
      }
      if (decoded['outputHash'] != await _sha256(output)) {
        return null;
      }
      return InpaintingResult(
        status: InpaintingStatus.success,
        outputPath: output.path,
        fromCache: true,
        sourceHash: sourceHash,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMetadata(File file, Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(value), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  String _maskHash(List<PolygonMask> masks) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode(
                masks.map((PolygonMask mask) => mask.toJson()).toList(),
              ),
            ),
          )
          .toString();

  String _artifactKey(String sourceHash, String maskHash, String modelHash) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode(<String, String>{
                'sourceHash': sourceHash,
                'maskHash': maskHash,
                'modelHash': modelHash,
                'pipeline': 'inpainting-v1',
              }),
            ),
          )
          .toString();
}

ImageInpaintingService imageInpaintingService = ImageInpaintingService();
