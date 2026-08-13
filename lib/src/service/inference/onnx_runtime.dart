import 'dart:async';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:jhentai/src/service/log.dart';

import 'inference_safety.dart';

/// Diagnostic sink for ONNX Runtime lifecycle events.
///
/// The app-wide default writes through the global [log] singleton. The OCR
/// worker isolate passes a no-op sink instead: the global `log` depends on
/// UI-isolate services (`pathService`) that are never initialized there, so
/// logging from the worker would throw `LateInitializationError`.
abstract interface class OnnxRuntimeLog {
  void info(String message);
  void warning(String message);
  void trace(Object message);
}

class _DefaultOnnxRuntimeLog implements OnnxRuntimeLog {
  const _DefaultOnnxRuntimeLog();

  @override
  void info(String message) => log.info(message);

  @override
  void warning(String message) => log.warning(message);

  @override
  void trace(Object message) => log.trace(message);
}

class _NoopOnnxRuntimeLog implements OnnxRuntimeLog {
  const _NoopOnnxRuntimeLog();

  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void trace(Object message) {}
}

/// A no-op [OnnxRuntimeLog] for the OCR worker isolate.
const OnnxRuntimeLog noopOnnxRuntimeLog = _NoopOnnxRuntimeLog();

/// Process-wide ONNX Runtime owner.
///
/// Initialization and session creation are single-flight. Sessions are keyed
/// by model fingerprint and execution-provider order, so changing backend or
/// replacing a model never reuses a stale native session.
///
/// The constructor is public so the OCR worker isolate can own a private
/// instance alongside the app-wide [instance]; every instance keeps its own
/// provider list, session cache and lifecycle leases. [log] overrides where
/// diagnostics go (the worker passes [noopOnnxRuntimeLog]).
class OnnxRuntime {
  OnnxRuntime({OnnxRuntimeLog? log})
    : _log = log ?? const _DefaultOnnxRuntimeLog();

  final OnnxRuntimeLog _log;

  static final OnnxRuntime instance = OnnxRuntime();

  ort.OnnxRuntime? _engine;
  final List<ort.OrtProvider> _providers = <ort.OrtProvider>[];
  final Map<String, _SessionEntry> _sessions = <String, _SessionEntry>{};
  final Set<_SessionEntry> _allSessions = <_SessionEntry>{};
  final Map<String, Future<ort.OrtSession?>> _creatingSessions =
      <String, Future<ort.OrtSession?>>{};
  final InferenceTaskQueue _sessionCreationQueue = InferenceTaskQueue();
  final Map<String, String> _sessionErrors = <String, String>{};
  final Map<String, Completer<void>> _pathBarriers =
      <String, Completer<void>>{};
  Future<bool>? _initializing;
  Future<void>? _closingSessions;
  bool _available = false;
  String _runtimeVersion = 'unknown';

  bool get isAvailable => _available;

  String get runtimeVersion => _runtimeVersion;

  List<ort.OrtProvider> get availableProviders =>
      List<ort.OrtProvider>.unmodifiable(_providers);

  bool hasReadySessions(Iterable<String> modelPaths) {
    final Set<String> paths = modelPaths.toSet();
    return paths.isNotEmpty &&
        paths.every(
          (String path) => _sessions.values.any(
            (_SessionEntry entry) =>
                entry.modelPath == path && !entry.closeRequested,
          ),
        );
  }

  String? sessionErrorFor(Iterable<String> modelPaths) {
    for (final String path in modelPaths) {
      final String? error = _sessionErrors[path];
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  Future<bool> initialize() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    try {
      final ort.OnnxRuntime engine = ort.OnnxRuntime();
      final List<ort.OrtProvider> providers =
          await engine.getAvailableProviders();
      try {
        final Map<String, dynamic> runtimeInfo = await engine.getRuntimeInfo();
        _runtimeVersion = runtimeInfo['ortVersion']?.toString() ?? 'unknown';
      } catch (e, s) {
        // Version reporting is diagnostic. Provider initialization remains
        // usable when an older plugin implementation lacks this method.
        _runtimeVersion = 'unknown';
        _log.warning('ONNX Runtime version probe failed: $e');
        _log.trace(s);
      }
      _engine = engine;
      _providers
        ..clear()
        ..addAll(providers);
      _available = providers.isNotEmpty;
      _log.info(
        'ONNX Runtime available, providers: ${providers.map((ort.OrtProvider provider) => provider.name).join(', ')}',
      );
    } catch (e, s) {
      _log.warning('ONNX Runtime initialization failed: $e');
      _log.trace(s);
      _engine = null;
      _providers.clear();
      _runtimeVersion = 'unknown';
      _available = false;
    }
    return _available;
  }

  Future<ort.OrtSession?> session(
    String modelPath, {
    required String modelFingerprint,
    required List<ort.OrtProvider> providers,
    InferenceSessionSafetyConfig? safetyConfig,
    int? intraOpNumThreads,
    int? interOpNumThreads,
  }) async {
    final Future<void>? closing = _closingSessions;
    if (closing != null) {
      await closing;
    }
    Completer<void>? barrier = _pathBarriers[modelPath];
    while (barrier != null) {
      await barrier.future;
      barrier = _pathBarriers[modelPath];
    }
    if (!await initialize()) {
      return null;
    }
    final List<ort.OrtProvider> effectiveProviders = providers
        .where(_providers.contains)
        .toSet()
        .toList(growable: false);
    if (effectiveProviders.isEmpty) {
      _log.warning('No requested ONNX provider is available: $providers');
      return null;
    }
    final String cacheKey = _cacheKey(
      modelPath,
      modelFingerprint,
      effectiveProviders,
      safetyConfig: safetyConfig,
      intraOpNumThreads: intraOpNumThreads,
      interOpNumThreads: interOpNumThreads,
    );
    final _SessionEntry? cached = _sessions[cacheKey];
    if (cached != null) {
      return cached.session;
    }
    final Future<ort.OrtSession?>? creating = _creatingSessions[cacheKey];
    if (creating != null) {
      return creating;
    }
    final Future<ort.OrtSession?> task = _sessionCreationQueue.run(
      () => _createSession(
        cacheKey: cacheKey,
        modelPath: modelPath,
        providers: effectiveProviders,
        safetyConfig: safetyConfig,
        intraOpNumThreads: intraOpNumThreads,
        interOpNumThreads: interOpNumThreads,
      ),
    );
    _creatingSessions[cacheKey] = task;
    try {
      return await task;
    } finally {
      _creatingSessions.remove(cacheKey);
    }
  }

  Future<ort.OrtSession?> _createSession({
    required String cacheKey,
    required String modelPath,
    required List<ort.OrtProvider> providers,
    InferenceSessionSafetyConfig? safetyConfig,
    int? intraOpNumThreads,
    int? interOpNumThreads,
  }) async {
    try {
      final ort.OrtSessionOptions options = ort.OrtSessionOptions(
        providers: providers,
        intraOpNumThreads: intraOpNumThreads,
        interOpNumThreads: interOpNumThreads,
        useArena: safetyConfig?.useArena ?? true,
        providerOptions: safetyConfig?.providerOptions,
        sessionConfigEntries: safetyConfig?.sessionConfigEntries,
        mlComputeUnits: safetyConfig?.mlComputeUnits,
        requireStaticShapes: safetyConfig?.requireStaticShapes,
        inputShape: safetyConfig?.inputShape,
        memoryBudgetBytes: safetyConfig?.memoryBudgetBytes,
      );
      final ort.OrtSession created = await _engine!.createSession(
        modelPath,
        options: options,
      );
      _sessions[cacheKey] = _SessionEntry(
        modelPath: modelPath,
        providers: providers,
        session: created,
        memoryBudgetBytes: safetyConfig?.memoryBudgetBytes,
        maxInputPixels: safetyConfig?.maxInputPixels,
      );
      _sessionErrors.remove(modelPath);
      _allSessions.add(_sessions[cacheKey]!);
      _log.info(
        'ONNX session ready: $modelPath (${providers.map((ort.OrtProvider provider) => provider.name).join(' -> ')})',
      );
      return created;
    } catch (e, s) {
      _sessionErrors[modelPath] = e.toString();
      _log.warning('create ONNX session failed: $modelPath: $e');
      _log.trace(s);
      return null;
    }
  }

  /// Runs one native inference while holding a lifecycle lease on [session].
  /// Model replacement and backend changes wait for leased runs before closing
  /// native resources, so a settings tap cannot close a session mid-call.
  Future<Map<String, ort.OrtValue>> run(
    ort.OrtSession session,
    Map<String, ort.OrtValue> inputs,
  ) async {
    _SessionEntry? entry;
    for (final _SessionEntry candidate in _allSessions) {
      if (identical(candidate.session, session)) {
        entry = candidate;
        break;
      }
    }
    if (entry == null || entry.closeRequested) {
      throw StateError('ONNX session is no longer active');
    }
    final int estimatedInputBytes = inputs.values.fold<int>(
      0,
      (int total, ort.OrtValue value) => total + _estimatedTensorBytes(value),
    );
    final int? memoryBudgetBytes = entry.memoryBudgetBytes;
    if (memoryBudgetBytes != null &&
        estimatedInputBytes > memoryBudgetBytes ~/ 2) {
      throw StateError(
        'ONNX input tensors exceed the configured memory budget: '
        '$estimatedInputBytes bytes',
      );
    }
    final int? maxInputPixels = entry.maxInputPixels;
    if (maxInputPixels != null &&
        inputs.values.any(
          (ort.OrtValue value) => _exceedsPixelBudget(value, maxInputPixels),
        )) {
      throw StateError('ONNX input tensor exceeds the configured pixel budget');
    }
    entry.activeRuns++;
    try {
      return await session.run(inputs);
    } finally {
      entry.activeRuns--;
      if (entry.activeRuns == 0 && entry.closeRequested) {
        unawaited(_closeEntry(entry));
      }
    }
  }

  String _cacheKey(
    String modelPath,
    String fingerprint,
    List<ort.OrtProvider> providers, {
    InferenceSessionSafetyConfig? safetyConfig,
    int? intraOpNumThreads,
    int? interOpNumThreads,
  }) =>
      '$modelPath|$fingerprint|${providers.map((ort.OrtProvider provider) => provider.name).join(',')}|${intraOpNumThreads ?? 0}|${interOpNumThreads ?? 0}|${safetyConfig?.stableId ?? 'default'}';

  int _estimatedTensorBytes(ort.OrtValue value) {
    final int elements = value.shape.fold<int>(
      1,
      (int product, int dimension) => dimension <= 0 ? 0 : product * dimension,
    );
    final int bytesPerElement = switch (value.dataType) {
      ort.OrtDataType.float32 ||
      ort.OrtDataType.int32 ||
      ort.OrtDataType.uint32 ||
      ort.OrtDataType.int16 ||
      ort.OrtDataType.uint16 => 4,
      ort.OrtDataType.float16 ||
      ort.OrtDataType.int8 ||
      ort.OrtDataType.uint8 ||
      ort.OrtDataType.bool => 2,
      ort.OrtDataType.int64 || ort.OrtDataType.uint64 => 8,
      _ => 8,
    };
    return elements * bytesPerElement;
  }

  bool _exceedsPixelBudget(ort.OrtValue value, int maxPixels) {
    if (value.shape.length < 2) {
      return false;
    }
    final int height = value.shape[value.shape.length - 2];
    final int width = value.shape.last;
    return height > 0 && width > 0 && height * width > maxPixels;
  }

  /// Prevents new sessions for [modelPaths], waits for active native calls,
  /// then performs [operation] while those paths remain exclusively locked.
  Future<T> withPathsInvalidated<T>(
    Iterable<String> modelPaths,
    Future<T> Function() operation,
  ) async {
    final Set<String> paths = modelPaths.toSet();
    for (final String path in paths) {
      final Completer<void>? active = _pathBarriers[path];
      if (active != null) {
        await active.future;
      }
    }
    final Completer<void> barrier = Completer<void>();
    for (final String path in paths) {
      _pathBarriers[path] = barrier;
    }
    try {
      await _invalidatePaths(paths);
      return await operation();
    } finally {
      for (final String path in paths) {
        if (identical(_pathBarriers[path], barrier)) {
          _pathBarriers.remove(path);
        }
      }
      if (!barrier.isCompleted) {
        barrier.complete();
      }
    }
  }

  Future<void> _invalidatePaths(Set<String> paths) async {
    for (final String path in paths) {
      _sessionErrors.remove(path);
    }
    final List<Future<ort.OrtSession?>> creating = _creatingSessions.entries
        .where(
          (MapEntry<String, Future<ort.OrtSession?>> entry) =>
              paths.any((String path) => entry.key.startsWith('$path|')),
        )
        .map((MapEntry<String, Future<ort.OrtSession?>> entry) => entry.value)
        .toList(growable: false);
    if (creating.isNotEmpty) {
      await Future.wait(creating);
    }
    final List<String> keys = _sessions.entries
        .where(
          (MapEntry<String, _SessionEntry> entry) =>
              paths.contains(entry.value.modelPath),
        )
        .map((MapEntry<String, _SessionEntry> entry) => entry.key)
        .toList(growable: false);
    final List<_SessionEntry> entries = keys
        .map(_sessions.remove)
        .whereType<_SessionEntry>()
        .toSet()
        .toList(growable: false);
    await Future.wait(entries.map(_requestClose));
  }

  Future<void> closeSessions() {
    final Future<void>? active = _closingSessions;
    if (active != null) {
      return active;
    }
    late final Future<void> task;
    task = _closeSessions().whenComplete(() {
      if (identical(_closingSessions, task)) {
        _closingSessions = null;
      }
    });
    _closingSessions = task;
    return task;
  }

  Future<void> _closeSessions() async {
    if (_creatingSessions.isNotEmpty) {
      await Future.wait(_creatingSessions.values.toList());
    }
    final List<_SessionEntry> entries = _allSessions.toList(growable: false);
    _sessions.clear();
    _sessionErrors.clear();
    await Future.wait(entries.map(_requestClose));
  }

  Future<void> _requestClose(_SessionEntry entry) {
    entry.closeRequested = true;
    entry.closeCompleter ??= Completer<void>();
    if (entry.activeRuns == 0) {
      unawaited(_closeEntry(entry));
    }
    return entry.closeCompleter!.future;
  }

  Future<void> _closeEntry(_SessionEntry entry) async {
    if (entry.closing) {
      return entry.closeCompleter?.future;
    }
    entry.closing = true;
    try {
      await entry.session.close();
    } catch (e) {
      _log.trace('close ONNX session failed: $e');
    } finally {
      _allSessions.remove(entry);
      if (!(entry.closeCompleter?.isCompleted ?? true)) {
        entry.closeCompleter!.complete();
      }
    }
  }

  Future<void> dispose() async {
    await closeSessions();
    _engine = null;
    _providers.clear();
    for (final Completer<void> barrier in _pathBarriers.values.toSet()) {
      if (!barrier.isCompleted) {
        barrier.complete();
      }
    }
    _pathBarriers.clear();
    _initializing = null;
    _runtimeVersion = 'unknown';
    _available = false;
  }
}

class _SessionEntry {
  _SessionEntry({
    required this.modelPath,
    required this.providers,
    required this.session,
    this.memoryBudgetBytes,
    this.maxInputPixels,
  });

  final String modelPath;
  final List<ort.OrtProvider> providers;
  final ort.OrtSession session;
  final int? memoryBudgetBytes;
  final int? maxInputPixels;
  int activeRuns = 0;
  bool closeRequested = false;
  bool closing = false;
  Completer<void>? closeCompleter;
}
