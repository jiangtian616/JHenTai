import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:jhentai/src/service/inference/inference_exception.dart';
import 'package:jhentai/src/service/inference/inference_task.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference/onnx_ocr_engine.dart'
    show OnnxProviderResolver;
import 'package:jhentai/src/service/inference/onnx_runtime.dart';
import 'package:jhentai/src/service/inference/onnx_super_resolution_engine.dart';
import 'package:jhentai/src/service/inference/super_resolution_inference_engine.dart';

/// Runs the entire ONNX super-resolution pipeline (decode, tiled Real-ESRGAN
/// inference, PNG encoding) on a dedicated background isolate.
///
/// Like [OnnxOcrWorker], this keeps the heavy CPU + tensor work off the UI
/// isolate (which froze frames on macOS and could crash iOS), and forwards
/// flutter_onnxruntime's MethodChannel calls back through the root isolate via
/// [BackgroundIsolateBinaryMessenger].
class OnnxSuperResolutionWorker {
  OnnxSuperResolutionWorker._(this._workerPort);

  final SendPort _workerPort;
  int _nextCallId = 1;
  bool _closed = false;
  final Set<Completer<void>> _inflight = <Completer<void>>{};

  /// Spawns the worker isolate and waits for its handshake.
  static Future<OnnxSuperResolutionWorker> spawn() async {
    final ui.RootIsolateToken? token = ServicesBinding.rootIsolateToken;
    if (token == null) {
      throw StateError('ONNX super-resolution worker requires a root isolate token');
    }
    final ReceivePort handshakePort = ReceivePort();
    final Completer<OnnxSuperResolutionWorker> completer =
        Completer<OnnxSuperResolutionWorker>();
    handshakePort.listen((dynamic message) {
      if (message is Map &&
          message['op'] == 'ready' &&
          message['port'] is SendPort &&
          !completer.isCompleted) {
        completer.complete(
          OnnxSuperResolutionWorker._(message['port'] as SendPort),
        );
      }
    });
    unawaited(
      Isolate.spawn(onnxSuperResolutionWorkerMain, (token, handshakePort.sendPort)),
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw StateError('ONNX super-resolution worker failed to start'),
      );
    } finally {
      handshakePort.close();
    }
  }

  /// Upscales [inputPath] to [outputPath] in the worker. Cancellation is
  /// cooperative: the UI isolate polls [cancellationToken] and forwards a
  /// cancel message, which the worker honours between tiles/stages.
  Future<void> upscale({
    required OnnxSuperResolutionModelInfo model,
    required List<ort.OrtProvider> providers,
    required String inputPath,
    required String outputPath,
    required int scale,
    required InferenceCancellationToken cancellationToken,
    InferenceProgressCallback? onProgress,
  }) async {
    if (_closed) {
      throw StateError('ONNX super-resolution worker is closed');
    }
    final int callId = _nextCallId++;
    final ReceivePort callPort = ReceivePort();
    final Completer<void> completer = Completer<void>();
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
          completer.complete();
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
      'op': 'upscale',
      'id': callId,
      'model': <String, String>{
        'modelPath': model.modelPath,
        'fingerprint': model.fingerprint,
      },
      'providers': providers
          .map((ort.OrtProvider provider) => provider.name)
          .toList(),
      'inputPath': inputPath,
      'outputPath': outputPath,
      'scale': scale,
      'reply': callPort.sendPort,
    });
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
        const Duration(minutes: 20),
        onTimeout: () {
          _workerPort.send(<String, dynamic>{'op': 'cancel', 'id': callId});
          throw StateError('ONNX super-resolution worker timed out');
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
  /// and model replacement). In-flight upscale aborts cooperatively.
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
    final Object disposeError = StateError('ONNX super-resolution worker disposed');
    for (final Completer<void> completer in _inflight.toList()) {
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
        return const InferenceNotReadyException('onnx-super-resolution');
      default:
        return StateError(detail ?? 'ONNX super-resolution failed');
    }
  }
}

/// UI-isolate [SuperResolutionInferenceEngine] that forwards work to
/// [OnnxSuperResolutionWorker].
class OnnxSuperResolutionIsolateEngine
    implements SuperResolutionInferenceEngine {
  OnnxSuperResolutionIsolateEngine({
    required this.providerResolver,
    required this.modelIdResolver,
    this.onSessionStateChanged,
  });

  final OnnxProviderResolver providerResolver;

  /// Returns the active ONNX super-resolution manifest id (from
  /// [SuperResolutionSetting.onnxModelId]) so the engine follows the model the
  /// user selected instead of hardcoding one manifest.
  final String Function() modelIdResolver;

  /// Reports whether the worker managed to create usable sessions, so the
  /// inference settings page can show a real session state even though native
  /// sessions now live inside the worker isolate.
  final void Function({required bool verified, String? error})?
  onSessionStateChanged;

  OnnxSuperResolutionWorker? _worker;
  Future<OnnxSuperResolutionWorker>? _spawnFuture;

  String get _activeManifestId => modelIdResolver();

  @override
  String get displayName {
    final OnnxModelManifest? manifest = OnnxModelStore.instance
        .manifestOf(_activeManifestId);
    return manifest?.displayName ?? 'ONNX Super Resolution';
  }

  @override
  bool get isReady =>
      OnnxRuntime.instance.isAvailable &&
      providerResolver().isNotEmpty &&
      OnnxModelStore.instance.isManifestDownloaded(_activeManifestId);

  @override
  Future<void> upscale({
    required String inputPath,
    required String outputPath,
    required int scale,
    InferenceCancellationToken? cancellationToken,
    InferenceProgressCallback? onProgress,
  }) async {
    final InferenceCancellationToken token =
        cancellationToken ?? InferenceCancellationToken();
    if (!isReady) {
      throw const InferenceNotReadyException('onnx-super-resolution');
    }
    final String? modelPath = OnnxModelStore.instance.filePath(
      _activeManifestId,
      'model',
    );
    final String? fingerprint = OnnxModelStore.instance.fingerprintOf(
      _activeManifestId,
    );
    if (modelPath == null || fingerprint == null) {
      throw const InferenceNotReadyException('onnx-super-resolution');
    }
    final List<ort.OrtProvider> providers = providerResolver();
    if (providers.isEmpty) {
      throw const InferenceNotReadyException('onnx-super-resolution');
    }
    final OnnxSuperResolutionWorker worker = await _ensureWorker();
    try {
      await worker.upscale(
        model: OnnxSuperResolutionModelInfo(
          modelPath: modelPath,
          fingerprint: fingerprint,
        ),
        providers: providers,
        inputPath: inputPath,
        outputPath: outputPath,
        scale: scale,
        cancellationToken: token,
        onProgress: onProgress,
      );
      onSessionStateChanged?.call(verified: true);
    } on InferenceCancelledException {
      // The UI token was NOT cancelled: the abort came from inside the worker
      // (e.g. a backend/model change closed its sessions). Surface it as an
      // error so the SR task reports feedback instead of being mistaken for a
      // silent user pause.
      if (!token.isCancelled) {
        throw StateError('ONNX super-resolution session was closed');
      }
      rethrow;
    } on InferenceNotReadyException catch (e) {
      // The worker failed to build a native session. Surface it so the
      // settings page flips to "failed".
      onSessionStateChanged?.call(verified: false, error: e.toString());
      rethrow;
    }
  }

  Future<OnnxSuperResolutionWorker> _ensureWorker() {
    final OnnxSuperResolutionWorker? existing = _worker;
    if (existing != null) {
      return Future.value(existing);
    }
    final Future<OnnxSuperResolutionWorker>? pending = _spawnFuture;
    if (pending != null) {
      return pending;
    }
    final Future<OnnxSuperResolutionWorker> task =
        OnnxSuperResolutionWorker.spawn().then((worker) {
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
    final OnnxSuperResolutionWorker? worker = _worker;
    if (worker != null) {
      await worker.closeSessions();
    }
  }

  /// Re-initializes the worker's ONNX runtime. Returns true on success, false
  /// if the worker is spawned but re-initialization failed, or null if the
  /// worker was never spawned (nothing to re-initialize).
  Future<bool?> reinitialize() async {
    final OnnxSuperResolutionWorker? worker = _worker;
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
    final OnnxSuperResolutionWorker? worker = _worker;
    _worker = null;
    _spawnFuture = null;
    if (worker != null) {
      await worker.dispose();
    }
  }
}

/// Isolate entry point. Awaits control messages; each upscale request is
/// handled asynchronously so cancel / close can interleave with a long run.
Future<void> onnxSuperResolutionWorkerMain(
  (ui.RootIsolateToken, SendPort) args,
) async {
  final (ui.RootIsolateToken token, SendPort helloPort) = args;
  // flutter_onnxruntime's MethodChannel calls are forwarded to the root
  // isolate through the background binary messenger. The full Flutter binding
  // must NOT be initialized here (the engine rejects UI operations off the
  // root isolate).
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final ReceivePort commandPort = ReceivePort();
  helloPort.send(<String, dynamic>{'op': 'ready', 'port': commandPort.sendPort});
  final OnnxRuntime runtime = OnnxRuntime(log: noopOnnxRuntimeLog);
  await runtime.initialize();
  final Map<int, InferenceCancellationToken> tokens =
      <int, InferenceCancellationToken>{};
  await for (final dynamic message in commandPort) {
    if (message is! Map) {
      continue;
    }
    switch (message['op'] as String? ?? '') {
      case 'upscale':
        final int id = message['id'] as int;
        final SendPort reply = message['reply'] as SendPort;
        final InferenceCancellationToken token = InferenceCancellationToken();
        tokens[id] = token;
        unawaited(
          _handleUpscale(
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
        // Handle off the message loop so a queued cancel/upscale is not
        // delayed while sessions drain; in-flight upscale aborts cooperatively.
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
  (message['reply'] as SendPort?)?.send(<String, dynamic>{'done': true, 'ok': ok});
}

Future<void> _closeSessionsInWorker(
  OnnxRuntime runtime,
  Map<dynamic, dynamic> message,
  Map<int, InferenceCancellationToken> tokens,
) async {
  for (final InferenceCancellationToken token in tokens.values) {
    token.cancel('session closed');
  }
  await runtime.closeSessions();
  (message['reply'] as SendPort?)?.send(<String, dynamic>{'done': true});
}

Future<void> _handleUpscale(
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
    final List<ort.OrtProvider> providers = providerNames
        .map(
          (String name) => ort.OrtProvider.values.firstWhere(
            (ort.OrtProvider provider) => provider.name == name,
            orElse: () => ort.OrtProvider.CPU,
          ),
        )
        .toList();
    final Map<dynamic, dynamic> model = message['model'] as Map;
    final OnnxSuperResolutionInferenceEngine engine =
        OnnxSuperResolutionInferenceEngine(
          runtime: runtime,
          providerResolver: () => providers,
          model: OnnxSuperResolutionModelInfo(
            modelPath: model['modelPath'] as String,
            fingerprint: model['fingerprint'] as String,
          ),
        );
    await engine.upscale(
      inputPath: message['inputPath'] as String,
      outputPath: message['outputPath'] as String,
      scale: message['scale'] as int,
      cancellationToken: token,
      onProgress: (double progress) =>
          reply.send(<String, dynamic>{'progress': progress}),
    );
    reply.send(<String, dynamic>{'done': true, 'ok': true});
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
