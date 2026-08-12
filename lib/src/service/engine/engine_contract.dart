import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:jhentai/src/model/image_translation.dart';

/// Stable names for the independent stages of the image pipeline.
enum EngineKind {
  detection,
  ocr,
  translation,
  inpaint,
  superResolution,
  modelCatalog,
  modelDownload,
}

enum EnginePlatform { android, ios, linux, macos, web, windows, unknown }

enum EngineTaskLifecycle { queued, running, succeeded, cancelled, failed }

enum EngineTaskStage { queued, loading, processing, finalizing, completed }

/// Selects how translated pages are rendered without ever mutating the source
/// image. Only the first two modes are user-facing until a translated raster
/// compositor is available.
enum ImageProcessingDisplayMode {
  overlay,
  repairedBackgroundEmbeddedText,
  translatedImage,
}

class EngineTaskProgress {
  const EngineTaskProgress({
    required this.taskId,
    required this.stage,
    required this.fraction,
    this.message,
    this.speedBytesPerSecond = 0,
  });

  final String taskId;
  final EngineTaskStage stage;
  final double fraction;
  final String? message;

  /// Optional instantaneous transfer rate, used by download stages to render
  /// a live MB/s label. Zero means the stage reports no speed.
  final double speedBytesPerSecond;
}

/// Cancellation is deliberately independent from inference/HTTP implementations.
/// Adapters bridge this token to their native, isolate, or Dio cancellation.
class EngineCancellationToken {
  final StreamController<String> _cancelController =
      StreamController<String>.broadcast(sync: true);
  bool _cancelled = false;
  String _reason = 'cancelled';
  Future<void>? _disposeFuture;

  bool get isCancelled => _cancelled;
  String get reason => _reason;
  Stream<String> get onCancel => _cancelController.stream;

  void cancel([String reason = 'cancelled']) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason;
    _cancelController.add(reason);
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw EngineTaskCancelledException(reason);
    }
  }

  /// A synchronous controller cannot be closed while a cancellation event is
  /// being delivered. Native/fake adapters may complete their cancellation
  /// future from that event, so defer close to the next microtask and make
  /// disposal idempotent. This preserves the token API while avoiding the
  /// documented synchronous-controller re-entrancy failure.
  Future<void> dispose() {
    final Future<void>? existing = _disposeFuture;
    if (existing != null) return existing;
    final Completer<void> completer = Completer<void>();
    _disposeFuture = completer.future;
    scheduleMicrotask(() async {
      try {
        await _cancelController.close();
        completer.complete();
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }
}

class EngineException implements Exception {
  const EngineException({
    required this.code,
    required this.message,
    required this.engineId,
    this.cause,
  });

  final String code;
  final String message;
  final String engineId;
  final Object? cause;

  @override
  String toString() => 'EngineException[$engineId/$code]: $message';
}

class EngineTaskCancelledException extends EngineException {
  EngineTaskCancelledException([String reason = 'cancelled'])
    : super(code: 'cancelled', message: reason, engineId: 'engine-task');
}

typedef EngineTaskOperation<T> = Future<T> Function(EngineTaskContext context);

/// A task is the only lifecycle surface an adapter exposes to callers.
/// It gives every stage the same id, progress stream, cancellation and error
/// semantics while keeping the underlying implementation free to use isolates,
/// native channels, or HTTP.
class EngineTask<T> {
  EngineTask._({required this.id, required EngineCancellationToken token})
    : cancellation = token {
    _emit(
      const EngineTaskProgress(
        taskId: 'pending',
        stage: EngineTaskStage.queued,
        fraction: 0,
      ),
    );
  }

  static int _nextSequence = 0;

  factory EngineTask.start({
    String? id,
    required EngineTaskOperation<T> operation,
  }) {
    final EngineTask<T> task = EngineTask<T>._(
      id: id ?? _newId(),
      token: EngineCancellationToken(),
    );
    unawaited(Future<void>.microtask(() => task._run(operation)));
    return task;
  }

  static String _newId() =>
      'engine-task-${DateTime.now().microsecondsSinceEpoch}-${++_nextSequence}';

  final String id;
  final EngineCancellationToken cancellation;
  final Completer<T> _completer = Completer<T>();
  final StreamController<EngineTaskProgress> _progressController =
      StreamController<EngineTaskProgress>.broadcast(sync: true);
  late final Future<T> future = _completer.future;
  EngineTaskLifecycle _lifecycle = EngineTaskLifecycle.queued;
  EngineException? _error;

  EngineTaskLifecycle get lifecycle => _lifecycle;
  EngineException? get error => _error;
  Stream<EngineTaskProgress> get progress => _progressController.stream;

  void cancel([String reason = 'cancelled']) => cancellation.cancel(reason);

  void _emit(EngineTaskProgress progress) {
    if (_progressController.isClosed) return;
    _progressController.add(
      EngineTaskProgress(
        taskId: id,
        stage: progress.stage,
        fraction: progress.fraction.clamp(0, 1).toDouble(),
        message: progress.message,
        speedBytesPerSecond: progress.speedBytesPerSecond,
      ),
    );
  }

  Future<void> _run(EngineTaskOperation<T> operation) async {
    _lifecycle = EngineTaskLifecycle.running;
    _emit(
      const EngineTaskProgress(
        taskId: 'pending',
        stage: EngineTaskStage.loading,
        fraction: 0,
      ),
    );
    try {
      final T result = await operation(
        EngineTaskContext._(id: id, cancellation: cancellation, report: _emit),
      );
      cancellation.throwIfCancelled();
      _lifecycle = EngineTaskLifecycle.succeeded;
      _emit(
        const EngineTaskProgress(
          taskId: 'pending',
          stage: EngineTaskStage.completed,
          fraction: 1,
        ),
      );
      _completer.complete(result);
    } on EngineException catch (error, stack) {
      _completeError(error, stack);
    } catch (error, stack) {
      if (cancellation.isCancelled) {
        _completeError(
          EngineTaskCancelledException(cancellation.reason),
          stack,
        );
      } else {
        _completeError(
          EngineException(
            code: 'unexpected',
            message: error.toString(),
            engineId: 'engine-task',
            cause: error,
          ),
          stack,
        );
      }
    } finally {
      await cancellation.dispose();
      await _progressController.close();
    }
  }

  void _completeError(EngineException error, StackTrace stack) {
    _error = error;
    _lifecycle =
        error is EngineTaskCancelledException
            ? EngineTaskLifecycle.cancelled
            : EngineTaskLifecycle.failed;
    if (!_completer.isCompleted) {
      _completer.completeError(error, stack);
    }
  }
}

class EngineTaskContext {
  const EngineTaskContext._({
    required this.id,
    required this.cancellation,
    required void Function(EngineTaskProgress progress) report,
  }) : _report = report;

  final String id;
  final EngineCancellationToken cancellation;
  final void Function(EngineTaskProgress progress) _report;

  void report(
    EngineTaskStage stage,
    double fraction, {
    String? message,
    double speedBytesPerSecond = 0,
  }) {
    cancellation.throwIfCancelled();
    _report(
      EngineTaskProgress(
        taskId: id,
        stage: stage,
        fraction: fraction,
        message: message,
        speedBytesPerSecond: speedBytesPerSecond,
      ),
    );
  }
}

class EngineDescriptor {
  const EngineDescriptor({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.platforms,
    this.modelId,
  });

  final String id;
  final EngineKind kind;
  final String displayName;
  final Set<EnginePlatform> platforms;
  final String? modelId;

  bool supports(EnginePlatform platform) => platforms.contains(platform);
}

class EngineImageRequest {
  const EngineImageRequest({
    required this.imagePath,
    this.configuration = const <String, dynamic>{},
  });

  final String imagePath;
  final Map<String, dynamic> configuration;
}

/// A point in the source image's upright pixel coordinate space.
///
/// Polygon coordinates deliberately stay in image pixels instead of being
/// silently normalized or converted to a rectangle. The same points can be
/// rasterized into an inpainting mask without losing the detector's shape.
class EnginePoint {
  const EnginePoint({required this.x, required this.y});

  final double x;
  final double y;

  bool get isFinite => x.isFinite && y.isFinite;

  Map<String, double> toJson() => <String, double>{'x': x, 'y': y};
}

/// A pixel-accurate text mask emitted by a detector such as CTD.
///
/// [points] are an ordered, closed-or-open polygon in source image pixels.
/// Consumers must preserve the polygon when creating a mask; the bounding box
/// is only a compatibility projection for older rectangle-only consumers.
class PolygonMask {
  const PolygonMask({required this.points, this.confidence = 0});

  final List<EnginePoint> points;
  final double confidence;

  bool get isValid {
    if (points.length < 3 ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        points.any((EnginePoint point) => !point.isFinite)) {
      return false;
    }
    double area = 0;
    for (int index = 0; index < points.length; index++) {
      final EnginePoint current = points[index];
      final EnginePoint next = points[(index + 1) % points.length];
      area += current.x * next.y - next.x * current.y;
    }
    return area.abs() > 0.5;
  }

  double get left =>
      points.map((EnginePoint point) => point.x).reduce(math.min);
  double get top => points.map((EnginePoint point) => point.y).reduce(math.min);
  double get right =>
      points.map((EnginePoint point) => point.x).reduce(math.max);
  double get bottom =>
      points.map((EnginePoint point) => point.y).reduce(math.max);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'points': points.map((EnginePoint point) => point.toJson()).toList(),
    'confidence': confidence,
  };
}

class DetectionResult {
  const DetectionResult({
    required this.regions,
    this.polygonMasks = const <PolygonMask>[],
  });

  final List<DetectedTextRegion> regions;

  /// Polygon output is authoritative for mask consumers. [regions] remains a
  /// rectangle projection for OCR/layout code that has not adopted polygons.
  final List<PolygonMask> polygonMasks;
}

class DetectedTextRegion {
  const DetectedTextRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.confidence = 0,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
}

abstract class DetectionEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<DetectionResult> detect(EngineImageRequest request);
}

class OcrEngineRequest extends EngineImageRequest {
  const OcrEngineRequest({
    required super.imagePath,
    super.configuration,
    this.maxDimension = 2200,
    this.regions = const <DetectedTextRegion>[],
  });

  final int maxDimension;
  final List<DetectedTextRegion> regions;
}

class OcrResult {
  const OcrResult({required this.blocks, this.imageWidth, this.imageHeight});

  final List<RecognizedTextBlock> blocks;
  final int? imageWidth;
  final int? imageHeight;
}

abstract class OcrEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<OcrResult> recognize(OcrEngineRequest request);
}

class TranslationEngineRequest {
  const TranslationEngineRequest({
    required this.blocks,
    required this.targetLanguage,
    this.imagePath,
    this.sourceLanguage,
    this.configuration = const <String, dynamic>{},
    this.promptVersion = 1,
    this.mergeTextBlocks = true,
    this.containers = const <RecognizedTextContainer>[],
  });

  final List<RecognizedTextBlock> blocks;
  final String targetLanguage;

  /// Optional source image for a multimodal GGUF. Text-only engines ignore it.
  final String? imagePath;
  final String? sourceLanguage;
  final Map<String, dynamic> configuration;
  final int promptVersion;

  /// Whether adjacent OCR blocks in the same visual container may be
  /// translated and rendered as one utterance.
  final bool mergeTextBlocks;

  /// Optional speech-bubble/container membership produced by a detector.
  /// When present, translation grouping must respect these memberships.
  final List<RecognizedTextContainer> containers;
}

class TranslationResult {
  const TranslationResult({
    required this.translatedText,
    required this.lines,
    this.groupTranslations = const <String>[],
  });

  final String translatedText;
  final List<String> lines;

  /// One natural translation per visual speech-bubble group. [lines] remains
  /// the stable OCR-block mapping used by older callers; keeping the original
  /// group text lets renderers wrap an utterance without re-splitting it.
  final List<String> groupTranslations;
}

abstract class TranslationEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<TranslationResult> translate(TranslationEngineRequest request);
}

abstract interface class EngineReadiness {
  Future<bool> ensureReady();
}

/// Optional asynchronous readiness for adapters backed by a native/plugin
/// runtime. Existing adapters keep their synchronous behavior by default;
/// native adapters can provide a same-named member to perform a real probe.
extension TranslationEngineReadiness on TranslationEngine {
  Future<bool> ensureReady() async {
    final TranslationEngine engine = this;
    return engine is EngineReadiness ? engine.ensureReady() : engine.isReady;
  }
}

class ImageProcessingRequest extends EngineImageRequest {
  const ImageProcessingRequest({
    required super.imagePath,
    required this.outputPath,
    super.configuration,
    this.polygonMasks = const <PolygonMask>[],
  });

  final String outputPath;

  /// Optional polygon masks in source-image pixel coordinates. Inpainting
  /// adapters must reject an empty set instead of inventing rectangle masks.
  final List<PolygonMask> polygonMasks;
}

abstract class InpaintEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<String> inpaint(ImageProcessingRequest request);
}

abstract class SuperResolutionEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<String> upscale(ImageProcessingRequest request, {int scale = 4});
}

/// A deterministic key for every persisted translation/image-processing result.
/// It intentionally includes all inputs that can change the output.
class EngineCacheKey {
  const EngineCacheKey({
    required this.sourceHash,
    required this.ocrModel,
    required this.ocrConfiguration,
    required this.translationModel,
    required this.translationConfiguration,
    required this.promptVersion,
    required this.pipelineVersion,
  });

  final String sourceHash;
  final String? ocrModel;
  final Map<String, dynamic> ocrConfiguration;
  final String? translationModel;
  final Map<String, dynamic> translationConfiguration;
  final int promptVersion;
  final String pipelineVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceHash': sourceHash,
    'ocrModel': ocrModel,
    'ocrConfiguration': _canonicalize(ocrConfiguration),
    'translationModel': translationModel,
    'translationConfiguration': _canonicalize(translationConfiguration),
    'promptVersion': promptVersion,
    'pipelineVersion': pipelineVersion,
  };

  String get canonicalJson => jsonEncode(toJson());

  String get value => sha256.convert(utf8.encode(canonicalJson)).toString();
}

dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final List<String> keys =
        value.keys.map((Object? key) => '$key').toList()..sort();
    return <String, dynamic>{
      for (final String key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList();
  }
  return value;
}
