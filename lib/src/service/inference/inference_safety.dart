import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;

/// The state written before an accelerated inference starts.
///
/// A process kill cannot be caught by Dart. Persisting [running] before the
/// native call means the next process can treat an interrupted call exactly as
/// a failed canary and select CPU without trying the same provider again.
enum InferenceCanaryStatus { running, succeeded, failed }

/// Stable identity of one device/runtime/model/execution-provider combination.
/// The identity deliberately contains no account data or machine identifier
/// that is not already exposed by the platform device-info API.
class InferenceCanaryKey {
  const InferenceCanaryKey({
    required this.deviceModel,
    required this.systemVersion,
    required this.appVersion,
    required this.ortVersion,
    required this.modelHash,
    required this.epConfig,
  });

  final String deviceModel;
  final String systemVersion;
  final String appVersion;
  final String ortVersion;
  final String modelHash;
  final String epConfig;

  /// JSON is used as a deterministic, inspectable key. It is not intended to
  /// be a secret or an authentication token.
  String get stableId => jsonEncode(toJson());

  Map<String, String> toJson() => <String, String>{
    'deviceModel': deviceModel,
    'systemVersion': systemVersion,
    'appVersion': appVersion,
    'ortVersion': ortVersion,
    'modelHash': modelHash,
    'epConfig': epConfig,
  };

  factory InferenceCanaryKey.fromJson(Map<dynamic, dynamic> json) {
    String value(String key) => json[key]?.toString() ?? 'unknown';

    return InferenceCanaryKey(
      deviceModel: value('deviceModel'),
      systemVersion: value('systemVersion'),
      appVersion: value('appVersion'),
      ortVersion: value('ortVersion'),
      modelHash: value('modelHash'),
      epConfig: value('epConfig'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InferenceCanaryKey && other.stableId == stableId;

  @override
  int get hashCode => stableId.hashCode;
}

/// One persisted canary result. Only the last attempted configuration is
/// retained; a changed model hash or EP configuration gets a new key.
class InferenceCanaryRecord {
  const InferenceCanaryRecord({
    required this.status,
    required this.key,
    this.failureReason,
    this.timestamp,
  });

  final InferenceCanaryStatus status;
  final InferenceCanaryKey key;
  final String? failureReason;
  final String? timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.name,
    'key': key.toJson(),
    if (failureReason != null) 'failureReason': failureReason,
    if (timestamp != null) 'timestamp': timestamp,
  };

  factory InferenceCanaryRecord.fromJson(Map<dynamic, dynamic> json) {
    final String statusName = json['status']?.toString() ?? '';
    final InferenceCanaryStatus status = InferenceCanaryStatus.values
        .firstWhere(
          (InferenceCanaryStatus value) => value.name == statusName,
          orElse: () => InferenceCanaryStatus.failed,
        );
    final dynamic rawKey = json['key'];
    return InferenceCanaryRecord(
      status: status,
      key:
          rawKey is Map
              ? InferenceCanaryKey.fromJson(rawKey)
              : const InferenceCanaryKey(
                deviceModel: 'unknown',
                systemVersion: 'unknown',
                appVersion: 'unknown',
                ortVersion: 'unknown',
                modelHash: 'unknown',
                epConfig: 'unknown',
              ),
      failureReason: json['failureReason']?.toString(),
      timestamp: json['timestamp']?.toString(),
    );
  }
}

/// A bounded image size after adaptive scaling.
class InferencePixelSize {
  const InferencePixelSize(this.width, this.height);

  final int width;
  final int height;

  int get pixels => width * height;

  @override
  String toString() => '${width}x$height ($pixels pixels)';
}

/// Deterministic pixel-budget calculation shared by OCR and image SR.
class InferencePixelBudget {
  const InferencePixelBudget(this.maxPixels);

  final int maxPixels;

  InferencePixelSize fit(int width, int height, {int alignment = 1}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('image dimensions must be positive');
    }
    if (maxPixels <= 0 || alignment <= 0) {
      throw ArgumentError('pixel budget and alignment must be positive');
    }
    final int sourcePixels = width * height;
    if (sourcePixels <= maxPixels) {
      return InferencePixelSize(width, height);
    }
    final double scale = math.sqrt(maxPixels / sourcePixels);
    int fittedWidth = math.max(1, (width * scale).floor());
    int fittedHeight = math.max(1, (height * scale).floor());
    if (alignment > 1) {
      fittedWidth = math.max(alignment, fittedWidth ~/ alignment * alignment);
      fittedHeight = math.max(alignment, fittedHeight ~/ alignment * alignment);
    }
    while (fittedWidth * fittedHeight > maxPixels) {
      if (fittedWidth >= fittedHeight) {
        fittedWidth = math.max(alignment, fittedWidth - alignment);
      } else {
        fittedHeight = math.max(alignment, fittedHeight - alignment);
      }
    }
    return InferencePixelSize(fittedWidth, fittedHeight);
  }

  bool contains(int width, int height) =>
      width > 0 && height > 0 && width * height <= maxPixels;
}

/// A small FIFO queue used at both worker boundaries and session creation.
/// It is intentionally independent of Flutter so it can be tested without a
/// device, native plugin, or model file.
class InferenceTaskQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final Future<void> previous = _tail;
    final Completer<void> release = Completer<void>();
    _tail = release.future;
    return previous.then((_) => task()).whenComplete(() {
      if (!release.isCompleted) {
        release.complete();
      }
    });
  }
}

/// Options passed all the way to the native plugin's session creation call.
/// Input shape and memory limits are also enforced in Dart before a native run;
/// the native side receives them for diagnostics and future hard guards.
class InferenceSessionSafetyConfig {
  const InferenceSessionSafetyConfig({
    required this.useArena,
    required this.providerOptions,
    required this.sessionConfigEntries,
    this.mlComputeUnits,
    this.requireStaticShapes,
    this.inputShape,
    required this.memoryBudgetBytes,
    required this.maxInputPixels,
  });

  final bool useArena;
  final Map<String, Map<String, String>> providerOptions;
  final Map<String, String> sessionConfigEntries;
  final String? mlComputeUnits;
  final bool? requireStaticShapes;
  final List<int>? inputShape;
  final int memoryBudgetBytes;
  final int maxInputPixels;

  String get stableId => jsonEncode(<String, dynamic>{
    'useArena': useArena,
    'providerOptions': providerOptions,
    'sessionConfigEntries': sessionConfigEntries,
    'mlComputeUnits': mlComputeUnits,
    'requireStaticShapes': requireStaticShapes,
    'inputShape': inputShape,
    'memoryBudgetBytes': memoryBudgetBytes,
    'maxInputPixels': maxInputPixels,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'useArena': useArena,
    'providerOptions': providerOptions,
    'sessionConfigEntries': sessionConfigEntries,
    'mlComputeUnits': mlComputeUnits,
    'requireStaticShapes': requireStaticShapes,
    'inputShape': inputShape,
    'memoryBudgetBytes': memoryBudgetBytes,
    'maxInputPixels': maxInputPixels,
  };

  factory InferenceSessionSafetyConfig.fromMap(Map<dynamic, dynamic> map) {
    final dynamic rawProviderOptions = map['providerOptions'];
    final Map<String, Map<String, String>> providerOptions =
        <String, Map<String, String>>{};
    if (rawProviderOptions is Map) {
      for (final MapEntry<dynamic, dynamic> entry
          in rawProviderOptions.entries) {
        if (entry.key is String && entry.value is Map) {
          providerOptions[entry.key as String] = <String, String>{
            for (final MapEntry<dynamic, dynamic> option
                in (entry.value as Map).entries)
              if (option.key is String && option.value is String)
                option.key as String: option.value as String,
          };
        }
      }
    }
    final dynamic rawConfigEntries = map['sessionConfigEntries'];
    return InferenceSessionSafetyConfig(
      useArena: map['useArena'] as bool? ?? true,
      providerOptions: providerOptions,
      sessionConfigEntries:
          rawConfigEntries is Map
              ? <String, String>{
                for (final MapEntry<dynamic, dynamic> entry
                    in rawConfigEntries.entries)
                  if (entry.key is String && entry.value is String)
                    entry.key as String: entry.value as String,
              }
              : const <String, String>{},
      mlComputeUnits: map['mlComputeUnits']?.toString(),
      requireStaticShapes: map['requireStaticShapes'] as bool?,
      inputShape: (map['inputShape'] as List?)?.whereType<int>().toList(),
      memoryBudgetBytes:
          (map['memoryBudgetBytes'] as num?)?.toInt() ?? 128 * 1024 * 1024,
      maxInputPixels:
          (map['maxInputPixels'] as num?)?.toInt() ?? 4 * 1024 * 1024,
    );
  }
}

typedef InferenceCanaryLifecycle =
    Future<void> Function(String modelHash, List<ort.OrtProvider> providers);

typedef InferenceCanaryFailureLifecycle =
    Future<void> Function(
      String modelHash,
      List<ort.OrtProvider> providers,
      Object error,
    );

/// Conservative policy shared by the settings service and both worker
/// engines. Auto mode is CPU-only; an accelerator is an explicit opt-in and
/// remains blocked after an interrupted/failed canary for the same key.
class InferenceProviderPolicy {
  static const Set<String> highRiskBackends = <String>{
    'coreml',
    'nnapi',
    'cuda',
    'directml',
    'openvino',
  };

  static bool isAccelerated(String backend) =>
      highRiskBackends.contains(backend);

  static bool isCanaryBlocked(
    InferenceCanaryKey key,
    InferenceCanaryRecord? record,
  ) =>
      record != null &&
      record.key == key &&
      record.status != InferenceCanaryStatus.succeeded;

  static List<ort.OrtProvider> providers({
    required String backend,
    required List<ort.OrtProvider> available,
    required bool enableNnapi,
    required bool enableCpuFallback,
    required bool canaryBlocked,
  }) {
    final ort.OrtProvider? requested = _providerForBackend(backend);
    final bool nnapiDisabled = backend == 'nnapi' && !enableNnapi;
    final ort.OrtProvider? primary =
        nnapiDisabled || canaryBlocked ? null : requested;
    final List<ort.OrtProvider> result = <ort.OrtProvider>[];
    if (primary != null && available.contains(primary)) {
      result.add(primary);
    }
    if ((result.isEmpty || enableCpuFallback) &&
        available.contains(ort.OrtProvider.CPU)) {
      result.add(ort.OrtProvider.CPU);
    }
    return result;
  }

  static InferenceSessionSafetyConfig sessionConfig({
    required String backend,
    required int maxInputPixels,
    required int memoryBudgetBytes,
    List<int>? inputShape,
  }) {
    final bool coreMl = backend == 'coreml';
    final Map<String, Map<String, String>> providerOptions =
        <String, Map<String, String>>{};
    if (coreMl) {
      providerOptions['CORE_ML'] = <String, String>{
        'MLComputeUnits': 'CPUAndNeuralEngine',
        'RequireStaticInputShapes': '1',
      };
    }
    final bool useArena = !isAccelerated(backend);
    return InferenceSessionSafetyConfig(
      useArena: useArena,
      providerOptions: providerOptions,
      sessionConfigEntries: <String, String>{
        'session.enable_cpu_mem_arena': useArena ? '1' : '0',
      },
      mlComputeUnits: coreMl ? 'CPUAndNeuralEngine' : null,
      requireStaticShapes: coreMl ? true : null,
      inputShape: inputShape,
      memoryBudgetBytes: memoryBudgetBytes,
      maxInputPixels: maxInputPixels,
    );
  }

  static ort.OrtProvider? _providerForBackend(String backend) =>
      switch (backend) {
        'cpu' => ort.OrtProvider.CPU,
        'directml' => ort.OrtProvider.DIRECT_ML,
        'cuda' => ort.OrtProvider.CUDA,
        'openvino' => ort.OrtProvider.OPEN_VINO,
        'nnapi' => ort.OrtProvider.NNAPI,
        'coreml' => ort.OrtProvider.CORE_ML,
        'xnnpack' => ort.OrtProvider.XNNPACK,
        _ => null,
      };
}
