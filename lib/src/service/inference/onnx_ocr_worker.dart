import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:jhentai/src/service/inference/inference_exception.dart';
import 'package:jhentai/src/service/inference/inference_safety.dart';
import 'package:jhentai/src/service/inference/inference_task.dart';
import 'package:jhentai/src/service/inference/ocr_inference_engine.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference/onnx_ocr_engine.dart';
import 'package:jhentai/src/service/inference/onnx_runtime.dart';

/// Runs the entire ONNX OCR pipeline on a dedicated background isolate.
///
/// The pipeline (image decode, resize, normalization, connected-component
/// labeling, per-line classification/recognition, and the ONNX native calls)
/// is heavy CPU + tensor marshaling work. Executing it on the UI isolate froze
/// frames for seconds per page on macOS and, combined with the transient
/// memory spikes of the detection tensor, could terminate the app on iOS.
///
/// The worker owns its own [OnnxRuntime] instance and session cache; the UI
/// isolate talks to it over ports and never blocks. Sessions live in the
/// worker, so backend changes and disposal are forwarded as control messages.
///
/// flutter_onnxruntime is a MethodChannel plugin, and platform channels are not
/// reachable from an `Isolate.spawn`'d isolate by default. The UI isolate
/// forwards its [ui.RootIsolateToken] at spawn so the worker can install a
/// [BackgroundIsolateBinaryMessenger], which routes channel calls back through
/// the root isolate. The full Flutter binding must NOT be initialized off the
/// root isolate ("UI actions are only available on root isolate").
class OnnxOcrWorker {
  OnnxOcrWorker._(this._workerPort);

  final SendPort _workerPort;
  int _nextCallId = 1;
  bool _closed = false;
  final Set<Completer<OcrInferenceResult>> _inflight =
      <Completer<OcrInferenceResult>>{};

  /// Spawns the worker isolate and waits for its handshake.
  static Future<OnnxOcrWorker> spawn() async {
    final ui.RootIsolateToken? token = ServicesBinding.rootIsolateToken;
    if (token == null) {
      throw StateError('ONNX OCR worker requires a root isolate token');
    }
    final ReceivePort handshakePort = ReceivePort();
    final Completer<OnnxOcrWorker> completer = Completer<OnnxOcrWorker>();
    handshakePort.listen((dynamic message) {
      if (message is Map &&
          message['op'] == 'ready' &&
          message['port'] is SendPort &&
          !completer.isCompleted) {
        completer.complete(OnnxOcrWorker._(message['port'] as SendPort));
      }
    });
    unawaited(
      Isolate.spawn(onnxOcrWorkerMain, (token, handshakePort.sendPort)),
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw StateError('ONNX OCR worker failed to start'),
      );
    } finally {
      handshakePort.close();
    }
  }

  /// Runs OCR on [imagePath] in the worker. Cancellation is cooperative: the
  /// UI isolate polls [cancellationToken] and forwards a cancel message, which
  /// the worker honours between pipeline stages.
  Future<OcrInferenceResult> recognize({
    required OnnxOcrModelInfo model,
    required List<ort.OrtProvider> providers,
    required String imagePath,
    int maxDimension = 2200,
    required InferenceCancellationToken cancellationToken,
    InferenceProgressCallback? onProgress,
    required InferenceSessionSafetyConfig safetyConfig,
  }) async {
    if (_closed) {
      throw StateError('ONNX OCR worker is closed');
    }
    final int callId = _nextCallId++;
    final ReceivePort callPort = ReceivePort();
    final Completer<OcrInferenceResult> completer =
        Completer<OcrInferenceResult>();
    // The poll timer and the listener are both set up synchronously below, so
    // by the time a message or timer tick fires they are already assigned.
    late final Timer pollTimer;
    late final StreamSubscription<dynamic> subscription;
    subscription = callPort.listen((dynamic message) {
      if (message is! Map) {
        return;
      }
      final dynamic progress = message['progress'];
      if (progress is double) {
        onProgress?.call(progress);
        return;
      }
      if (message['done'] == true) {
        if (message['ok'] == true) {
          completer.complete(message['result'] as OcrInferenceResult);
        } else {
          completer.completeError(
            _mapWorkerError(
              message['code'] as String?,
              message['detail'] as String?,
            ),
          );
        }
        subscription.cancel();
        callPort.close();
        pollTimer.cancel();
      }
    });
    _workerPort.send(<String, dynamic>{
      'op': 'recognize',
      'id': callId,
      'model': <String, String>{
        'det': model.detPath,
        'cls': model.clsPath,
        'rec': model.recPath,
        'dict': model.dictPath,
        'fingerprint': model.fingerprint,
      },
      'providers':
          providers.map((ort.OrtProvider provider) => provider.name).toList(),
      'imagePath': imagePath,
      'maxDimension': maxDimension,
      'safetyConfig': safetyConfig.toMap(),
      'reply': callPort.sendPort,
    });
    // A pipeline stage can run for a while without emitting progress, so poll
    // the UI-isolate token and push cancellation through promptly.
    pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (cancellationToken.isCancelled) {
        _workerPort.send(<String, dynamic>{'op': 'cancel', 'id': callId});
      }
    });
    _inflight.add(completer);
    try {
      // Guard against a dead worker isolate: sending to a terminated isolate
      // is silently dropped, so without a timeout the call would hang forever.
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          // Tell the worker to abort so it does not keep burning CPU/memory
          // (and hold decoded-image + tensor allocations) with no consumer.
          _workerPort.send(<String, dynamic>{'op': 'cancel', 'id': callId});
          throw StateError('ONNX OCR worker timed out');
        },
      );
    } finally {
      _inflight.remove(completer);
      pollTimer.cancel();
      subscription.cancel();
      callPort.close();
    }
  }

  /// Closes all cached native sessions in the worker (used on backend change
  /// and model replacement). In-flight OCR aborts cooperatively.
  Future<void> closeSessions() async {
    if (_closed) {
      return;
    }
    await _sendControl('closeSessions');
  }

  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    // Fail any in-flight recognize so its caller does not hang until the
    // 5-minute timeout; the worker abandons the remaining pipeline when it
    // exits below.
    final Object disposeError = StateError('ONNX OCR worker disposed');
    for (final Completer<OcrInferenceResult> completer in _inflight.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(disposeError);
      }
    }
    _inflight.clear();
    await _sendControl('dispose');
  }

  Future<Map<dynamic, dynamic>?> _sendControl(String op) async {
    final ReceivePort reply = ReceivePort();
    final Completer<Map<dynamic, dynamic>> completer =
        Completer<Map<dynamic, dynamic>>();
    reply.listen((dynamic message) {
      if (message is Map && !completer.isCompleted) {
        completer.complete(message);
        reply.close();
      }
    });
    _workerPort.send(<String, dynamic>{'op': op, 'reply': reply.sendPort});
    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      reply.close();
      return null;
    }
  }

  /// Re-initializes the worker's ONNX runtime so a transient startup failure is
  /// retried (the single-flight [OnnxRuntime.initialize] caches the outcome).
  /// Returns true when the runtime is available afterwards.
  Future<bool> reinitialize() async {
    if (_closed) {
      return false;
    }
    final Map<dynamic, dynamic>? reply = await _sendControl('reinitialize');
    return reply?['ok'] == true;
  }

  static Object _mapWorkerError(String? code, String? detail) {
    switch (code) {
      case 'cancelled':
        return const InferenceCancelledException('cancelled');
      case 'not_ready':
        return const InferenceNotReadyException('onnx-ocr');
      default:
        return StateError(detail ?? 'ONNX OCR failed');
    }
  }
}

/// UI-isolate [OcrInferenceEngine] that forwards work to [OnnxOcrWorker].
class OnnxOcrIsolateEngine implements OcrInferenceEngine {
  OnnxOcrIsolateEngine({
    required this.providerResolver,
    required this.modelIdResolver,
    this.onSessionStateChanged,
    this.safetyConfigResolver,
    this.onCanaryStarted,
    this.onCanarySucceeded,
    this.onCanaryFailed,
  });

  final OnnxProviderResolver providerResolver;

  /// Returns the active ONNX OCR manifest id (from
  /// [ImageTranslationSetting.onnxModelId]) so the engine follows the model the
  /// user selected instead of hardcoding one manifest.
  final String Function() modelIdResolver;

  /// Reports whether the worker managed to create usable sessions, so the
  /// inference settings page can show a real session state even though native
  /// sessions now live inside the worker isolate.
  final void Function({required bool verified, String? error})?
  onSessionStateChanged;
  final InferenceSessionSafetyConfig Function(String modelHash)?
  safetyConfigResolver;
  final InferenceCanaryLifecycle? onCanaryStarted;
  final InferenceCanaryLifecycle? onCanarySucceeded;
  final InferenceCanaryFailureLifecycle? onCanaryFailed;

  OnnxOcrWorker? _worker;
  Future<OnnxOcrWorker>? _spawnFuture;
  final InferenceTaskQueue _inferenceQueue = InferenceTaskQueue();

  String get _activeManifestId => modelIdResolver();

  @override
  String get displayName {
    final OnnxModelManifest? manifest = OnnxModelStore.instance.manifestOf(
      _activeManifestId,
    );
    return manifest?.displayName ?? 'ONNX OCR';
  }

  @override
  bool get isReady =>
      OnnxRuntime.instance.isAvailable &&
      providerResolver().isNotEmpty &&
      OnnxModelStore.instance.isManifestDownloaded(_activeManifestId);

  @override
  Future<OcrInferenceResult> recognize(
    String imagePath, {
    int maxDimension = 2200,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) => _inferenceQueue.run(
    () => _recognize(
      imagePath,
      maxDimension: maxDimension,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    ),
  );

  Future<OcrInferenceResult> _recognize(
    String imagePath, {
    int maxDimension = 2200,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) async {
    final InferenceCancellationToken token =
        cancellationToken ?? InferenceCancellationToken();
    // Resolve the model paths once: manifestFilePaths() already performs the
    // (synchronous, on-disk) download validation, so calling isReady here too
    // would validate the model twice per page for no benefit.
    final Map<String, String>? files = OnnxModelStore.instance
        .manifestFilePaths(_activeManifestId);
    final String? fingerprint = OnnxModelStore.instance.fingerprintOf(
      _activeManifestId,
    );
    final List<ort.OrtProvider> providers = providerResolver();
    if (!OnnxRuntime.instance.isAvailable ||
        files == null ||
        fingerprint == null ||
        providers.isEmpty) {
      throw const InferenceNotReadyException('onnx-ocr');
    }
    final InferenceSessionSafetyConfig safetyConfig =
        safetyConfigResolver?.call(fingerprint) ??
        InferenceProviderPolicy.sessionConfig(
          backend: 'cpu',
          maxInputPixels: 4 * 1024 * 1024,
          memoryBudgetBytes: 128 * 1024 * 1024,
        );
    final bool accelerated =
        providers.isNotEmpty && providers.first != ort.OrtProvider.CPU;
    if (accelerated) {
      await onCanaryStarted?.call(fingerprint, providers);
    }
    try {
      final OnnxOcrWorker worker = await _ensureWorker();
      final OcrInferenceResult result = await worker.recognize(
        model: OnnxOcrModelInfo(
          detPath: files['det']!,
          clsPath: files['cls']!,
          recPath: files['rec']!,
          dictPath: files['dict']!,
          fingerprint: fingerprint,
        ),
        providers: providers,
        imagePath: imagePath,
        maxDimension: maxDimension,
        cancellationToken: token,
        onProgress: onProgress,
        safetyConfig: safetyConfig,
      );
      if (accelerated) {
        await onCanarySucceeded?.call(fingerprint, providers);
      }
      onSessionStateChanged?.call(verified: true);
      return result;
    } on InferenceNotReadyException catch (e) {
      // The worker failed to build a native session (e.g. provider rejected
      // the model). Surface it so the settings page flips to "failed".
      onSessionStateChanged?.call(verified: false, error: e.toString());
      rethrow;
    } catch (e) {
      if (accelerated && e is! InferenceCancelledException) {
        await onCanaryFailed?.call(fingerprint, providers, e);
      }
      onSessionStateChanged?.call(verified: false, error: e.toString());
      rethrow;
    }
  }

  Future<OnnxOcrWorker> _ensureWorker() {
    final OnnxOcrWorker? existing = _worker;
    if (existing != null) {
      return Future.value(existing);
    }
    final Future<OnnxOcrWorker>? pending = _spawnFuture;
    if (pending != null) {
      return pending;
    }
    final Future<OnnxOcrWorker> task = OnnxOcrWorker.spawn().then((
      OnnxOcrWorker worker,
    ) {
      _worker = worker;
      return worker;
    });
    _spawnFuture = task;
    return task.whenComplete(() {
      if (identical(_spawnFuture, task)) {
        _spawnFuture = null;
      }
    });
  }

  /// Closes cached sessions in the worker (backend change / model replace).
  Future<void> closeSessions() async {
    final OnnxOcrWorker? worker = _worker;
    if (worker != null) {
      await worker.closeSessions();
    }
  }

  /// Re-initializes the worker's ONNX runtime. Returns true on success, false
  /// if the worker is spawned but re-initialization failed, or null if the
  /// worker was never spawned (nothing to re-initialize).
  Future<bool?> reinitialize() async {
    final OnnxOcrWorker? worker = _worker;
    if (worker == null) {
      return null;
    }
    return worker.reinitialize();
  }

  Future<void> dispose() async {
    try {
      await _spawnFuture;
    } catch (_) {
      // Spawn failed; nothing to dispose.
    }
    final OnnxOcrWorker? worker = _worker;
    _worker = null;
    _spawnFuture = null;
    if (worker != null) {
      await worker.dispose();
    }
  }
}

/// Isolate entry point. Awaits control messages; each recognize request is
/// handled asynchronously so cancel / close can interleave with a long run.
Future<void> onnxOcrWorkerMain((ui.RootIsolateToken, SendPort) args) async {
  final (ui.RootIsolateToken token, SendPort helloPort) = args;
  // flutter_onnxruntime's MethodChannel calls are forwarded to the root
  // isolate through the background binary messenger. The full Flutter binding
  // must NOT be initialized here: SchedulerBinding tries to arm a timings
  // callback and the engine rejects UI operations off the root isolate.
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final ReceivePort commandPort = ReceivePort();
  helloPort.send(<String, dynamic>{
    'op': 'ready',
    'port': commandPort.sendPort,
  });
  // The global `log` singleton depends on UI-isolate services (pathService),
  // so the worker uses a no-op diagnostics sink.
  final OnnxRuntime runtime = OnnxRuntime(log: noopOnnxRuntimeLog);
  await runtime.initialize();
  final Map<int, InferenceCancellationToken> tokens =
      <int, InferenceCancellationToken>{};
  await for (final dynamic message in commandPort) {
    if (message is! Map) {
      continue;
    }
    switch (message['op'] as String? ?? '') {
      case 'recognize':
        final int id = message['id'] as int;
        final SendPort reply = message['reply'] as SendPort;
        final InferenceCancellationToken token = InferenceCancellationToken();
        tokens[id] = token;
        unawaited(
          _handleRecognize(
            runtime,
            message,
            token,
            reply,
            () => tokens.remove(id),
          ),
        );
      case 'cancel':
        final Object? id = message['id'];
        if (id is int) {
          tokens[id]?.cancel('cancelled');
        }
      case 'closeSessions':
        // Handle off the message loop so a queued cancel/recognize is not
        // delayed while sessions drain; in-flight OCR aborts cooperatively.
        unawaited(_closeSessionsInWorker(runtime, message, tokens));
      case 'reinitialize':
        unawaited(_reinitializeInWorker(runtime, message));
      case 'dispose':
        await runtime.closeSessions();
        (message['reply'] as SendPort?)?.send(<String, dynamic>{'done': true});
        return;
    }
  }
}

Future<void> _reinitializeInWorker(
  OnnxRuntime runtime,
  Map<dynamic, dynamic> message,
) async {
  bool ok = false;
  try {
    await runtime.dispose();
    ok = await runtime.initialize();
  } catch (_) {
    ok = false;
  }
  (message['reply'] as SendPort?)?.send(<String, dynamic>{
    'done': true,
    'ok': ok,
  });
}

Future<void> _closeSessionsInWorker(
  OnnxRuntime runtime,
  Map<dynamic, dynamic> message,
  Map<int, InferenceCancellationToken> tokens,
) async {
  // Cancel in-flight OCR so the next pipeline stage throws InferenceCancelled
  // instead of hitting a session that is being torn down underneath it.
  for (final InferenceCancellationToken token in tokens.values) {
    token.cancel('session closed');
  }
  await runtime.closeSessions();
  (message['reply'] as SendPort?)?.send(<String, dynamic>{'done': true});
}

Future<void> _handleRecognize(
  OnnxRuntime runtime,
  Map<dynamic, dynamic> message,
  InferenceCancellationToken token,
  SendPort reply,
  void Function() onFinished,
) async {
  try {
    final List<String> providerNames =
        (message['providers'] as List)
            .map((dynamic name) => name as String)
            .toList();
    final List<ort.OrtProvider> providers =
        providerNames
            .map(
              (String name) => ort.OrtProvider.values.firstWhere(
                (ort.OrtProvider provider) => provider.name == name,
                orElse: () => ort.OrtProvider.CPU,
              ),
            )
            .toList();
    final Map<dynamic, dynamic> model = message['model'] as Map;
    final OnnxOcrInferenceEngine engine = OnnxOcrInferenceEngine(
      runtime: runtime,
      providerResolver: () => providers,
      safetyConfig: InferenceSessionSafetyConfig.fromMap(
        (message['safetyConfig'] as Map?) ?? const <String, dynamic>{},
      ),
      model: OnnxOcrModelInfo(
        detPath: model['det'] as String,
        clsPath: model['cls'] as String,
        recPath: model['rec'] as String,
        dictPath: model['dict'] as String,
        fingerprint: model['fingerprint'] as String,
      ),
    );
    final OcrInferenceResult result = await engine.recognize(
      message['imagePath'] as String,
      maxDimension: message['maxDimension'] as int? ?? 2200,
      cancellationToken: token,
      onProgress:
          (double progress) =>
              reply.send(<String, dynamic>{'progress': progress}),
    );
    reply.send(<String, dynamic>{'done': true, 'ok': true, 'result': result});
  } on InferenceCancelledException {
    reply.send(<String, dynamic>{
      'done': true,
      'ok': false,
      'code': 'cancelled',
      'detail': 'cancelled',
    });
  } on InferenceNotReadyException catch (e) {
    reply.send(<String, dynamic>{
      'done': true,
      'ok': false,
      'code': 'not_ready',
      'detail': e.toString(),
    });
  } catch (e) {
    reply.send(<String, dynamic>{
      'done': true,
      'ok': false,
      'code': 'state',
      'detail': e.toString(),
    });
  } finally {
    onFinished();
  }
}
