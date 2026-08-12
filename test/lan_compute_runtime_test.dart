import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/lan_compute_protocol.dart';
import 'package:jhentai/src/service/lan_compute_runtime.dart';
import 'package:jhentai/src/service/lan_compute_scheduler.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_sharing_runtime.dart';
import 'package:jhentai/src/service/lan_trust_repository.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';

void main() {
  setUpAll(() {
    log.logDirPath = '${Directory.systemTemp.path}/jhentai-lan-test-logs';
  });

  test('authenticated v2 session advertises and runs fake compute', () async {
    advancedSetting.enableLanSharing.value = true;
    advancedSetting.lanActAsServer.value = true;
    final LanDeviceTrustService clientTrust = LanDeviceTrustService(
      repository: _MemoryTrustRepository(),
      secureRandom: Random(501),
      registerWithGet: false,
    );
    final LanDeviceTrustService hostTrust = LanDeviceTrustService(
      repository: _MemoryTrustRepository(),
      secureRandom: Random(502),
      registerWithGet: false,
    );
    await clientTrust.doInitBean();
    await hostTrust.doInitBean();
    final LanComputeExecutorIdentity hostIdentity = LanComputeExecutorIdentity(
      deviceId: hostTrust.localDeviceId,
      executorId: 'lan-compute-runtime',
      platform: _currentComputePlatform(),
    );
    final _FakeExecutor hostExecutor = _FakeExecutor(
      descriptor: _readyDescriptor(
        capability: LanComputeCapability.translation,
        executor: hostIdentity,
      ),
      expectedInputHash: _hash('i'),
      hold: false,
    );
    final LanSharingRuntime clientRuntime = LanSharingRuntime(
      trustService: clientTrust,
      useServiceDiscovery: false,
      bindAddress: InternetAddress.loopbackIPv4,
      secureRandom: Random(503),
    );
    final LanSharingRuntime hostRuntime = LanSharingRuntime(
      trustService: hostTrust,
      useServiceDiscovery: false,
      bindAddress: InternetAddress.loopbackIPv4,
      secureRandom: Random(504),
      computeExecutors: [hostExecutor],
    );
    try {
      await clientRuntime.doInitBean();
      await hostRuntime.doInitBean();
      final LanDiscoveredPeer peer = _peerFor(
        hostTrust,
        hostRuntime.serverPort!,
      );
      await clientTrust.handlePeerDiscovered(peer);
      final Future<LanPairingAcceptance> pairing = clientTrust
          .trustDiscoveredDevice(
            deviceId: hostTrust.localDeviceId,
            permissions: const <LanSharePermission>{},
          );
      await _waitUntil(() => hostTrust.incomingPairingRequests.isNotEmpty);
      await hostTrust.acceptIncomingPairing(
        deviceId: clientTrust.localDeviceId,
        permissions: const <LanSharePermission>{
          LanSharePermission.translationCompute,
        },
      );
      await pairing;
      await _waitUntil(
        () =>
            clientTrust.connectionFor(hostTrust.localDeviceId).state ==
            LanPeerConnectionState.connected,
      );
      final LanComputeSession session =
          clientTrust.computeSession(hostTrust.localDeviceId)!;
      await _waitUntil(
        () =>
            session
                .computeDescriptor(LanComputeCapability.translation)
                ?.ready ==
            true,
      );
      final EngineTask<LanComputeDataRef> task = session.requestCompute(
        taskId: 'authenticated-task-1',
        capability: LanComputeCapability.translation,
        modelHash: _hash('m'),
        configHash: _hash('c'),
        input: LanComputeDataRef(
          kind: LanComputeArtifactKind.image,
          hash: _hash('i'),
          sizeBytes: 16,
        ),
        deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 10000,
        commitGate: LanComputeCommitGate(
          targetId: 'page-1',
          generation: 1,
          gateId: 'gate-1',
        ),
      );
      final LanComputeDataRef output = await task.future;
      expect(output.hash, _hash('o'));
      expect(hostExecutor.executionCount, 1);
      expect(task.lifecycle, EngineTaskLifecycle.succeeded);
    } finally {
      await clientRuntime.stop();
      await hostRuntime.stop();
      clientTrust.onClose();
      hostTrust.onClose();
      advancedSetting.enableLanSharing.value = false;
      advancedSetting.lanActAsServer.value = false;
    }
  });

  test('host rechecks permission and all request hashes at runtime', () async {
    final _Harness denied = _Harness(authorized: false);
    await denied.advertise();
    final List<LanComputeMessage> deniedMessages = <LanComputeMessage>[];
    await denied.host.handleMessage(
      denied.request,
      (LanComputeMessage message) async => deniedMessages.add(message),
    );
    expect(deniedMessages.single, isA<LanComputeTerminalError>());
    expect(
      (deniedMessages.single as LanComputeTerminalError).code,
      LanComputeErrorCode.notAuthorized,
    );
    expect(denied.executor.executionCount, 0);

    final _Harness hashMismatch = _Harness();
    await hashMismatch.advertise();
    final List<LanComputeMessage> hashMessages = <LanComputeMessage>[];
    await hashMismatch.host.handleMessage(
      hashMismatch.requestWith(modelHash: _hash('wrong')),
      (LanComputeMessage message) async => hashMessages.add(message),
    );
    expect(
      (hashMessages.single as LanComputeTerminalError).code,
      LanComputeErrorCode.hashMismatch,
    );
    expect(hashMismatch.executor.executionCount, 0);
    await denied.close();
    await hashMismatch.close();
  });

  test('stale generation and duplicate task results never commit', () async {
    final List<LanComputeTerminalResult> committed =
        <LanComputeTerminalResult>[];
    final _ManualScheduler scheduler = _ManualScheduler();
    final LanComputeExecutorIdentity identity = _identity('client');
    final LanComputeClientRuntime client = LanComputeClientRuntime(
      peerSupportsCompute: true,
      send: (_) async {},
      timerScheduler: scheduler,
      onCommit: committed.add,
    );
    client.handleMessage(
      _readyDescriptor(
        capability: LanComputeCapability.translation,
        executor: identity,
      ),
    );
    final LanComputeCommitGate currentGate = LanComputeCommitGate(
      targetId: 'page-1',
      generation: 2,
      gateId: 'gate-2',
    );
    final EngineTask<LanComputeDataRef> task = client.requestCompute(
      taskId: 'stale-task',
      capability: LanComputeCapability.translation,
      modelHash: _hash('m'),
      configHash: _hash('c'),
      input: _input,
      deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
      commitGate: currentGate,
    );
    await _waitUntil(() => scheduler.pendingCount == 1);
    client.handleMessage(
      _result(
        identity: identity,
        gate: LanComputeCommitGate(
          targetId: 'page-1',
          generation: 1,
          gateId: 'gate-1',
        ),
        taskId: 'stale-task',
      ),
    );
    expect(committed, isEmpty);
    expect(task.lifecycle, isNot(EngineTaskLifecycle.succeeded));
    client.handleMessage(
      _result(identity: identity, gate: currentGate, taskId: 'stale-task'),
    );
    await task.future;
    expect(committed, hasLength(1));

    final _Harness duplicate = _Harness();
    await duplicate.advertise();
    final EngineTask<LanComputeDataRef> first = duplicate.client.requestCompute(
      taskId: 'duplicate-task',
      capability: LanComputeCapability.translation,
      modelHash: _hash('m'),
      configHash: _hash('c'),
      promptHash: _hash('p'),
      input: duplicate.input,
      deadlineEpochMs: duplicate.clock().millisecondsSinceEpoch + 60000,
      commitGate: duplicate.gate,
    );
    await _waitUntil(() => duplicate.executor.executionCount == 1);
    final EngineTask<LanComputeDataRef> second = duplicate.client
        .requestCompute(
          taskId: 'duplicate-task',
          capability: LanComputeCapability.translation,
          modelHash: _hash('m'),
          configHash: _hash('c'),
          promptHash: _hash('p'),
          input: duplicate.input,
          deadlineEpochMs: duplicate.clock().millisecondsSinceEpoch + 60000,
          commitGate: duplicate.gate,
        );
    final EngineException duplicateError = await _expectEngineError(
      second.future,
    );
    expect(duplicateError.code, 'invalidRequest');
    duplicate.executor.release('duplicate-task');
    await first.future;
    await duplicate.close();
    await client.close();
  });

  test('audit events contain only redacted identifiers and hash prefixes', () {
    final List<LanComputeAuditEvent> events = <LanComputeAuditEvent>[];
    final LanComputeAuditEvent event = LanComputeAuditEvent(
      taskId: 'task-with-sensitive-suffix',
      deviceId: 'device-with-sensitive-suffix',
      capability: 'translationComputeV1',
      status: 'terminal_result',
      hash: _hash('a'),
      errorCode: LanComputeErrorCode.failed.wireName,
    );
    events.add(event);
    final String encoded = event.toJson().toString();
    expect(encoded, isNot(contains('task-with-sensitive-suffix')));
    expect(encoded, isNot(contains('device-with-sensitive-suffix')));
    expect(event.hashPrefix, hasLength(12));
    expect(events.single.toJson().keys, isNot(contains('input')));
    expect(events.single.toJson().keys, isNot(contains('text')));
  });
}

final LanComputeDataRef _input = LanComputeDataRef(
  kind: LanComputeArtifactKind.image,
  hash: _hash('i'),
  sizeBytes: 16,
);

class _Harness {
  final DateTime _now = DateTime.now();
  final _ManualScheduler clientScheduler = _ManualScheduler();
  final _ManualScheduler hostScheduler = _ManualScheduler();
  late final _FakeExecutor executor;
  late final LanComputeHostRuntime host;
  late final LanComputeClientRuntime client;
  final List<LanComputeCancel> cancelMessages = <LanComputeCancel>[];
  final bool authorized;

  _Harness({this.authorized = true}) {
    final LanComputeExecutorIdentity identity = _identity('host');
    executor = _FakeExecutor(
      descriptor: _readyDescriptor(
        capability: LanComputeCapability.translation,
        executor: identity,
      ),
      expectedPromptHash: _hash('p'),
      expectedInputHash: _hash('i'),
      hold: true,
    );
    host = LanComputeHostRuntime(
      executorIdentity: identity,
      remoteDeviceId: 'remote-device',
      isAuthorized: (_) => authorized,
      executors: <LanComputeExecutor>[executor],
      timerScheduler: hostScheduler,
      clock: () => _now,
    );
    client = LanComputeClientRuntime(
      peerSupportsCompute: true,
      send: (LanComputeMessage message) async {
        if (message is LanComputeCancel) {
          cancelMessages.add(message);
        }
        await host.handleMessage(message, (LanComputeMessage response) async {
          client.handleMessage(response);
        });
      },
      timerScheduler: clientScheduler,
      clock: () => _now,
    );
  }

  Future<void> advertise() async {
    await host.advertise((LanComputeMessage message) async {
      client.handleMessage(message);
    });
  }

  LanComputeTaskRequest get request => requestWith();

  LanComputeTaskRequest requestWith({String? modelHash}) =>
      LanComputeTaskRequest(
        taskId: 'permission-task',
        capability: LanComputeCapability.translation,
        modelHash: modelHash ?? _hash('m'),
        configHash: _hash('c'),
        promptHash: _hash('p'),
        input: input,
        deadlineEpochMs: _now.millisecondsSinceEpoch + 60000,
        executor: _identity('host'),
        commitGate: gate,
        schemaHash: LanComputeProtocol.schemaHash,
      );

  LanComputeDataRef get input => _input;

  LanComputeCommitGate get gate =>
      LanComputeCommitGate(targetId: 'page-1', generation: 1, gateId: 'gate-1');

  DateTime Function() get clock => () => _now;

  Future<void> close() async {
    await client.close();
    await host.close();
  }
}

class _FakeExecutor implements LanComputeExecutor {
  @override
  final LanComputeCapabilityDescriptor descriptor;
  @override
  final String? expectedPromptHash;
  final String expectedInputHash;
  final bool hold;
  final List<EngineTaskContext> contexts = <EngineTaskContext>[];
  final Map<String, Completer<void>> _releases = <String, Completer<void>>{};
  int executionCount = 0;

  _FakeExecutor({
    required this.descriptor,
    this.expectedPromptHash,
    required this.expectedInputHash,
    this.hold = true,
  });

  @override
  bool acceptsInput(LanComputeDataRef input) => input.hash == expectedInputHash;

  @override
  LanComputeResourceEstimate resourceEstimateFor(
    LanComputeTaskRequest request,
  ) => LanComputeResourceEstimate(
    inputBytes: request.input.sizeBytes,
    outputBytes: 4,
    modelMemoryBytes: 64,
  );

  @override
  EngineTask<LanComputeDataRef> execute(LanComputeTaskRequest request) {
    executionCount++;
    final Completer<void> release = Completer<void>();
    _releases[request.taskId] = release;
    return EngineTask<LanComputeDataRef>.start(
      id: request.taskId,
      operation: (EngineTaskContext context) async {
        contexts.add(context);
        context.report(EngineTaskStage.processing, .4);
        if (hold) {
          await Future.any<void>(<Future<void>>[
            release.future,
            context.cancellation.onCancel.first.then((_) {}),
          ]);
        }
        context.cancellation.throwIfCancelled();
        context.report(EngineTaskStage.finalizing, .9);
        return LanComputeDataRef(
          kind: LanComputeArtifactKind.text,
          hash: _hash('o'),
          sizeBytes: 4,
        );
      },
    );
  }

  void release(String taskId) => _releases[taskId]?.complete();
}

class _ManualScheduler implements LanComputeTimerScheduler {
  final List<_ManualTask> _tasks = <_ManualTask>[];

  int get pendingCount => _tasks.where((task) => !task.cancelled).length;

  @override
  LanComputeScheduledTask schedule(Duration delay, void Function() callback) {
    final _ManualTask task = _ManualTask(callback);
    _tasks.add(task);
    return task;
  }

  void fireNext() {
    final _ManualTask task = _tasks.firstWhere((item) => !item.cancelled);
    task.fire();
  }
}

class _ManualTask implements LanComputeScheduledTask {
  final void Function() callback;
  bool cancelled = false;

  _ManualTask(this.callback);

  @override
  void cancel() => cancelled = true;

  void fire() {
    if (!cancelled) {
      callback();
    }
  }
}

LanComputeCapabilityDescriptor _readyDescriptor({
  required LanComputeCapability capability,
  required LanComputeExecutorIdentity executor,
}) => LanComputeCapabilityDescriptor(
  ready: true,
  capability: capability,
  reason: LanComputeReadinessReason.ready,
  executor: executor,
  modelHash: _hash('m'),
  configHash: _hash('c'),
  schemaHash: LanComputeProtocol.schemaHash,
);

LanComputeExecutorIdentity _identity(String deviceId) =>
    LanComputeExecutorIdentity(
      deviceId: deviceId,
      executorId: 'lan-compute-runtime',
      platform: LanComputePlatform.macos,
    );

LanComputeTerminalResult _result({
  required LanComputeExecutorIdentity identity,
  required LanComputeCommitGate gate,
  required String taskId,
}) => LanComputeTerminalResult(
  taskId: taskId,
  capability: LanComputeCapability.translation,
  output: LanComputeDataRef(
    kind: LanComputeArtifactKind.text,
    hash: _hash('o'),
    sizeBytes: 4,
  ),
  completedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
  executor: identity,
  commitGate: gate,
  schemaHash: LanComputeProtocol.schemaHash,
);

Future<EngineException> _expectEngineError(Future<Object?> future) async {
  try {
    await future;
    fail('expected EngineException');
  } on EngineException catch (error) {
    return error;
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition was not met');
    }
    await Future<void>.delayed(Duration.zero);
  }
}

LanDiscoveredPeer _peerFor(LanDeviceTrustService service, int port) =>
    LanDiscoveredPeer(
      deviceId: service.localDeviceId,
      displayName: service.localDisplayName,
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      identityPublicKey: service.localIdentityPublicKey,
      identityFingerprint: service.localIdentityFingerprint,
    );

LanComputePlatform _currentComputePlatform() => switch (Platform
    .operatingSystem) {
  'ios' => LanComputePlatform.ios,
  'android' => LanComputePlatform.android,
  'macos' => LanComputePlatform.macos,
  'windows' => LanComputePlatform.windows,
  'linux' => LanComputePlatform.linux,
  _ => LanComputePlatform.unknown,
};

String _hash(String value) {
  final String character =
      <String, String>{
        'm': 'a',
        'c': 'b',
        'p': 'c',
        'i': 'd',
        'o': 'e',
        'wrong': 'f',
      }[value] ??
      'f';
  return List<String>.filled(64, character).join();
}

class _MemoryTrustRepository implements LanTrustRepository {
  String? localDeviceId;
  String? localIdentitySeed;
  String? localDeviceName;
  final Map<String, TrustedLanDevice> devices = <String, TrustedLanDevice>{};
  final Map<String, LanDeviceCredentials> credentials =
      <String, LanDeviceCredentials>{};

  @override
  Future<LanDeviceCredentials?> credentialsFor(String deviceId) async =>
      credentials[deviceId];

  @override
  Future<String> ensureLocalDeviceId(String Function() generator) async =>
      localDeviceId ??= generator();

  @override
  Future<String?> readLocalDeviceName() async => localDeviceName;

  @override
  Future<void> saveLocalDeviceName(String name) async {
    localDeviceName = name;
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<TrustedLanDevice>> loadDevices() async => devices.values.toList();

  @override
  Future<String?> readLocalIdentitySeed() async => localIdentitySeed;

  @override
  Future<void> revokeDevice(String deviceId) async {
    devices.remove(deviceId);
    credentials.remove(deviceId);
  }

  @override
  Future<void> saveDevice(
    TrustedLanDevice device, {
    required String remoteAccessToken,
    required String inboundAccessToken,
  }) async {
    devices[device.deviceId] = device;
    credentials[device.deviceId] = LanDeviceCredentials(
      remoteAccessToken: remoteAccessToken,
      inboundAccessToken: inboundAccessToken,
    );
  }

  @override
  Future<void> saveLocalIdentitySeed(String seed) async {
    localIdentitySeed = seed;
  }

  @override
  Future<void> updateDevice(TrustedLanDevice device) async {
    devices[device.deviceId] = device;
  }
}
