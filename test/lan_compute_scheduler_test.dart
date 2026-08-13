import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/lan_compute_protocol.dart';
import 'package:jhentai/src/service/lan_compute_runtime.dart';
import 'package:jhentai/src/service/lan_compute_scheduler.dart';

void main() {
  test(
    'compute scheduler enforces concurrency, queue, bytes and memory',
    () async {
      final List<LanComputeSchedulerEvent> events =
          <LanComputeSchedulerEvent>[];
      final LanComputeScheduler scheduler = LanComputeScheduler(
        limits: LanComputeSchedulerLimits(
          maxConcurrent: 1,
          maxQueued: 1,
          maxInputBytes: 8,
          maxOutputBytes: 8,
          maxModelMemoryBytes: 100,
        ),
        onEvent: events.add,
      );
      final LanComputeTaskRequest firstRequest = _request('scheduler-first');
      final LanComputeTaskRequest secondRequest = _request('scheduler-second');
      final Completer<void> firstRelease = Completer<void>();
      final Completer<void> secondRelease = Completer<void>();

      final LanComputeScheduledExecution first = scheduler.schedule(
        request: firstRequest,
        estimate: _estimate(firstRequest, memory: 60),
        start: () => _heldTask(firstRequest.taskId, firstRelease),
      );
      await _settle();
      expect(scheduler.runningCount, 1);
      expect(scheduler.queuedCount, 0);

      final LanComputeScheduledExecution second = scheduler.schedule(
        request: secondRequest,
        estimate: _estimate(secondRequest, memory: 30),
        start: () => _heldTask(secondRequest.taskId, secondRelease),
      );
      expect(second.wasQueued, isTrue);
      expect(scheduler.queuedCount, 1);
      expect(
        () => scheduler.schedule(
          request: _request('queue-full'),
          estimate: _estimate(_request('queue-full'), memory: 1),
          start: () => _completedTask('queue-full'),
        ),
        throwsA(
          isA<LanComputeAdmissionException>().having(
            (LanComputeAdmissionException error) => error.reason,
            'reason',
            LanComputeAdmissionReason.queueFull,
          ),
        ),
      );

      firstRelease.complete();
      await first.future;
      await _waitFor(() => scheduler.runningCount == 1);
      secondRelease.complete();
      await second.future;
      expect(scheduler.activeCount, 0);
      expect(scheduler.reservedModelMemoryBytes, 0);
      expect(
        events.map((LanComputeSchedulerEvent event) => event.state),
        containsAll(<LanComputeSchedulerState>[
          LanComputeSchedulerState.admitted,
          LanComputeSchedulerState.queued,
          LanComputeSchedulerState.running,
          LanComputeSchedulerState.completed,
        ]),
      );

      final LanComputeTaskRequest smallRequest = _request('admission-small');
      final LanComputeScheduler inputScheduler = LanComputeScheduler(
        limits: LanComputeSchedulerLimits(
          maxInputBytes: 3,
          maxOutputBytes: 8,
          maxModelMemoryBytes: 8,
        ),
      );
      expect(
        () => inputScheduler.schedule(
          request: smallRequest,
          estimate: _estimate(smallRequest, memory: 1),
          start: () => _completedTask(smallRequest.taskId),
        ),
        throwsA(
          isA<LanComputeAdmissionException>().having(
            (LanComputeAdmissionException error) => error.reason,
            'reason',
            LanComputeAdmissionReason.inputTooLarge,
          ),
        ),
      );
      final LanComputeTaskRequest memoryRequest = _request('admission-memory');
      final LanComputeScheduler outputScheduler = LanComputeScheduler(
        limits: LanComputeSchedulerLimits(
          maxInputBytes: 8,
          maxOutputBytes: 3,
          maxModelMemoryBytes: 8,
        ),
      );
      expect(
        () => outputScheduler.schedule(
          request: memoryRequest,
          estimate: _estimate(memoryRequest, memory: 1),
          start: () => _completedTask(memoryRequest.taskId),
        ),
        throwsA(
          isA<LanComputeAdmissionException>().having(
            (LanComputeAdmissionException error) => error.reason,
            'reason',
            LanComputeAdmissionReason.outputTooLarge,
          ),
        ),
      );
      final LanComputeScheduler memoryScheduler = LanComputeScheduler(
        limits: LanComputeSchedulerLimits(
          maxInputBytes: 8,
          maxOutputBytes: 8,
          maxModelMemoryBytes: 3,
        ),
      );
      expect(
        () => memoryScheduler.schedule(
          request: memoryRequest,
          estimate: _estimate(memoryRequest, memory: 4),
          start: () => _completedTask(memoryRequest.taskId),
        ),
        throwsA(
          isA<LanComputeAdmissionException>().having(
            (LanComputeAdmissionException error) => error.reason,
            'reason',
            LanComputeAdmissionReason.modelMemoryTooLarge,
          ),
        ),
      );
      await scheduler.close();
    },
  );

  test(
    'synchronous submissions reserve slots before their start microtasks run',
    () async {
      final LanComputeScheduler scheduler = LanComputeScheduler(
        limits: LanComputeSchedulerLimits(
          maxConcurrent: 2,
          maxQueued: 2,
          maxInputBytes: 8,
          maxOutputBytes: 8,
          maxModelMemoryBytes: 100,
        ),
      );
      final List<Completer<void>> releases = List<Completer<void>>.generate(
        4,
        (_) => Completer<void>(),
      );
      final List<String> starts = <String>[];
      int active = 0;
      int maxActive = 0;

      LanComputeScheduledExecution submit(int index) {
        final String id = 'synchronous-$index';
        final LanComputeTaskRequest request = _request(id);
        return scheduler.schedule(
          request: request,
          estimate: _estimate(request, memory: 10),
          start: () {
            starts.add(id);
            active++;
            if (active > maxActive) {
              maxActive = active;
            }
            return EngineTask<LanComputeDataRef>.start(
              id: id,
              operation: (EngineTaskContext context) async {
                try {
                  await releases[index].future;
                  return _output(id);
                } finally {
                  active--;
                }
              },
            );
          },
        );
      }

      final List<LanComputeScheduledExecution> executions =
          <LanComputeScheduledExecution>[
            submit(0),
            submit(1),
            submit(2),
            submit(3),
          ];

      expect(
        executions.map((LanComputeScheduledExecution item) => item.wasQueued),
        <bool>[false, false, true, true],
      );
      expect(scheduler.queuedCount, 2);
      await _settle();
      expect(starts, <String>['synchronous-0', 'synchronous-1']);
      expect(scheduler.runningCount, 2);
      expect(maxActive, 2);

      releases[0].complete();
      await executions[0].future;
      await _waitFor(() => starts.length == 3);
      expect(starts, <String>[
        'synchronous-0',
        'synchronous-1',
        'synchronous-2',
      ]);
      expect(maxActive, 2);

      releases[1].complete();
      await executions[1].future;
      await _waitFor(() => starts.length == 4);
      expect(maxActive, 2);

      releases[2].complete();
      releases[3].complete();
      await Future.wait<LanComputeDataRef>(<Future<LanComputeDataRef>>[
        executions[2].future,
        executions[3].future,
      ]);
      expect(scheduler.runningCount, 0);
      expect(scheduler.activeCount, 0);
      await scheduler.close();
    },
  );

  test('cancelling a reserved start releases its slot immediately', () async {
    final LanComputeScheduler scheduler = LanComputeScheduler(
      limits: LanComputeSchedulerLimits(
        maxConcurrent: 1,
        maxQueued: 0,
        maxInputBytes: 8,
        maxOutputBytes: 8,
        maxModelMemoryBytes: 100,
      ),
    );
    final List<String> starts = <String>[];
    final LanComputeTaskRequest cancelledRequest = _request(
      'reserved-cancelled',
    );
    final LanComputeScheduledExecution cancelled = scheduler.schedule(
      request: cancelledRequest,
      estimate: _estimate(cancelledRequest, memory: 10),
      start: () {
        starts.add(cancelledRequest.taskId);
        return _completedTask(cancelledRequest.taskId);
      },
    );

    cancelled.cancel('cancel-before-start');
    await expectLater(
      cancelled.future,
      throwsA(isA<EngineTaskCancelledException>()),
    );

    final LanComputeTaskRequest replacementRequest = _request(
      'reserved-replacement',
    );
    final LanComputeScheduledExecution replacement = scheduler.schedule(
      request: replacementRequest,
      estimate: _estimate(replacementRequest, memory: 10),
      start: () {
        starts.add(replacementRequest.taskId);
        return _completedTask(replacementRequest.taskId);
      },
    );
    expect(replacement.wasQueued, isFalse);
    await replacement.future;
    expect(starts, <String>['reserved-replacement']);
    expect(scheduler.activeCount, 0);
    expect(scheduler.reservedModelMemoryBytes, 0);
    await scheduler.close();
  });

  test(
    'task cache key is canonical and isolated by every remote dimension',
    () {
      final LanComputeTaskRequest request = _request('cache-task');
      final LanComputeTaskCacheKey first = LanComputeTaskCacheKey.fromRequest(
        request,
      );
      final LanComputeTaskCache cache = LanComputeTaskCache();
      final LanComputeDataRef output = _output('cache-output');

      expect(first.canonicalJson, contains('inputHash'));
      expect(first.canonicalJson, isNot(contains('cookie')));
      expect(first.canonicalJson, isNot(contains('apiKey')));
      expect(first.canonicalJson, isNot(contains('original')));
      expect(first.hash, hasLength(64));
      expect(cache.writeIfAbsent(first, output), isTrue);
      expect(cache.writeIfAbsent(first, output), isFalse);
      expect(cache.read(first), same(output));

      for (final LanComputeTaskRequest variant in <LanComputeTaskRequest>[
        _request('cache-task', capability: LanComputeCapability.ocr),
        _request('cache-task', inputHash: _hash('different-input')),
        _request('cache-task', modelHash: _hash('different-model')),
        _request('cache-task', configHash: _hash('different-config')),
        _request('cache-task', promptHash: _hash('different-prompt')),
        _request(
          'cache-task',
          executor: LanComputeExecutorIdentity(
            deviceId: 'other-device',
            executorId: 'executor',
            platform: LanComputePlatform.macos,
          ),
        ),
      ]) {
        expect(
          LanComputeTaskCacheKey.fromRequest(variant).hash,
          isNot(first.hash),
        );
      }
    },
  );

  test(
    'host admission rechecks permission and emits redacted lifecycle audit',
    () async {
      final _Harness denied = _Harness(authorized: false);
      await denied.advertise();
      final EngineTask<LanComputeDataRef> deniedTask = denied.client
          .requestCompute(
            taskId: 'permission-task',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: denied.now.millisecondsSinceEpoch + 60000,
            commitGate: _gate(1),
          );
      expect(await _errorCode(deniedTask.future), 'notAuthorized');
      expect(
        denied.audit.any(
          (LanComputeAuditEvent event) => event.status == 'unauthorized',
        ),
        isTrue,
      );
      await denied.close();

      final _Harness admission = _Harness(
        schedulerLimits: LanComputeSchedulerLimits(
          maxConcurrent: 1,
          maxQueued: 0,
          maxModelMemoryBytes: 64,
        ),
      );
      await admission.advertise();
      final EngineTask<LanComputeDataRef> first = admission.client
          .requestCompute(
            taskId: 'admission-first',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: admission.now.millisecondsSinceEpoch + 60000,
            commitGate: _gate(1),
          );
      await _waitFor(() => admission.executor.executionCount == 1);
      final EngineTask<LanComputeDataRef> second = admission.client
          .requestCompute(
            taskId: 'admission-second',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: admission.now.millisecondsSinceEpoch + 60000,
            commitGate: _gate(2),
          );
      expect(await _errorCode(second.future), 'resourceExhausted');
      expect(
        admission.audit.any(
          (LanComputeAuditEvent event) => event.status == 'admission_denied',
        ),
        isTrue,
      );
      admission.executor.release('admission-first');
      await first.future;
      expect(
        admission.audit.map((LanComputeAuditEvent event) => event.status),
        containsAll(<String>['authorized', 'queued', 'running', 'progress']),
      );
      await admission.close();
    },
  );

  test(
    'timeout, disconnect and explicit cancel use one fallback and suppress late results',
    () async {
      final _ManualTimerScheduler timer = _ManualTimerScheduler();
      final List<LanComputeCancelReason> fallbackReasons =
          <LanComputeCancelReason>[];
      final List<LanComputeDataRef> committed = <LanComputeDataRef>[];
      final List<LanComputeTerminalResult> remoteCommits =
          <LanComputeTerminalResult>[];
      late LanComputeClientRuntime client;
      client = LanComputeClientRuntime(
        peerSupportsCompute: true,
        timerScheduler: timer,
        cache: LanComputeTaskCache(),
        onCommit: remoteCommits.add,
        onFallbackCommit: (
          LanComputeTaskRequest _,
          LanComputeDataRef output,
          LanComputeCancelReason _,
        ) {
          committed.add(output);
        },
        fallback: (LanComputeTaskRequest _, LanComputeCancelReason reason) {
          fallbackReasons.add(reason);
          return _completedTask('fallback-${reason.wireName}');
        },
        send: (LanComputeMessage message) async {},
      );
      client.handleMessage(_descriptor());
      final EngineTask<LanComputeDataRef> timeoutTask = client.requestCompute(
        taskId: 'timeout-task',
        capability: LanComputeCapability.translation,
        modelHash: _hash('model'),
        configHash: _hash('config'),
        promptHash: _hash('prompt'),
        input: _input,
        deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
        commitGate: _gate(1),
      );
      await _waitFor(() => client.pendingTaskCount == 1);
      timer.fireNext();
      final LanComputeDataRef timeoutOutput = await timeoutTask.future;
      expect(timeoutOutput.hash, _hash('fallback-deadline'));
      expect(fallbackReasons, contains(LanComputeCancelReason.deadline));
      expect(committed, hasLength(1));
      client.handleMessage(_terminalResult('timeout-task', _gate(1)));
      expect(remoteCommits, isEmpty);

      final EngineTask<LanComputeDataRef> disconnectTask = client
          .requestCompute(
            taskId: 'disconnect-task',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _otherInput,
            deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
            commitGate: _gate(2),
          );
      await _waitFor(() => client.pendingTaskCount == 1);
      await client.close();
      await disconnectTask.future;
      expect(fallbackReasons, contains(LanComputeCancelReason.disconnected));
      expect(committed, hasLength(2));
      expect(client.pendingTaskCount, 0);

      final _ManualTimerScheduler cancelTimer = _ManualTimerScheduler();
      final List<LanComputeDataRef> cancelCommits = <LanComputeDataRef>[];
      final LanComputeClientRuntime cancelClient = LanComputeClientRuntime(
        peerSupportsCompute: true,
        timerScheduler: cancelTimer,
        onFallbackCommit: (
          LanComputeTaskRequest _,
          LanComputeDataRef output,
          LanComputeCancelReason _,
        ) {
          cancelCommits.add(output);
        },
        fallback:
            (LanComputeTaskRequest _, LanComputeCancelReason reason) =>
                _completedTask('explicit-cancel'),
        send: (LanComputeMessage message) async {},
      );
      cancelClient.handleMessage(_descriptor());
      final EngineTask<LanComputeDataRef> cancelTask = cancelClient
          .requestCompute(
            taskId: 'cancel-task',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
            commitGate: _gate(3),
          );
      await _waitFor(() => cancelClient.pendingTaskCount == 1);
      cancelTask.cancel('user');
      expect(await _errorCode(cancelTask.future), 'cancelled');
      expect(cancelCommits, hasLength(1));
      await cancelClient.close();
    },
  );

  test(
    'fallback commit gate rejects a stale local result and default fallback is explicit unavailable',
    () async {
      final _ManualTimerScheduler timer = _ManualTimerScheduler();
      final LanComputeClientRuntime staleClient = LanComputeClientRuntime(
        peerSupportsCompute: true,
        timerScheduler: timer,
        isCommitGateCurrent: (_) => false,
        fallback:
            (LanComputeTaskRequest _, LanComputeCancelReason _) =>
                _completedTask('stale-fallback'),
        send: (LanComputeMessage message) async {},
      );
      staleClient.handleMessage(_descriptor());
      final EngineTask<LanComputeDataRef> staleTask = staleClient
          .requestCompute(
            taskId: 'stale-fallback-task',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
            commitGate: _gate(4),
          );
      await _waitFor(() => staleClient.pendingTaskCount == 1);
      await staleClient.close();
      expect(await _errorCode(staleTask.future), 'staleGeneration');

      final _ManualTimerScheduler unavailableTimer = _ManualTimerScheduler();
      final LanComputeClientRuntime unavailableClient = LanComputeClientRuntime(
        peerSupportsCompute: true,
        timerScheduler: unavailableTimer,
        send: (LanComputeMessage message) async {},
      );
      unavailableClient.handleMessage(_descriptor());
      final EngineTask<LanComputeDataRef> unavailableTask = unavailableClient
          .requestCompute(
            taskId: 'unavailable-fallback-task',
            capability: LanComputeCapability.translation,
            modelHash: _hash('model'),
            configHash: _hash('config'),
            promptHash: _hash('prompt'),
            input: _input,
            deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
            commitGate: _gate(5),
          );
      await _waitFor(() => unavailableClient.pendingTaskCount == 1);
      await unavailableClient.close();
      expect(await _errorCode(unavailableTask.future), 'fallbackUnavailable');
    },
  );

  test(
    'host cancellation is deferred past synchronous EngineTask cancel dispatch',
    () async {
      final _Harness harness = _Harness(
        fallback:
            (LanComputeTaskRequest _, LanComputeCancelReason _) =>
                _completedTask('cancel-fallback'),
      );
      await harness.advertise();
      final EngineTask<LanComputeDataRef> task = harness.client.requestCompute(
        taskId: 'reentrant-cancel',
        capability: LanComputeCapability.translation,
        modelHash: _hash('model'),
        configHash: _hash('config'),
        promptHash: _hash('prompt'),
        input: _input,
        deadlineEpochMs: harness.now.millisecondsSinceEpoch + 60000,
        commitGate: _gate(6),
      );
      await _waitFor(() => harness.executor.executionCount == 1);
      task.cancel('user');
      expect(await _errorCode(task.future), 'cancelled');
      await _waitFor(() => harness.host.activeTaskCount == 0);
      expect(harness.cancelMessages, hasLength(1));
      expect(
        harness.audit.map((LanComputeAuditEvent event) => event.status),
        contains('cancelled'),
      );
      await harness.close();
    },
  );
}

final LanComputeDataRef _input = LanComputeDataRef(
  kind: LanComputeArtifactKind.image,
  hash: _hash('input'),
  sizeBytes: 4,
);

final LanComputeDataRef _otherInput = LanComputeDataRef(
  kind: LanComputeArtifactKind.image,
  hash: _hash('other-input'),
  sizeBytes: 4,
);

LanComputeTaskRequest _request(
  String taskId, {
  LanComputeCapability capability = LanComputeCapability.translation,
  String? inputHash,
  String? modelHash,
  String? configHash,
  String? promptHash,
  LanComputeExecutorIdentity? executor,
}) => LanComputeTaskRequest(
  taskId: taskId,
  capability: capability,
  modelHash: modelHash ?? _hash('model'),
  configHash: configHash ?? _hash('config'),
  promptHash: promptHash ?? _hash('prompt'),
  input: LanComputeDataRef(
    kind: LanComputeArtifactKind.image,
    hash: inputHash ?? _input.hash,
    sizeBytes: _input.sizeBytes,
  ),
  deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
  executor: executor ?? _executor(),
  commitGate: _gate(1),
  schemaHash: LanComputeProtocol.schemaHash,
);

LanComputeResourceEstimate _estimate(
  LanComputeTaskRequest request, {
  required int memory,
}) => LanComputeResourceEstimate(
  inputBytes: request.input.sizeBytes,
  outputBytes: 4,
  modelMemoryBytes: memory,
);

EngineTask<LanComputeDataRef> _heldTask(String id, Completer<void> release) =>
    EngineTask<LanComputeDataRef>.start(
      id: id,
      operation: (EngineTaskContext context) async {
        context.report(EngineTaskStage.processing, .25);
        await Future.any<void>(<Future<void>>[
          release.future,
          context.cancellation.onCancel.first.then((_) {}),
        ]);
        context.cancellation.throwIfCancelled();
        return _output('scheduler-output');
      },
    );

EngineTask<LanComputeDataRef> _completedTask(String id) =>
    EngineTask<LanComputeDataRef>.start(
      id: id,
      operation: (EngineTaskContext context) async {
        context.report(EngineTaskStage.processing, .5);
        return _output(id);
      },
    );

LanComputeDataRef _output(String seed) => LanComputeDataRef(
  kind: LanComputeArtifactKind.text,
  hash: _hash(seed),
  sizeBytes: 4,
);

LanComputeExecutorIdentity _executor() => LanComputeExecutorIdentity(
  deviceId: 'host-device',
  executorId: 'host-executor',
  platform: LanComputePlatform.macos,
);

LanComputeCommitGate _gate(int generation) => LanComputeCommitGate(
  targetId: 'page-1',
  generation: generation,
  gateId: 'gate-$generation',
);

LanComputeCapabilityDescriptor _descriptor() => LanComputeCapabilityDescriptor(
  ready: true,
  capability: LanComputeCapability.translation,
  reason: LanComputeReadinessReason.ready,
  executor: _executor(),
  modelHash: _hash('model'),
  configHash: _hash('config'),
  schemaHash: LanComputeProtocol.schemaHash,
);

LanComputeTerminalResult _terminalResult(
  String taskId,
  LanComputeCommitGate gate,
) => LanComputeTerminalResult(
  taskId: taskId,
  capability: LanComputeCapability.translation,
  output: _output('late-output'),
  completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
  executor: _executor(),
  commitGate: gate,
  schemaHash: LanComputeProtocol.schemaHash,
);

Future<String> _errorCode(Future<LanComputeDataRef> future) async {
  try {
    await future;
    fail('expected compute task error');
  } on EngineException catch (error) {
    return error.code;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<void> _waitFor(bool Function() condition) async {
  for (int index = 0; index < 100; index++) {
    if (condition()) {
      return;
    }
    await _settle();
  }
  fail('condition did not become true');
}

class _ManualTimerScheduler implements LanComputeTimerScheduler {
  final List<_ManualTimer> _timers = <_ManualTimer>[];

  @override
  LanComputeScheduledTask schedule(Duration delay, void Function() callback) {
    final _ManualTimer timer = _ManualTimer(callback);
    _timers.add(timer);
    return timer;
  }

  void fireNext() {
    _timers.firstWhere((_ManualTimer timer) => !timer.cancelled).fire();
  }
}

class _ManualTimer implements LanComputeScheduledTask {
  final void Function() callback;
  bool cancelled = false;

  _ManualTimer(this.callback);

  @override
  void cancel() => cancelled = true;

  void fire() {
    if (!cancelled) {
      callback();
    }
  }
}

class _Harness {
  final DateTime now = DateTime.now();
  final _ManualTimerScheduler hostTimer = _ManualTimerScheduler();
  final _ManualTimerScheduler clientTimer = _ManualTimerScheduler();
  final List<LanComputeAuditEvent> audit = <LanComputeAuditEvent>[];
  final List<LanComputeCancel> cancelMessages = <LanComputeCancel>[];
  final _FakeExecutor executor;
  late final LanComputeHostRuntime host;
  late final LanComputeClientRuntime client;

  _Harness({
    bool authorized = true,
    LanComputeSchedulerLimits? schedulerLimits,
    LanComputeFallbackHandler? fallback,
  }) : executor = _FakeExecutor() {
    host = LanComputeHostRuntime(
      executorIdentity: _executor(),
      remoteDeviceId: 'remote-device',
      isAuthorized: (_) => authorized,
      executors: <LanComputeExecutor>[executor],
      timerScheduler: hostTimer,
      scheduler: LanComputeScheduler(
        limits: schedulerLimits ?? LanComputeSchedulerLimits(),
      ),
      clock: () => now,
      onAudit: audit.add,
    );
    client = LanComputeClientRuntime(
      peerSupportsCompute: true,
      timerScheduler: clientTimer,
      fallback: fallback,
      send: (LanComputeMessage message) async {
        if (message is LanComputeCancel) {
          cancelMessages.add(message);
        }
        await host.handleMessage(message, (LanComputeMessage response) async {
          client.handleMessage(response);
        });
      },
      clock: () => now,
      onAudit: audit.add,
    );
  }

  Future<void> advertise() async {
    await host.advertise((LanComputeMessage message) async {
      client.handleMessage(message);
    });
  }

  Future<void> close() async {
    await client.close();
    await host.close();
  }
}

class _FakeExecutor implements LanComputeExecutor {
  @override
  final LanComputeCapabilityDescriptor descriptor = _descriptor();
  @override
  final String? expectedPromptHash = _hash('prompt');
  final Map<String, Completer<void>> _releases = <String, Completer<void>>{};
  int executionCount = 0;

  @override
  bool acceptsInput(LanComputeDataRef input) => input.hash == _input.hash;

  @override
  LanComputeResourceEstimate resourceEstimateFor(
    LanComputeTaskRequest request,
  ) => _estimate(request, memory: 32);

  @override
  EngineTask<LanComputeDataRef> execute(LanComputeTaskRequest request) {
    executionCount++;
    final Completer<void> release = Completer<void>();
    _releases[request.taskId] = release;
    return EngineTask<LanComputeDataRef>.start(
      id: request.taskId,
      operation: (EngineTaskContext context) async {
        context.report(EngineTaskStage.processing, .4);
        await Future.any<void>(<Future<void>>[
          release.future,
          context.cancellation.onCancel.first.then((_) {}),
        ]);
        context.cancellation.throwIfCancelled();
        context.report(EngineTaskStage.finalizing, .9);
        return _output('host-output');
      },
    );
  }

  void release(String taskId) => _releases[taskId]?.complete();
}

String _hash(String seed) => sha256.convert(utf8.encode(seed)).toString();
