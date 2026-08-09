import 'dart:async';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:jhentai/src/service/log.dart';

/// Process-wide ONNX Runtime owner.
///
/// Initialization and session creation are single-flight. Sessions are keyed
/// by model fingerprint and execution-provider order, so changing backend or
/// replacing a model never reuses a stale native session.
class OnnxRuntime {
  OnnxRuntime._();

  static final OnnxRuntime instance = OnnxRuntime._();

  ort.OnnxRuntime? _engine;
  final List<ort.OrtProvider> _providers = <ort.OrtProvider>[];
  final Map<String, _SessionEntry> _sessions = <String, _SessionEntry>{};
  final Set<_SessionEntry> _allSessions = <_SessionEntry>{};
  final Map<String, Future<ort.OrtSession?>> _creatingSessions =
      <String, Future<ort.OrtSession?>>{};
  final Map<String, String> _sessionErrors = <String, String>{};
  final Map<String, Completer<void>> _pathBarriers =
      <String, Completer<void>>{};
  Future<bool>? _initializing;
  Future<void>? _closingSessions;
  bool _available = false;

  bool get isAvailable => _available;

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
      _engine = engine;
      _providers
        ..clear()
        ..addAll(providers);
      _available = providers.isNotEmpty;
      log.info(
        'ONNX Runtime available, providers: ${providers.map((ort.OrtProvider provider) => provider.name).join(', ')}',
      );
    } catch (e, s) {
      log.warning('ONNX Runtime initialization failed: $e');
      log.trace(s);
      _engine = null;
      _providers.clear();
      _available = false;
    }
    return _available;
  }

  Future<ort.OrtSession?> session(
    String modelPath, {
    required String modelFingerprint,
    required List<ort.OrtProvider> providers,
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
      log.warning('No requested ONNX provider is available: $providers');
      return null;
    }
    final String cacheKey = _cacheKey(
      modelPath,
      modelFingerprint,
      effectiveProviders,
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
    final Future<ort.OrtSession?> task = _createSession(
      cacheKey: cacheKey,
      modelPath: modelPath,
      providers: effectiveProviders,
      intraOpNumThreads: intraOpNumThreads,
      interOpNumThreads: interOpNumThreads,
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
    int? intraOpNumThreads,
    int? interOpNumThreads,
  }) async {
    try {
      final ort.OrtSessionOptions options = ort.OrtSessionOptions(
        providers: providers,
        intraOpNumThreads: intraOpNumThreads,
        interOpNumThreads: interOpNumThreads,
        useArena: true,
      );
      final ort.OrtSession created = await _engine!.createSession(
        modelPath,
        options: options,
      );
      _sessions[cacheKey] = _SessionEntry(
        modelPath: modelPath,
        providers: providers,
        session: created,
      );
      _sessionErrors.remove(modelPath);
      _allSessions.add(_sessions[cacheKey]!);
      log.info(
        'ONNX session ready: $modelPath (${providers.map((ort.OrtProvider provider) => provider.name).join(' -> ')})',
      );
      return created;
    } catch (e, s) {
      _sessionErrors[modelPath] = e.toString();
      log.warning('create ONNX session failed: $modelPath: $e');
      log.trace(s);
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
    int? intraOpNumThreads,
    int? interOpNumThreads,
  }) =>
      '$modelPath|$fingerprint|${providers.map((ort.OrtProvider provider) => provider.name).join(',')}|${intraOpNumThreads ?? 0}|${interOpNumThreads ?? 0}';

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
      log.trace('close ONNX session failed: $e');
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
    _available = false;
  }
}

class _SessionEntry {
  _SessionEntry({
    required this.modelPath,
    required this.providers,
    required this.session,
  });

  final String modelPath;
  final List<ort.OrtProvider> providers;
  final ort.OrtSession session;
  int activeRuns = 0;
  bool closeRequested = false;
  bool closing = false;
  Completer<void>? closeCompleter;
}
