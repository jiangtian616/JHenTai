import 'dart:async';

import 'engine/engine_contract.dart';
import 'lan_compute_protocol.dart';

typedef LanComputeTaskStarter = EngineTask<LanComputeDataRef> Function();

typedef LanComputeSchedulerEventSink =
    void Function(LanComputeSchedulerEvent event);

enum LanComputeSchedulerState {
  admitted,
  queued,
  running,
  cancelled,
  completed,
  failed,
}

extension LanComputeSchedulerStateWire on LanComputeSchedulerState {
  String get wireName => switch (this) {
    LanComputeSchedulerState.admitted => 'admitted',
    LanComputeSchedulerState.queued => 'queued',
    LanComputeSchedulerState.running => 'running',
    LanComputeSchedulerState.cancelled => 'cancelled',
    LanComputeSchedulerState.completed => 'completed',
    LanComputeSchedulerState.failed => 'failed',
  };
}

enum LanComputeAdmissionReason {
  schedulerClosed,
  duplicateTask,
  invalidEstimate,
  inputTooLarge,
  outputTooLarge,
  modelMemoryTooLarge,
  memoryBudgetExceeded,
  concurrencyLimit,
  queueFull,
}

extension LanComputeAdmissionReasonWire on LanComputeAdmissionReason {
  String get wireName => switch (this) {
    LanComputeAdmissionReason.schedulerClosed => 'schedulerClosed',
    LanComputeAdmissionReason.duplicateTask => 'duplicateTask',
    LanComputeAdmissionReason.invalidEstimate => 'invalidEstimate',
    LanComputeAdmissionReason.inputTooLarge => 'inputTooLarge',
    LanComputeAdmissionReason.outputTooLarge => 'outputTooLarge',
    LanComputeAdmissionReason.modelMemoryTooLarge => 'modelMemoryTooLarge',
    LanComputeAdmissionReason.memoryBudgetExceeded => 'memoryBudgetExceeded',
    LanComputeAdmissionReason.concurrencyLimit => 'concurrencyLimit',
    LanComputeAdmissionReason.queueFull => 'queueFull',
  };
}

/// A bounded, displayable error returned before an executor is started.
class LanComputeAdmissionException implements Exception {
  final LanComputeAdmissionReason reason;
  final String message;

  const LanComputeAdmissionException(this.reason, this.message);

  String get code => 'admission.${reason.wireName}';

  @override
  String toString() => 'LanComputeAdmissionException[$code]: $message';
}

/// Resource reservations are explicit. A scheduler never guesses native model
/// memory from a model name or from the Dart task count.
class LanComputeResourceEstimate {
  final int inputBytes;
  final int outputBytes;
  final int modelMemoryBytes;

  LanComputeResourceEstimate({
    required this.inputBytes,
    required this.outputBytes,
    required this.modelMemoryBytes,
  }) {
    if (inputBytes < 1 || outputBytes < 1 || modelMemoryBytes < 1) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.invalidEstimate,
        'resource estimates must be positive byte counts',
      );
    }
  }

  Map<String, int> toJson() => <String, int>{
    'inputBytes': inputBytes,
    'outputBytes': outputBytes,
    'modelMemoryBytes': modelMemoryBytes,
  };
}

class LanComputeSchedulerLimits {
  final int maxConcurrent;
  final int maxQueued;
  final int maxInputBytes;
  final int maxOutputBytes;
  final int maxModelMemoryBytes;

  LanComputeSchedulerLimits({
    this.maxConcurrent = 2,
    this.maxQueued = 16,
    this.maxInputBytes = LanComputeProtocol.maxArtifactBytes,
    this.maxOutputBytes = LanComputeProtocol.maxArtifactBytes,
    this.maxModelMemoryBytes = 512 * 1024 * 1024,
  }) {
    if (maxConcurrent < 1 ||
        maxQueued < 0 ||
        maxInputBytes < 1 ||
        maxOutputBytes < 1 ||
        maxModelMemoryBytes < 1) {
      throw ArgumentError('LAN compute scheduler limits must be positive');
    }
  }
}

class LanComputeSchedulerEvent {
  final String taskId;
  final LanComputeSchedulerState state;
  final String? reason;

  const LanComputeSchedulerEvent({
    required this.taskId,
    required this.state,
    this.reason,
  });
}

/// A task admitted by [LanComputeScheduler]. The progress stream is forwarded
/// from the executor only after the scheduler owns a concurrency slot.
class LanComputeScheduledExecution {
  final Future<LanComputeDataRef> future;
  final Stream<EngineTaskProgress> progress;
  final bool wasQueued;
  final void Function(String reason) _cancelCallback;

  LanComputeScheduledExecution({
    required this.future,
    required this.progress,
    required this.wasQueued,
    required void Function(String reason) cancel,
  }) : _cancelCallback = cancel;

  void cancel([String reason = 'cancelled']) => _cancelCallback(reason);
}

/// Compute-only scheduler. It is deliberately independent from the image
/// download/prefetch queues and reserves model memory for queued work as well
/// as running work.
class LanComputeScheduler {
  final LanComputeSchedulerLimits limits;
  final LanComputeSchedulerEventSink? onEvent;
  final Map<String, _LanComputeScheduledEntry> _entries =
      <String, _LanComputeScheduledEntry>{};
  final List<_LanComputeScheduledEntry> _queue = <_LanComputeScheduledEntry>[];
  bool _closed = false;
  bool _pumpScheduled = false;
  int _starting = 0;
  int _running = 0;
  int _reservedModelMemoryBytes = 0;

  LanComputeScheduler({LanComputeSchedulerLimits? limits, this.onEvent})
    : limits = limits ?? LanComputeSchedulerLimits();

  bool get isClosed => _closed;
  int get runningCount => _running;
  int get queuedCount => _queue.length;
  int get activeCount => _entries.length;
  int get reservedModelMemoryBytes => _reservedModelMemoryBytes;

  int get _occupiedSlotCount => _starting + _running;

  LanComputeScheduledExecution schedule({
    required LanComputeTaskRequest request,
    required LanComputeResourceEstimate estimate,
    required LanComputeTaskStarter start,
    LanComputeSchedulerEventSink? onEvent,
  }) {
    _admit(request, estimate);
    final _LanComputeScheduledEntry entry = _LanComputeScheduledEntry(
      request: request,
      estimate: estimate,
      start: start,
      onEvent: onEvent ?? this.onEvent,
      wasQueued: _occupiedSlotCount >= limits.maxConcurrent,
    );
    _entries[request.taskId] = entry;
    _reservedModelMemoryBytes += estimate.modelMemoryBytes;
    _notify(entry, LanComputeSchedulerState.admitted);
    if (entry.wasQueued) {
      _queue.add(entry);
      _notify(entry, LanComputeSchedulerState.queued);
    } else {
      _reserveStart(entry);
    }
    return LanComputeScheduledExecution(
      future: entry.completer.future,
      progress: entry.progressController.stream,
      wasQueued: entry.wasQueued,
      cancel: (String reason) => _cancel(entry, reason),
    );
  }

  void _admit(
    LanComputeTaskRequest request,
    LanComputeResourceEstimate estimate,
  ) {
    if (_closed) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.schedulerClosed,
        'compute scheduler is closed',
      );
    }
    if (_entries.containsKey(request.taskId)) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.duplicateTask,
        'task id is already active',
      );
    }
    if (estimate.inputBytes != request.input.sizeBytes) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.invalidEstimate,
        'input estimate does not match the protocol input reference',
      );
    }
    if (estimate.inputBytes > limits.maxInputBytes) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.inputTooLarge,
        'input exceeds the LAN compute input budget',
      );
    }
    if (estimate.outputBytes > limits.maxOutputBytes) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.outputTooLarge,
        'output reservation exceeds the LAN compute output budget',
      );
    }
    if (estimate.modelMemoryBytes > limits.maxModelMemoryBytes) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.modelMemoryTooLarge,
        'model memory estimate exceeds the LAN compute memory budget',
      );
    }
    if (_reservedModelMemoryBytes + estimate.modelMemoryBytes >
        limits.maxModelMemoryBytes) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.memoryBudgetExceeded,
        'reserved model memory exceeds the LAN compute memory budget',
      );
    }
    if (_occupiedSlotCount >= limits.maxConcurrent &&
        _queue.length >= limits.maxQueued) {
      throw const LanComputeAdmissionException(
        LanComputeAdmissionReason.queueFull,
        'LAN compute queue is full',
      );
    }
  }

  void _reserveStart(_LanComputeScheduledEntry entry) {
    entry.slotReserved = true;
    _starting++;
    scheduleMicrotask(() => _start(entry));
  }

  void _start(_LanComputeScheduledEntry entry) {
    if (!entry.slotReserved) {
      return;
    }
    if (_closed || entry.terminal || entry.cancelRequested) {
      return;
    }
    if (!identical(_entries[entry.request.taskId], entry)) {
      return;
    }
    entry.slotReserved = false;
    _starting--;
    entry.running = true;
    _running++;
    _notify(entry, LanComputeSchedulerState.running);
    try {
      final EngineTask<LanComputeDataRef> task = entry.start();
      entry.engineTask = task;
      entry.progressSubscription = task.progress.listen((EngineTaskProgress p) {
        if (!entry.terminal && !entry.progressController.isClosed) {
          entry.progressController.add(p);
        }
      });
      unawaited(_observe(entry, task));
    } on Object catch (error, stack) {
      _completeError(entry, error, stack);
    }
  }

  Future<void> _observe(
    _LanComputeScheduledEntry entry,
    EngineTask<LanComputeDataRef> task,
  ) async {
    try {
      final LanComputeDataRef output = await task.future;
      if (output.sizeBytes > entry.estimate.outputBytes) {
        throw EngineException(
          code: LanComputeErrorCode.resourceExhausted.wireName,
          message: 'executor output exceeded its admitted byte budget',
          engineId: 'lan-compute-scheduler',
        );
      }
      _complete(entry, output);
    } on Object catch (error, stack) {
      _completeError(entry, error, stack);
    }
  }

  void _cancel(_LanComputeScheduledEntry entry, String reason) {
    if (entry.terminal || entry.cancelRequested) {
      return;
    }
    entry.cancelRequested = true;
    if (!entry.running) {
      _removeQueued(entry);
      _completeError(
        entry,
        EngineTaskCancelledException(reason),
        StackTrace.current,
      );
      return;
    }
    // EngineCancellationToken is backed by a synchronous controller. Defer
    // task.cancel so a transport callback cannot close/add to that controller
    // while it is dispatching its current event.
    scheduleMicrotask(() {
      if (!entry.terminal && identical(_entries[entry.request.taskId], entry)) {
        entry.engineTask?.cancel(reason);
      }
    });
  }

  void _removeQueued(_LanComputeScheduledEntry entry) {
    _queue.remove(entry);
  }

  void _complete(_LanComputeScheduledEntry entry, LanComputeDataRef output) {
    if (entry.terminal) {
      return;
    }
    _release(entry);
    _notify(entry, LanComputeSchedulerState.completed);
    if (!entry.completer.isCompleted) {
      entry.completer.complete(output);
    }
    _closeProgress(entry);
    _pumpLater();
  }

  void _completeError(
    _LanComputeScheduledEntry entry,
    Object error,
    StackTrace stack,
  ) {
    if (entry.terminal) {
      return;
    }
    _release(entry);
    final bool cancelled =
        error is EngineTaskCancelledException || entry.cancelRequested;
    _notify(
      entry,
      cancelled
          ? LanComputeSchedulerState.cancelled
          : LanComputeSchedulerState.failed,
      reason: error is EngineException ? error.code : 'failed',
    );
    if (!entry.completer.isCompleted) {
      entry.completer.completeError(error, stack);
    }
    _closeProgress(entry);
    _pumpLater();
  }

  void _release(_LanComputeScheduledEntry entry) {
    if (entry.terminal) {
      return;
    }
    entry.terminal = true;
    _entries.remove(entry.request.taskId);
    _removeQueued(entry);
    if (entry.running) {
      _running--;
    } else if (entry.slotReserved) {
      entry.slotReserved = false;
      _starting--;
    }
    _reservedModelMemoryBytes -= entry.estimate.modelMemoryBytes;
    if (_reservedModelMemoryBytes < 0) {
      _reservedModelMemoryBytes = 0;
    }
    unawaited(entry.progressSubscription?.cancel());
  }

  void _closeProgress(_LanComputeScheduledEntry entry) {
    if (!entry.progressController.isClosed) {
      unawaited(entry.progressController.close());
    }
  }

  void _pumpLater() {
    if (_pumpScheduled || _closed) {
      return;
    }
    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      while (!_closed &&
          _occupiedSlotCount < limits.maxConcurrent &&
          _queue.isNotEmpty) {
        final _LanComputeScheduledEntry entry = _queue.removeAt(0);
        if (entry.terminal || entry.cancelRequested) {
          continue;
        }
        _reserveStart(entry);
      }
    });
  }

  void _notify(
    _LanComputeScheduledEntry entry,
    LanComputeSchedulerState state, {
    String? reason,
  }) {
    entry.onEvent?.call(
      LanComputeSchedulerEvent(
        taskId: entry.request.taskId,
        state: state,
        reason: reason,
      ),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final _LanComputeScheduledEntry entry in _entries.values.toList()) {
      _cancel(entry, LanComputeCancelReason.shutdown.wireName);
    }
    _queue.clear();
  }
}

class _LanComputeScheduledEntry {
  final LanComputeTaskRequest request;
  final LanComputeResourceEstimate estimate;
  final LanComputeTaskStarter start;
  final LanComputeSchedulerEventSink? onEvent;
  final bool wasQueued;
  final Completer<LanComputeDataRef> completer = Completer<LanComputeDataRef>();
  final StreamController<EngineTaskProgress> progressController =
      StreamController<EngineTaskProgress>.broadcast();
  EngineTask<LanComputeDataRef>? engineTask;
  StreamSubscription<EngineTaskProgress>? progressSubscription;
  bool slotReserved = false;
  bool running = false;
  bool terminal = false;
  bool cancelRequested = false;

  _LanComputeScheduledEntry({
    required this.request,
    required this.estimate,
    required this.start,
    required this.onEvent,
    required this.wasQueued,
  });
}

/// The cache key contains only stable fingerprints and executor identity. It
/// intentionally never contains input text, image bytes, cookies or tokens.
class LanComputeTaskCacheKey {
  final LanComputeCapability capability;
  final String inputHash;
  final String modelHash;
  final String configHash;
  final String? promptHash;
  final String schemaHash;
  final LanComputeExecutorIdentity executor;

  LanComputeTaskCacheKey({
    required this.capability,
    required this.inputHash,
    required this.modelHash,
    required this.configHash,
    required this.promptHash,
    required this.schemaHash,
    required this.executor,
  }) {
    _assertHash(inputHash, 'inputHash');
    _assertHash(modelHash, 'modelHash');
    _assertHash(configHash, 'configHash');
    if (promptHash != null) {
      _assertHash(promptHash!, 'promptHash');
    }
    if (schemaHash != LanComputeProtocol.schemaHash) {
      throw ArgumentError.value(schemaHash, 'schemaHash');
    }
  }

  factory LanComputeTaskCacheKey.fromRequest(LanComputeTaskRequest request) =>
      LanComputeTaskCacheKey(
        capability: request.capability,
        inputHash: request.input.hash,
        modelHash: request.modelHash,
        configHash: request.configHash,
        promptHash: request.promptHash,
        schemaHash: request.schemaHash,
        executor: request.executor,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'capability': capability.wireName,
    'inputHash': inputHash,
    'modelHash': modelHash,
    'configHash': configHash,
    'promptHash': promptHash,
    'schemaHash': schemaHash,
    'executor': executor.toJson(),
  };

  String get canonicalJson => LanComputeProtocol.canonicalJson(toJson());
  String get hash => LanComputeProtocol.hashCanonical(toJson());

  static void _assertHash(String value, String field) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw ArgumentError.value(value, field, 'must be a lowercase SHA-256');
    }
  }
}

class LanComputeTaskCache {
  final Map<String, LanComputeDataRef> _values = <String, LanComputeDataRef>{};

  int get length => _values.length;

  LanComputeDataRef? read(LanComputeTaskCacheKey key) => _values[key.hash];

  bool writeIfAbsent(LanComputeTaskCacheKey key, LanComputeDataRef output) {
    if (_values.containsKey(key.hash)) {
      return false;
    }
    _values[key.hash] = output;
    return true;
  }

  void clear() => _values.clear();
}
