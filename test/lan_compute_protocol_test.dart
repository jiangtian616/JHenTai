import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/lan_compute_protocol.dart';

void main() {
  final String modelHash = _hash('a');
  final String configHash = _hash('b');
  final String promptHash = _hash('c');
  final String inputHash = _hash('d');
  final String outputHash = _hash('e');
  final LanComputeExecutorIdentity executor = LanComputeExecutorIdentity(
    deviceId: 'device-1',
    executorId: 'executor-1',
    platform: LanComputePlatform.macos,
  );
  final LanComputeCommitGate gate = LanComputeCommitGate(
    targetId: 'page-1',
    generation: 7,
    gateId: 'gate-7',
  );

  LanComputeTaskRequest request() => LanComputeTaskRequest(
    taskId: 'task-1',
    capability: LanComputeCapability.translation,
    modelHash: modelHash,
    configHash: configHash,
    promptHash: promptHash,
    input: LanComputeDataRef(
      kind: LanComputeArtifactKind.image,
      hash: inputHash,
      sizeBytes: 1024,
    ),
    deadlineEpochMs: 1786400000000,
    executor: executor,
    commitGate: gate,
    schemaHash: LanComputeProtocol.schemaHash,
  );

  test('canonical JSON sorts nested keys and has a deterministic hash', () {
    final String first = LanComputeProtocol.canonicalJson(<String, dynamic>{
      'z': <String, dynamic>{'b': 2, 'a': 1},
      'a': 3,
    });
    final String second = LanComputeProtocol.canonicalJson(<String, dynamic>{
      'a': 3,
      'z': <String, dynamic>{'a': 1, 'b': 2},
    });

    expect(first, '{"a":3,"z":{"a":1,"b":2}}');
    expect(first, second);
    expect(
      LanComputeProtocol.hashCanonical(<String, dynamic>{'b': 2, 'a': 1}),
      LanComputeProtocol.hashCanonical(<String, dynamic>{'a': 1, 'b': 2}),
    );
    expect(LanComputeProtocol.schemaHash, hasLength(64));
  });

  test('capability descriptors are explicit and default-safe', () {
    final LanComputeCapabilityDescriptor unavailable =
        LanComputeCapabilityDescriptor(
          ready: false,
          capability: LanComputeCapability.ocr,
          reason: LanComputeReadinessReason.modelMissing,
          executor: executor,
          schemaHash: LanComputeProtocol.schemaHash,
        );
    final LanComputeCapabilityDescriptor decoded =
        LanComputeCapabilityDescriptor.fromJson(unavailable.toJson());

    expect(decoded.ready, isFalse);
    expect(decoded.reason, LanComputeReadinessReason.modelMissing);
    expect(decoded.modelHash, isNull);
    expect(decoded.toJson(), unavailable.toJson());
    expect(
      () => LanComputeCapabilityDescriptor(
        ready: true,
        capability: LanComputeCapability.ocr,
        reason: LanComputeReadinessReason.ready,
        executor: executor,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
      throwsA(isA<LanComputeProtocolException>()),
    );
  });

  test('task lifecycle messages round-trip through the strict parser', () {
    final List<LanComputeMessage> messages = <LanComputeMessage>[
      request(),
      LanComputeProgress(
        taskId: 'task-1',
        capability: LanComputeCapability.translation,
        stage: LanComputeProgressStage.running,
        progress: .5,
        observedAtEpochMs: 1786400000100,
        executor: executor,
        commitGate: gate,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
      LanComputeCancel(
        taskId: 'task-1',
        capability: LanComputeCapability.translation,
        reason: LanComputeCancelReason.user,
        requestedAtEpochMs: 1786400000200,
        executor: executor,
        commitGate: gate,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
      LanComputeTerminalResult(
        taskId: 'task-1',
        capability: LanComputeCapability.translation,
        output: LanComputeDataRef(
          kind: LanComputeArtifactKind.overlay,
          hash: outputHash,
          sizeBytes: 2048,
        ),
        completedAtEpochMs: 1786400000300,
        executor: executor,
        commitGate: gate,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
      LanComputeTerminalError(
        taskId: 'task-1',
        capability: LanComputeCapability.translation,
        code: LanComputeErrorCode.cancelled,
        retryable: true,
        completedAtEpochMs: 1786400000300,
        executor: executor,
        commitGate: gate,
        schemaHash: LanComputeProtocol.schemaHash,
      ),
    ];

    for (final LanComputeMessage message in messages) {
      final LanComputeMessage decoded = LanComputeProtocol.fromJson(
        message.toJson(),
      );
      expect(decoded.type, message.type);
      expect(decoded.toJson(), message.toJson());
      expect(decoded.canonicalJson, message.canonicalJson);
    }
  });

  test(
    'unsupported schema and capability are explicit without changing v2',
    () {
      expect(
        LanComputeProtocol.negotiateSupport(
          peerVersion: 0,
          peerCapabilities: const <String>[],
          capability: LanComputeCapability.ocr,
        ).status,
        LanComputeSupportStatus.unsupportedSchema,
      );
      expect(
        LanComputeProtocol.negotiateSupport(
          peerVersion: LanComputeProtocol.version,
          peerCapabilities: const <String>['translationComputeV1'],
          capability: LanComputeCapability.ocr,
        ).status,
        LanComputeSupportStatus.unsupportedCapability,
      );

      final LanComputeUnsupported unsupported = LanComputeUnsupported(
        capability: 'ocrComputeV1',
        reason: LanComputeUnsupportedReason.unsupportedCapability,
        taskId: 'task-1',
        schemaHash: LanComputeProtocol.schemaHash,
      );
      expect(
        LanComputeProtocol.fromJson(unsupported.toJson()).toJson(),
        unsupported.toJson(),
      );
    },
  );

  test('stale generation can be rejected using the commit gate fields', () {
    final LanComputeCommitGate stale = LanComputeCommitGate(
      targetId: 'page-1',
      generation: 6,
      gateId: 'gate-6',
    );
    expect(
      LanComputeProtocol.acceptsCommit(expected: gate, actual: gate),
      isTrue,
    );
    expect(
      LanComputeProtocol.acceptsCommit(expected: gate, actual: stale),
      isFalse,
    );
    expect(request().toJson()['commitGate'], containsPair('generation', 7));
  });

  test(
    'strict parsing rejects unknown, missing, secret, oversized and bad fields',
    () {
      final Map<String, dynamic> unknown =
          request().toJson()..['unknown'] = true;
      expect(
        () => LanComputeTaskRequest.fromJson(unknown),
        throwsA(isA<LanComputeProtocolException>()),
      );

      final Map<String, dynamic> secret =
          request().toJson()..['apiKey'] = 'redacted-test-value';
      expect(
        () => LanComputeTaskRequest.fromJson(secret),
        throwsA(isA<LanComputeProtocolException>()),
      );

      final Map<String, dynamic> missing = request().toJson()..remove('taskId');
      expect(
        () => LanComputeTaskRequest.fromJson(missing),
        throwsA(isA<LanComputeProtocolException>()),
      );

      final Map<String, dynamic> longId =
          request().toJson()..['taskId'] = List<String>.filled(129, 'x').join();
      expect(
        () => LanComputeTaskRequest.fromJson(longId),
        throwsA(isA<LanComputeProtocolException>()),
      );

      final Map<String, dynamic> badHash =
          request().toJson()..['modelHash'] = 'not-a-sha256';
      expect(
        () => LanComputeTaskRequest.fromJson(badHash),
        throwsA(isA<LanComputeProtocolException>()),
      );

      final Map<String, dynamic> oversized = request().toJson();
      (oversized['input'] as Map<String, dynamic>)['sizeBytes'] =
          LanComputeProtocol.maxArtifactBytes + 1;
      expect(
        () => LanComputeTaskRequest.fromJson(oversized),
        throwsA(isA<LanComputeProtocolException>()),
      );
    },
  );
}

String _hash(String character) => List<String>.filled(64, character).join();
