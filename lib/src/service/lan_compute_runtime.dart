import 'dart:async';

import 'engine/engine_contract.dart';
import 'lan_compute_protocol.dart';
import 'lan_protocol_v2.dart';

typedef LanComputeMessageSender =
    Future<void> Function(LanComputeMessage message);

typedef LanComputeAuditSink = void Function(LanComputeAuditEvent event);

typedef LanComputeClock = DateTime Function();

/// The scheduler boundary is deliberately independent from Dart's Future
/// timeout. A timeout callback can send an application-level cancel while the
/// underlying EngineTask/future is still running.
abstract interface class LanComputeScheduledTask {
  void cancel();
}

abstract interface class LanComputeTimerScheduler {
  LanComputeScheduledTask schedule(Duration delay, void Function() callback);
}

class RealLanComputeTimerScheduler implements LanComputeTimerScheduler {
  const RealLanComputeTimerScheduler();

  @override
  LanComputeScheduledTask schedule(Duration delay, void Function() callback) =>
      _RealLanComputeScheduledTask(Timer(delay, callback));
}

class _RealLanComputeScheduledTask implements LanComputeScheduledTask {
  final Timer _timer;

  const _RealLanComputeScheduledTask(this._timer);

  @override
  void cancel() => _timer.cancel();
}

/// Structured, redacted audit data. It intentionally exposes prefixes only;
/// callers must not attach input text, image bytes, cookies, or credentials.
class LanComputeAuditEvent {
  final String taskIdPrefix;
  final String deviceIdPrefix;
  final String capability;
  final String status;
  final String? hashPrefix;
  final String? errorCode;

  LanComputeAuditEvent({
    required String taskId,
    required String deviceId,
    required this.capability,
    required this.status,
    String? hash,
    this.errorCode,
  }) : taskIdPrefix = _redactedPrefix(taskId),
       deviceIdPrefix = _redactedPrefix(deviceId),
       hashPrefix = hash == null ? null : _redactedPrefix(hash, length: 12);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'taskIdPrefix': taskIdPrefix,
    'deviceIdPrefix': deviceIdPrefix,
    'capability': capability,
    'status': status,
    if (hashPrefix != null) 'hashPrefix': hashPrefix,
    if (errorCode != null) 'errorCode': errorCode,
  };
}

String _redactedPrefix(String value, {int length = 16}) {
  if (value.length <= length) {
    return value;
  }
  return value.substring(0, length);
}

bool _sameExecutor(
  LanComputeExecutorIdentity left,
  LanComputeExecutorIdentity right,
) =>
    left.deviceId == right.deviceId &&
    left.executorId == right.executorId &&
    left.platform == right.platform;

bool _sameGate(LanComputeCommitGate left, LanComputeCommitGate right) =>
    LanComputeProtocol.acceptsCommit(expected: left, actual: right);

/// Additive envelope carried inside the already-authenticated and encrypted
/// LAN v2 record. Existing v2 operations continue to use their original
/// `request`/`response` payloads.
class LanComputeRuntime {
  static const String sessionCapability = 'lanComputeV1';
  static const String envelopeType = 'lanCompute';

  static List<String> get sessionCapabilities => <String>[
    ...LanProtocolV2.capabilities,
    sessionCapability,
  ];

  static Map<String, dynamic> envelope(LanComputeMessage message) =>
      <String, dynamic>{'type': envelopeType, 'message': message.toJson()};

  static LanComputeMessage decodeEnvelope(Map<String, dynamic> payload) {
    if (payload['type'] != envelopeType || payload['message'] is! Map) {
      throw const LanComputeProtocolException(
        'LAN compute envelope is invalid',
      );
    }
    return LanComputeProtocol.fromJson(
      Map<String, dynamic>.from(payload['message'] as Map),
    );
  }

  static LanComputeUnsupported unsupportedFor(
    Map<String, dynamic> payload, {
    LanComputeUnsupportedReason reason =
        LanComputeUnsupportedReason.unsupportedSchema,
  }) {
    final Object? rawMessage = payload['message'];
    final Map<String, dynamic> raw =
        rawMessage is Map
            ? Map<String, dynamic>.from(rawMessage)
            : const <String, dynamic>{};
    final String capability = _safeIdentifier(
      raw['capability'],
      sessionCapability,
    );
    final String? taskId =
        raw['taskId'] is String
            ? _safeOptionalIdentifier(raw['taskId'] as String)
            : null;
    return LanComputeUnsupported(
      capability: capability,
      reason: reason,
      taskId: taskId,
      schemaHash: LanComputeProtocol.schemaHash,
    );
  }

  static String _safeIdentifier(Object? value, String fallback) {
    if (value is String && _safeOptionalIdentifier(value) != null) {
      return value;
    }
    return fallback;
  }

  static String? _safeOptionalIdentifier(String value) {
    if (value.isEmpty ||
        value.length > LanComputeProtocol.maxIdentifierLength) {
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value)) {
      return null;
    }
    return value;
  }
}

/// An executor is the only production-specific adapter surface in this
/// slice. The runtime never receives raw input bytes over the wire; the
/// adapter must resolve the bounded input reference and verify its hash before
/// starting its EngineTask.
abstract interface class LanComputeExecutor {
  LanComputeCapabilityDescriptor get descriptor;

  /// A text-generation adapter may bind a prompt/config fingerprint. A null
  /// value means that the request must omit promptHash.
  String? get expectedPromptHash;

  /// This is request-time input verification, not a UI capability check.
  bool acceptsInput(LanComputeDataRef input);

  EngineTask<LanComputeDataRef> execute(LanComputeTaskRequest request);
}

typedef LanComputeEngineTaskFactory =
    EngineTask<LanComputeDataRef> Function(LanComputeTaskRequest request);

/// Small adapter for native, isolate, HTTP-loopback, or fake EngineTask
/// implementations. Real adapters must provide an input hash validator.
class LanComputeEngineTaskAdapter implements LanComputeExecutor {
  @override
  final LanComputeCapabilityDescriptor descriptor;

  @override
  final String? expectedPromptHash;

  final bool Function(LanComputeDataRef input) _inputValidator;
  final LanComputeEngineTaskFactory _factory;

  LanComputeEngineTaskAdapter({
    required this.descriptor,
    required this.expectedPromptHash,
    required bool Function(LanComputeDataRef input) inputValidator,
    required LanComputeEngineTaskFactory factory,
  }) : _inputValidator = inputValidator,
       _factory = factory;

  @override
  bool acceptsInput(LanComputeDataRef input) => _inputValidator(input);

  @override
  EngineTask<LanComputeDataRef> execute(LanComputeTaskRequest request) =>
      _factory(request);
}

/// Server-side runtime for one authenticated v2 session.
///
/// The permission callback is intentionally evaluated for every task request;
/// a capability descriptor or a hidden/visible UI control is never treated as
/// authorization.
class LanComputeHostRuntime {
  final LanComputeExecutorIdentity executorIdentity;
  final String remoteDeviceId;
  final bool Function(LanComputeCapability capability) isAuthorized;
  final LanComputeTimerScheduler timerScheduler;
  final LanComputeClock clock;
  final LanComputeAuditSink? onAudit;
  final Map<LanComputeCapability, LanComputeExecutor> _executors;
  final Map<String, _LanComputeHostTask> _active =
      <String, _LanComputeHostTask>{};
  bool _closed = false;

  LanComputeHostRuntime({
    required this.executorIdentity,
    required this.remoteDeviceId,
    required this.isAuthorized,
    required Iterable<LanComputeExecutor> executors,
    required this.timerScheduler,
    this.clock = DateTime.now,
    this.onAudit,
  }) : _executors = <LanComputeCapability, LanComputeExecutor>{
         for (final LanComputeExecutor executor in executors)
           executor.descriptor.capability: executor,
       };

  bool get isClosed => _closed;

  List<LanComputeCapabilityDescriptor> get descriptors =>
      LanComputeCapability.values.map(_descriptorFor).toList(growable: false);

  LanComputeCapabilityDescriptor _descriptorFor(
    LanComputeCapability capability,
  ) {
    final LanComputeExecutor? executor = _executors[capability];
    if (executor == null) {
      return LanComputeCapabilityDescriptor(
        ready: false,
        capability: capability,
        reason: LanComputeReadinessReason.notReady,
        executor: executorIdentity,
        schemaHash: LanComputeProtocol.schemaHash,
      );
    }
    final LanComputeCapabilityDescriptor descriptor = executor.descriptor;
    if (descriptor.schemaHash != LanComputeProtocol.schemaHash ||
        descriptor.capability != capability ||
        !_sameExecutor(descriptor.executor, executorIdentity) ||
        !descriptor.ready) {
      return LanComputeCapabilityDescriptor(
        ready: false,
        capability: capability,
        reason:
            descriptor.ready
                ? LanComputeReadinessReason.notReady
                : descriptor.reason,
        executor: executorIdentity,
        schemaHash: LanComputeProtocol.schemaHash,
      );
    }
    return descriptor;
  }

  Future<void> advertise(LanComputeMessageSender send) async {
    if (_closed) return;
    for (final LanComputeCapabilityDescriptor descriptor in descriptors) {
      await send(descriptor);
    }
  }

  Future<void> handleEnvelope(
    Map<String, dynamic> payload,
    LanComputeMessageSender send,
  ) async {
    if (_closed) return;
    try {
      await handleMessage(LanComputeRuntime.decodeEnvelope(payload), send);
    } on LanComputeProtocolException {
      _audit(
        taskId: _rawTaskId(payload),
        capability: _rawCapability(payload),
        status: 'unsupported',
        errorCode: LanComputeErrorCode.unsupportedSchema.wireName,
      );
      await send(
        LanComputeRuntime.unsupportedFor(
          payload,
          reason: LanComputeUnsupportedReason.unsupportedSchema,
        ),
      );
    }
  }

  Future<void> handleMessage(
    LanComputeMessage message,
    LanComputeMessageSender send,
  ) async {
    if (_closed) return;
    switch (message) {
      case LanComputeTaskRequest request:
        await _handleTask(request, send);
      case LanComputeCancel cancel:
        await _handleCancel(cancel);
      case LanComputeCapabilityDescriptor _:
      case LanComputeProgress _:
      case LanComputeTerminalResult _:
      case LanComputeTerminalError _:
      case LanComputeUnsupported _:
        _audit(
          taskId: _messageTaskId(message),
          capability: _messageCapability(message),
          status: 'ignored_peer_message',
        );
      case LanComputeMessage _:
        _audit(
          taskId: 'unknown',
          capability: LanComputeRuntime.sessionCapability,
          status: 'ignored_peer_message',
        );
    }
  }

  Future<void> _handleTask(
    LanComputeTaskRequest request,
    LanComputeMessageSender send,
  ) async {
    if (_active.containsKey(request.taskId)) {
      await _sendError(
        request,
        LanComputeErrorCode.invalidRequest,
        retryable: false,
        send: send,
      );
      return;
    }
    LanComputeErrorCode? rejection;
    LanComputeExecutor? executor;
    final LanComputeCapabilityDescriptor descriptor = _descriptorFor(
      request.capability,
    );
    try {
      if (!isAuthorized(request.capability)) {
        rejection = LanComputeErrorCode.notAuthorized;
      } else if (!descriptor.ready) {
        rejection = LanComputeErrorCode.notReady;
      } else if (!_sameExecutor(request.executor, executorIdentity)) {
        rejection = LanComputeErrorCode.executorUnavailable;
      } else if (request.modelHash != descriptor.modelHash ||
          request.configHash != descriptor.configHash) {
        rejection = LanComputeErrorCode.hashMismatch;
      } else {
        executor = _executors[request.capability];
        if (executor == null ||
            executor.expectedPromptHash != request.promptHash ||
            !executor.acceptsInput(request.input)) {
          rejection = LanComputeErrorCode.hashMismatch;
        }
      }
      if (rejection == null &&
          request.deadlineEpochMs <= clock().millisecondsSinceEpoch) {
        rejection = LanComputeErrorCode.deadlineExceeded;
      }
    } on Object {
      rejection = LanComputeErrorCode.hashMismatch;
    }
    if (rejection != null || executor == null) {
      final LanComputeErrorCode code =
          rejection ?? LanComputeErrorCode.executorUnavailable;
      _audit(
        taskId: request.taskId,
        capability: request.capability.wireName,
        status: 'rejected',
        hash: request.input.hash,
        errorCode: code.wireName,
      );
      await _sendError(
        request,
        code,
        retryable: _isRetryable(code),
        send: send,
      );
      return;
    }

    final EngineTask<LanComputeDataRef> task;
    try {
      task = executor.execute(request);
    } on Object {
      _audit(
        taskId: request.taskId,
        capability: request.capability.wireName,
        status: 'executor_unavailable',
        hash: request.input.hash,
        errorCode: LanComputeErrorCode.executorUnavailable.wireName,
      );
      await _sendError(
        request,
        LanComputeErrorCode.executorUnavailable,
        retryable: true,
        send: send,
      );
      return;
    }
    final _LanComputeHostTask entry = _LanComputeHostTask(
      request: request,
      task: task,
    );
    _active[request.taskId] = entry;
    _audit(
      taskId: request.taskId,
      capability: request.capability.wireName,
      status: 'accepted',
      hash: request.input.hash,
    );
    await _sendProgress(
      entry,
      stage: LanComputeProgressStage.queued,
      progress: 0,
      send: send,
    );
    entry.progressSubscription = task.progress.listen((EngineTaskProgress p) {
      final LanComputeProgressStage? stage = _progressStage(p.stage);
      if (stage == null || _closed || !identical(_active[p.taskId], entry)) {
        return;
      }
      unawaited(
        _sendProgress(
          entry,
          stage: stage,
          progress: p.fraction,
          send: send,
        ).catchError((Object _) {}),
      );
    });
    final int remainingMs =
        request.deadlineEpochMs - clock().millisecondsSinceEpoch;
    if (remainingMs > 0) {
      entry.deadlineTimer = timerScheduler.schedule(
        Duration(milliseconds: remainingMs),
        () {
          if (!identical(_active[request.taskId], entry)) return;
          entry.deadlineExceeded = true;
          task.cancel(LanComputeCancelReason.deadline.wireName);
        },
      );
    }
    unawaited(_finishTask(entry, send));
  }

  Future<void> _handleCancel(LanComputeCancel cancel) async {
    final _LanComputeHostTask? entry = _active[cancel.taskId];
    if (entry == null) {
      _audit(
        taskId: cancel.taskId,
        capability: cancel.capability.wireName,
        status: 'late_cancel',
      );
      return;
    }
    if (entry.request.capability != cancel.capability ||
        !_sameExecutor(cancel.executor, executorIdentity) ||
        !_sameGate(entry.request.commitGate, cancel.commitGate)) {
      _audit(
        taskId: cancel.taskId,
        capability: cancel.capability.wireName,
        status: 'invalid_cancel',
        errorCode: LanComputeErrorCode.staleGeneration.wireName,
      );
      return;
    }
    entry.cancelRequested = true;
    entry.deadlineTimer?.cancel();
    // Defer cancellation until the incoming message callback has returned.
    // EngineTask's cancellation stream is synchronous; cascading a remote
    // cancel from inside another cancellation stream would close its
    // controller while it is still dispatching.
    scheduleMicrotask(() {
      if (identical(_active[cancel.taskId], entry)) {
        entry.task.cancel(cancel.reason.wireName);
      }
    });
    _audit(
      taskId: cancel.taskId,
      capability: cancel.capability.wireName,
      status: 'cancel_requested',
    );
  }

  Future<void> _finishTask(
    _LanComputeHostTask entry,
    LanComputeMessageSender send,
  ) async {
    try {
      final LanComputeDataRef output = await entry.task.future;
      if (_closed || !identical(_active[entry.request.taskId], entry)) {
        return;
      }
      _active.remove(entry.request.taskId);
      await send(
        LanComputeTerminalResult(
          taskId: entry.request.taskId,
          capability: entry.request.capability,
          output: output,
          completedAtEpochMs: _nowEpochMs,
          executor: executorIdentity,
          commitGate: entry.request.commitGate,
          schemaHash: LanComputeProtocol.schemaHash,
        ),
      );
      _audit(
        taskId: entry.request.taskId,
        capability: entry.request.capability.wireName,
        status: 'terminal_result',
        hash: output.hash,
      );
    } on Object catch (error) {
      if (_closed || !identical(_active[entry.request.taskId], entry)) {
        return;
      }
      _active.remove(entry.request.taskId);
      final LanComputeErrorCode code = _errorCode(error, entry);
      await _sendError(
        entry.request,
        code,
        retryable: _isRetryable(code),
        send: send,
      );
      _audit(
        taskId: entry.request.taskId,
        capability: entry.request.capability.wireName,
        status: 'terminal_error',
        errorCode: code.wireName,
      );
    } finally {
      entry.progressSubscription?.cancel();
      entry.deadlineTimer?.cancel();
    }
  }

  Future<void> _sendProgress(
    _LanComputeHostTask entry, {
    required LanComputeProgressStage stage,
    required double progress,
    required LanComputeMessageSender send,
  }) async {
    if (_closed || !identical(_active[entry.request.taskId], entry)) return;
    await send(
      LanComputeProgress(
        taskId: entry.request.taskId,
        capability: entry.request.capability,
        stage: stage,
        progress: progress,
        observedAtEpochMs: _nowEpochMs,
        executor: executorIdentity,
        commitGate: entry.request.commitGate,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
    );
    _audit(
      taskId: entry.request.taskId,
      capability: entry.request.capability.wireName,
      status: 'progress',
    );
  }

  Future<void> _sendError(
    LanComputeTaskRequest request,
    LanComputeErrorCode code, {
    required bool retryable,
    required LanComputeMessageSender send,
  }) => send(
    LanComputeTerminalError(
      taskId: request.taskId,
      capability: request.capability,
      code: code,
      retryable: retryable,
      completedAtEpochMs: _nowEpochMs,
      executor: executorIdentity,
      commitGate: request.commitGate,
      schemaHash: LanComputeProtocol.schemaHash,
    ),
  );

  LanComputeErrorCode _errorCode(Object error, _LanComputeHostTask entry) {
    if (entry.deadlineExceeded) {
      return LanComputeErrorCode.deadlineExceeded;
    }
    if (error is EngineTaskCancelledException || entry.cancelRequested) {
      return LanComputeErrorCode.cancelled;
    }
    if (error is EngineException) {
      return switch (error.code) {
        'executorUnavailable' => LanComputeErrorCode.executorUnavailable,
        'resourceExhausted' => LanComputeErrorCode.resourceExhausted,
        'deadlineExceeded' => LanComputeErrorCode.deadlineExceeded,
        'cancelled' => LanComputeErrorCode.cancelled,
        _ => LanComputeErrorCode.failed,
      };
    }
    return LanComputeErrorCode.failed;
  }

  int get _nowEpochMs => clock().millisecondsSinceEpoch;

  LanComputeProgressStage? _progressStage(EngineTaskStage stage) =>
      switch (stage) {
        EngineTaskStage.queued ||
        EngineTaskStage.loading => LanComputeProgressStage.queued,
        EngineTaskStage.processing => LanComputeProgressStage.running,
        EngineTaskStage.finalizing => LanComputeProgressStage.finalizing,
        EngineTaskStage.completed => null,
      };

  void _audit({
    required String taskId,
    required String capability,
    required String status,
    String? hash,
    String? errorCode,
  }) {
    onAudit?.call(
      LanComputeAuditEvent(
        taskId: taskId,
        deviceId: remoteDeviceId,
        capability: capability,
        status: status,
        hash: hash,
        errorCode: errorCode,
      ),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final _LanComputeHostTask entry in _active.values.toList()) {
      entry.deadlineTimer?.cancel();
      entry.progressSubscription?.cancel();
      entry.task.cancel(LanComputeCancelReason.disconnected.wireName);
    }
    _active.clear();
  }

  static bool _isRetryable(LanComputeErrorCode code) => switch (code) {
    LanComputeErrorCode.executorUnavailable ||
    LanComputeErrorCode.resourceExhausted ||
    LanComputeErrorCode.failed => true,
    _ => false,
  };

  static String _rawTaskId(Map<String, dynamic> payload) {
    final Object? message = payload['message'];
    if (message is Map && message['taskId'] is String) {
      return message['taskId'] as String;
    }
    return 'unknown';
  }

  static String _rawCapability(Map<String, dynamic> payload) {
    final Object? message = payload['message'];
    if (message is Map && message['capability'] is String) {
      return message['capability'] as String;
    }
    return LanComputeRuntime.sessionCapability;
  }

  static String _messageTaskId(LanComputeMessage message) => switch (message) {
    LanComputeTaskRequest value => value.taskId,
    LanComputeProgress value => value.taskId,
    LanComputeCancel value => value.taskId,
    LanComputeTerminalResult value => value.taskId,
    LanComputeTerminalError value => value.taskId,
    LanComputeUnsupported value => value.taskId ?? 'unknown',
    LanComputeCapabilityDescriptor _ => 'descriptor',
    LanComputeMessage _ => 'unknown',
  };

  static String _messageCapability(LanComputeMessage message) =>
      switch (message) {
        LanComputeTaskRequest value => value.capability.wireName,
        LanComputeProgress value => value.capability.wireName,
        LanComputeCancel value => value.capability.wireName,
        LanComputeTerminalResult value => value.capability.wireName,
        LanComputeTerminalError value => value.capability.wireName,
        LanComputeUnsupported value => value.capability,
        LanComputeCapabilityDescriptor value => value.capability.wireName,
        LanComputeMessage _ => LanComputeRuntime.sessionCapability,
      };
}

class _LanComputeHostTask {
  final LanComputeTaskRequest request;
  final EngineTask<LanComputeDataRef> task;
  StreamSubscription<EngineTaskProgress>? progressSubscription;
  LanComputeScheduledTask? deadlineTimer;
  bool deadlineExceeded = false;
  bool cancelRequested = false;

  _LanComputeHostTask({required this.request, required this.task});
}

/// Client-side session surface exposed only after authenticated v2 setup.
abstract interface class LanComputeSession {
  LanComputeCapabilityDescriptor? computeDescriptor(
    LanComputeCapability capability,
  );

  EngineTask<LanComputeDataRef> requestCompute({
    required String taskId,
    required LanComputeCapability capability,
    required String modelHash,
    required String configHash,
    String? promptHash,
    required LanComputeDataRef input,
    required int deadlineEpochMs,
    required LanComputeCommitGate commitGate,
  });
}

/// Client lifecycle adapter for one encrypted session. It owns the pending
/// task map, explicit cancel messages, deadline cancellation and stale-result
/// filtering. It has no fallback or scheduler ownership by design.
class LanComputeClientRuntime implements LanComputeSession {
  final bool peerSupportsCompute;
  final LanComputeMessageSender _send;
  final LanComputeTimerScheduler timerScheduler;
  final LanComputeClock clock;
  final LanComputeAuditSink? onAudit;
  final void Function(LanComputeTerminalResult result)? onCommit;
  final Map<LanComputeCapability, LanComputeCapabilityDescriptor> _descriptors =
      <LanComputeCapability, LanComputeCapabilityDescriptor>{};
  final Map<String, _LanComputeClientTask> _pending =
      <String, _LanComputeClientTask>{};
  bool _closed = false;

  LanComputeClientRuntime({
    required this.peerSupportsCompute,
    required LanComputeMessageSender send,
    required this.timerScheduler,
    this.clock = DateTime.now,
    this.onAudit,
    this.onCommit,
  }) : _send = send;

  bool get isClosed => _closed;

  @override
  LanComputeCapabilityDescriptor? computeDescriptor(
    LanComputeCapability capability,
  ) => _descriptors[capability];

  Future<void> handleEnvelope(Map<String, dynamic> payload) async {
    if (_closed) return;
    try {
      handleMessage(LanComputeRuntime.decodeEnvelope(payload));
    } on LanComputeProtocolException {
      _audit(
        taskId: _rawTaskId(payload),
        capability: _rawCapability(payload),
        status: 'unsupported',
        errorCode: LanComputeErrorCode.unsupportedSchema.wireName,
      );
    }
  }

  void handleMessage(LanComputeMessage message) {
    if (_closed) return;
    switch (message) {
      case LanComputeCapabilityDescriptor descriptor:
        if (descriptor.schemaHash == LanComputeProtocol.schemaHash) {
          _descriptors[descriptor.capability] = descriptor;
          _audit(
            taskId: 'descriptor',
            capability: descriptor.capability.wireName,
            status: descriptor.ready ? 'ready' : 'not_ready',
            hash: descriptor.modelHash,
          );
        }
      case LanComputeProgress progress:
        _handleProgress(progress);
      case LanComputeTerminalResult result:
        _handleResult(result);
      case LanComputeTerminalError error:
        _handleError(error);
      case LanComputeUnsupported unsupported:
        _handleUnsupported(unsupported);
      case LanComputeTaskRequest _:
      case LanComputeCancel _:
        _audit(
          taskId: _messageTaskId(message),
          capability: _messageCapability(message),
          status: 'ignored_peer_message',
        );
      case LanComputeMessage _:
        _audit(
          taskId: 'unknown',
          capability: LanComputeRuntime.sessionCapability,
          status: 'ignored_peer_message',
        );
    }
  }

  @override
  EngineTask<LanComputeDataRef> requestCompute({
    required String taskId,
    required LanComputeCapability capability,
    required String modelHash,
    required String configHash,
    String? promptHash,
    required LanComputeDataRef input,
    required int deadlineEpochMs,
    required LanComputeCommitGate commitGate,
  }) => EngineTask<LanComputeDataRef>.start(
    id: taskId,
    operation:
        (EngineTaskContext context) => _runRequest(
          context,
          taskId: taskId,
          capability: capability,
          modelHash: modelHash,
          configHash: configHash,
          promptHash: promptHash,
          input: input,
          deadlineEpochMs: deadlineEpochMs,
          commitGate: commitGate,
        ),
  );

  Future<LanComputeDataRef> _runRequest(
    EngineTaskContext context, {
    required String taskId,
    required LanComputeCapability capability,
    required String modelHash,
    required String configHash,
    required String? promptHash,
    required LanComputeDataRef input,
    required int deadlineEpochMs,
    required LanComputeCommitGate commitGate,
  }) async {
    context.cancellation.throwIfCancelled();
    if (_closed) {
      throw _clientError('disconnected', 'session is closed');
    }
    if (!peerSupportsCompute) {
      throw _clientError('unsupported', 'peer does not support lanCompute');
    }
    final LanComputeCapabilityDescriptor? descriptor = _descriptors[capability];
    if (descriptor == null) {
      throw _clientError('unsupported', 'peer has no compute descriptor');
    }
    if (!descriptor.ready) {
      throw _clientError('notReady', 'remote executor is not ready');
    }
    if (descriptor.schemaHash != LanComputeProtocol.schemaHash ||
        descriptor.modelHash != modelHash ||
        descriptor.configHash != configHash) {
      throw _clientError('hashMismatch', 'remote descriptor hash mismatch');
    }
    final LanComputeTaskRequest request = LanComputeTaskRequest(
      taskId: taskId,
      capability: capability,
      modelHash: modelHash,
      configHash: configHash,
      promptHash: promptHash,
      input: input,
      deadlineEpochMs: deadlineEpochMs,
      executor: descriptor.executor,
      commitGate: commitGate,
      schemaHash: LanComputeProtocol.schemaHash,
    );
    if (deadlineEpochMs <= clock().millisecondsSinceEpoch) {
      throw _clientError(
        LanComputeErrorCode.deadlineExceeded.wireName,
        'deadline already elapsed',
      );
    }
    if (_pending.containsKey(taskId)) {
      throw _clientError('invalidRequest', 'duplicate task id');
    }
    final _LanComputeClientTask pending = _LanComputeClientTask(
      request: request,
      context: context,
    );
    _pending[taskId] = pending;
    try {
      await _send(request);
      if (context.cancellation.isCancelled) {
        await _cancelPending(
          taskId,
          _cancelReason(context.cancellation.reason),
        );
        context.cancellation.throwIfCancelled();
      }
      final int remainingMs = deadlineEpochMs - clock().millisecondsSinceEpoch;
      if (remainingMs > 0 && !pending.completer.isCompleted) {
        pending.deadlineTimer = timerScheduler.schedule(
          Duration(milliseconds: remainingMs),
          () => unawaited(_timeoutPending(taskId)),
        );
      }
      pending.cancelSubscription = context.cancellation.onCancel.listen(
        (String reason) =>
            unawaited(_cancelPending(taskId, _cancelReason(reason))),
      );
      if (context.cancellation.isCancelled) {
        await _cancelPending(
          taskId,
          _cancelReason(context.cancellation.reason),
        );
      }
      return await pending.completer.future;
    } on Object {
      if (identical(_pending[taskId], pending)) {
        _pending.remove(taskId);
        pending.deadlineTimer?.cancel();
      }
      rethrow;
    } finally {
      await pending.cancelSubscription?.cancel();
      pending.deadlineTimer?.cancel();
      if (identical(_pending[taskId], pending) &&
          pending.completer.isCompleted) {
        _pending.remove(taskId);
      }
    }
  }

  void _handleProgress(LanComputeProgress progress) {
    final _LanComputeClientTask? pending = _pending[progress.taskId];
    if (pending == null) {
      _audit(
        taskId: progress.taskId,
        capability: progress.capability.wireName,
        status: 'late_progress',
      );
      return;
    }
    if (!_matches(pending.request, progress)) {
      _audit(
        taskId: progress.taskId,
        capability: progress.capability.wireName,
        status: 'stale_progress',
        errorCode: LanComputeErrorCode.staleGeneration.wireName,
      );
      return;
    }
    try {
      pending.context.report(_engineStage(progress.stage), progress.progress);
      _audit(
        taskId: progress.taskId,
        capability: progress.capability.wireName,
        status: 'progress',
      );
    } on EngineTaskCancelledException {
      // The cancellation subscription owns the explicit cancel message.
    }
  }

  void _handleResult(LanComputeTerminalResult result) {
    final _LanComputeClientTask? pending = _pending[result.taskId];
    if (pending == null) {
      _audit(
        taskId: result.taskId,
        capability: result.capability.wireName,
        status: 'late_result',
        hash: result.output.hash,
      );
      return;
    }
    if (!_matches(pending.request, result)) {
      _audit(
        taskId: result.taskId,
        capability: result.capability.wireName,
        status: 'stale_result',
        hash: result.output.hash,
        errorCode: LanComputeErrorCode.staleGeneration.wireName,
      );
      return;
    }
    _removePending(result.taskId, pending);
    onCommit?.call(result);
    pending.completer.complete(result.output);
    _audit(
      taskId: result.taskId,
      capability: result.capability.wireName,
      status: 'terminal_result',
      hash: result.output.hash,
    );
  }

  void _handleError(LanComputeTerminalError error) {
    final _LanComputeClientTask? pending = _pending[error.taskId];
    if (pending == null) {
      _audit(
        taskId: error.taskId,
        capability: error.capability.wireName,
        status: 'late_error',
        errorCode: error.code.wireName,
      );
      return;
    }
    if (!_matches(pending.request, error)) {
      _audit(
        taskId: error.taskId,
        capability: error.capability.wireName,
        status: 'stale_error',
        errorCode: LanComputeErrorCode.staleGeneration.wireName,
      );
      return;
    }
    _removePending(error.taskId, pending);
    if (error.code == LanComputeErrorCode.cancelled) {
      pending.completer.completeError(
        EngineTaskCancelledException(LanComputeCancelReason.user.wireName),
      );
    } else {
      pending.completer.completeError(
        _clientError(error.code.wireName, 'remote compute failed'),
      );
    }
    _audit(
      taskId: error.taskId,
      capability: error.capability.wireName,
      status: 'terminal_error',
      errorCode: error.code.wireName,
    );
  }

  void _handleUnsupported(LanComputeUnsupported unsupported) {
    final String? taskId = unsupported.taskId;
    if (taskId == null) {
      _audit(
        taskId: 'unknown',
        capability: unsupported.capability,
        status: 'unsupported',
        errorCode: unsupported.reason.wireName,
      );
      return;
    }
    final _LanComputeClientTask? pending = _pending[taskId];
    if (pending == null) return;
    _removePending(taskId, pending);
    pending.completer.completeError(
      _clientError('unsupported', 'remote compute is unsupported'),
    );
    _audit(
      taskId: taskId,
      capability: unsupported.capability,
      status: 'unsupported',
      errorCode: unsupported.reason.wireName,
    );
  }

  Future<void> _timeoutPending(String taskId) async {
    final _LanComputeClientTask? pending = _pending[taskId];
    if (pending == null || pending.completer.isCompleted) return;
    _removePending(taskId, pending);
    await _sendCancel(pending, LanComputeCancelReason.deadline);
    pending.completer.completeError(
      _clientError(
        LanComputeErrorCode.deadlineExceeded.wireName,
        'compute deadline exceeded',
      ),
    );
    _audit(
      taskId: taskId,
      capability: pending.request.capability.wireName,
      status: 'timeout',
      errorCode: LanComputeErrorCode.deadlineExceeded.wireName,
    );
  }

  Future<void> _cancelPending(
    String taskId,
    LanComputeCancelReason reason,
  ) async {
    final _LanComputeClientTask? pending = _pending[taskId];
    if (pending == null || pending.completer.isCompleted) return;
    _removePending(taskId, pending);
    await _sendCancel(pending, reason);
    if (reason == LanComputeCancelReason.deadline) {
      pending.completer.completeError(
        _clientError(
          LanComputeErrorCode.deadlineExceeded.wireName,
          'compute deadline exceeded',
        ),
      );
    } else {
      pending.completer.completeError(
        EngineTaskCancelledException(reason.wireName),
      );
    }
    _audit(
      taskId: taskId,
      capability: pending.request.capability.wireName,
      status: 'cancelled',
      errorCode: reason.wireName,
    );
  }

  Future<void> _sendCancel(
    _LanComputeClientTask pending,
    LanComputeCancelReason reason,
  ) async {
    if (_closed || !peerSupportsCompute) return;
    try {
      await _send(
        LanComputeCancel(
          taskId: pending.request.taskId,
          capability: pending.request.capability,
          reason: reason,
          requestedAtEpochMs: clock().millisecondsSinceEpoch,
          executor: pending.request.executor,
          commitGate: pending.request.commitGate,
          schemaHash: LanComputeProtocol.schemaHash,
        ),
      );
    } on Object {
      // The caller already owns the local terminal state. A send failure is a
      // disconnected signal, not a reason to pretend remote cancellation was
      // acknowledged.
    }
  }

  void _audit({
    required String taskId,
    required String capability,
    required String status,
    String? hash,
    String? errorCode,
  }) {
    onAudit?.call(
      LanComputeAuditEvent(
        taskId: taskId,
        deviceId: 'remote',
        capability: capability,
        status: status,
        hash: hash,
        errorCode: errorCode,
      ),
    );
  }

  void _removePending(String taskId, _LanComputeClientTask pending) {
    if (!identical(_pending[taskId], pending)) return;
    _pending.remove(taskId);
    pending.deadlineTimer?.cancel();
    unawaited(pending.cancelSubscription?.cancel());
  }

  bool _matches(LanComputeTaskRequest request, LanComputeMessage message) {
    final LanComputeCapability capability = switch (message) {
      LanComputeProgress value => value.capability,
      LanComputeTerminalResult value => value.capability,
      LanComputeTerminalError value => value.capability,
      _ => request.capability,
    };
    final LanComputeExecutorIdentity executor = switch (message) {
      LanComputeProgress value => value.executor,
      LanComputeTerminalResult value => value.executor,
      LanComputeTerminalError value => value.executor,
      _ => request.executor,
    };
    final LanComputeCommitGate gate = switch (message) {
      LanComputeProgress value => value.commitGate,
      LanComputeTerminalResult value => value.commitGate,
      LanComputeTerminalError value => value.commitGate,
      _ => request.commitGate,
    };
    return request.capability == capability &&
        _sameExecutor(request.executor, executor) &&
        _sameGate(request.commitGate, gate);
  }

  EngineTaskStage _engineStage(LanComputeProgressStage stage) =>
      switch (stage) {
        LanComputeProgressStage.queued => EngineTaskStage.loading,
        LanComputeProgressStage.running => EngineTaskStage.processing,
        LanComputeProgressStage.finalizing => EngineTaskStage.finalizing,
      };

  LanComputeCancelReason _cancelReason(String reason) => switch (reason) {
    'deadline' => LanComputeCancelReason.deadline,
    'disconnected' => LanComputeCancelReason.disconnected,
    'superseded' => LanComputeCancelReason.superseded,
    'shutdown' => LanComputeCancelReason.shutdown,
    _ => LanComputeCancelReason.user,
  };

  EngineException _clientError(String code, String message) => EngineException(
    code: code,
    message: message,
    engineId: 'lan-compute-client',
  );

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final _LanComputeClientTask pending in _pending.values.toList()) {
      pending.deadlineTimer?.cancel();
      await pending.cancelSubscription?.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(
          _clientError('disconnected', 'secure session closed'),
        );
      }
    }
    _pending.clear();
  }

  static String _rawTaskId(Map<String, dynamic> payload) {
    final Object? message = payload['message'];
    if (message is Map && message['taskId'] is String) {
      return message['taskId'] as String;
    }
    return 'unknown';
  }

  static String _rawCapability(Map<String, dynamic> payload) {
    final Object? message = payload['message'];
    if (message is Map && message['capability'] is String) {
      return message['capability'] as String;
    }
    return LanComputeRuntime.sessionCapability;
  }

  static String _messageTaskId(LanComputeMessage message) => switch (message) {
    LanComputeTaskRequest value => value.taskId,
    LanComputeProgress value => value.taskId,
    LanComputeCancel value => value.taskId,
    LanComputeTerminalResult value => value.taskId,
    LanComputeTerminalError value => value.taskId,
    LanComputeUnsupported value => value.taskId ?? 'unknown',
    LanComputeCapabilityDescriptor _ => 'descriptor',
    LanComputeMessage _ => 'unknown',
  };

  static String _messageCapability(LanComputeMessage message) =>
      switch (message) {
        LanComputeTaskRequest value => value.capability.wireName,
        LanComputeProgress value => value.capability.wireName,
        LanComputeCancel value => value.capability.wireName,
        LanComputeTerminalResult value => value.capability.wireName,
        LanComputeTerminalError value => value.capability.wireName,
        LanComputeUnsupported value => value.capability,
        LanComputeCapabilityDescriptor value => value.capability.wireName,
        LanComputeMessage _ => LanComputeRuntime.sessionCapability,
      };
}

class _LanComputeClientTask {
  final LanComputeTaskRequest request;
  final EngineTaskContext context;
  final Completer<LanComputeDataRef> completer = Completer<LanComputeDataRef>();
  LanComputeScheduledTask? deadlineTimer;
  StreamSubscription<String>? cancelSubscription;

  _LanComputeClientTask({required this.request, required this.context});
}
