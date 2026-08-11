import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'lan_protocol_v2.dart';

/// Additive LAN compute contract. This file deliberately does not register
/// these messages with [LanProtocolV2] or with any runtime handler.
class LanComputeProtocol {
  static const String schema = 'lanCompute';
  static const int version = 1;
  static const int maxMessageBytes = 64 * 1024;
  static const int maxArtifactBytes = 64 * 1024 * 1024;
  static const int maxIdentifierLength = 128;
  static const int maxSafeInteger = 9007199254740991;

  static const Map<String, Object> _schemaDefinition = <String, Object>{
    'schema': schema,
    'version': version,
    'messages': <String>[
      'capabilityDescriptor',
      'taskRequest',
      'progress',
      'cancel',
      'terminalResult',
      'terminalError',
      'unsupported',
    ],
    'capabilities': <String>['ocrComputeV1', 'translationComputeV1'],
  };

  /// Hash of the stable schema descriptor, not of a message containing this
  /// field. This avoids a circular hash while making schema drift explicit.
  static final String schemaHash =
      sha256
          .convert(utf8.encode(LanProtocolV2.canonicalJson(_schemaDefinition)))
          .toString();

  static String canonicalJson(Object? value) =>
      LanProtocolV2.canonicalJson(value);

  static String hashCanonical(Object? value) =>
      sha256.convert(utf8.encode(canonicalJson(value))).toString();

  static LanComputeMessage fromJson(Map<String, dynamic> json) {
    final Object? type = json['type'];
    if (type is! String) {
      throw const LanComputeProtocolException(
        'compute message type must be a string',
      );
    }
    return switch (type) {
      'capabilityDescriptor' => LanComputeCapabilityDescriptor.fromJson(json),
      'taskRequest' => LanComputeTaskRequest.fromJson(json),
      'progress' => LanComputeProgress.fromJson(json),
      'cancel' => LanComputeCancel.fromJson(json),
      'terminalResult' => LanComputeTerminalResult.fromJson(json),
      'terminalError' => LanComputeTerminalError.fromJson(json),
      'unsupported' => LanComputeUnsupported.fromJson(json),
      _ =>
        throw const LanComputeProtocolException(
          'unsupported compute message type',
        ),
    };
  }

  static LanComputeSupportDecision negotiateSupport({
    required int peerVersion,
    required Iterable<String> peerCapabilities,
    required LanComputeCapability capability,
  }) {
    if (peerVersion != version) {
      return LanComputeSupportDecision(
        capability: capability,
        status: LanComputeSupportStatus.unsupportedSchema,
      );
    }
    if (!peerCapabilities.contains(capability.wireName)) {
      return LanComputeSupportDecision(
        capability: capability,
        status: LanComputeSupportStatus.unsupportedCapability,
      );
    }
    return LanComputeSupportDecision(
      capability: capability,
      status: LanComputeSupportStatus.supported,
    );
  }

  static bool acceptsCommit({
    required LanComputeCommitGate expected,
    required LanComputeCommitGate actual,
  }) =>
      expected.targetId == actual.targetId &&
      expected.generation == actual.generation &&
      expected.gateId == actual.gateId;
}

enum LanComputeCapability { ocr, translation }

extension LanComputeCapabilityWire on LanComputeCapability {
  String get wireName => switch (this) {
    LanComputeCapability.ocr => 'ocrComputeV1',
    LanComputeCapability.translation => 'translationComputeV1',
  };
}

enum LanComputePlatform { ios, android, macos, windows, linux, unknown }

extension LanComputePlatformWire on LanComputePlatform {
  String get wireName => switch (this) {
    LanComputePlatform.ios => 'ios',
    LanComputePlatform.android => 'android',
    LanComputePlatform.macos => 'macos',
    LanComputePlatform.windows => 'windows',
    LanComputePlatform.linux => 'linux',
    LanComputePlatform.unknown => 'unknown',
  };
}

enum LanComputeReadinessReason {
  ready,
  notSupported,
  notReady,
  modelMissing,
  providerUnavailable,
  permissionDenied,
  unsupportedPlatform,
  unknown,
}

extension LanComputeReadinessReasonWire on LanComputeReadinessReason {
  String get wireName => switch (this) {
    LanComputeReadinessReason.ready => 'ready',
    LanComputeReadinessReason.notSupported => 'notSupported',
    LanComputeReadinessReason.notReady => 'notReady',
    LanComputeReadinessReason.modelMissing => 'modelMissing',
    LanComputeReadinessReason.providerUnavailable => 'providerUnavailable',
    LanComputeReadinessReason.permissionDenied => 'permissionDenied',
    LanComputeReadinessReason.unsupportedPlatform => 'unsupportedPlatform',
    LanComputeReadinessReason.unknown => 'unknown',
  };
}

enum LanComputeArtifactKind { image, text, regions, overlay }

extension LanComputeArtifactKindWire on LanComputeArtifactKind {
  String get wireName => switch (this) {
    LanComputeArtifactKind.image => 'image',
    LanComputeArtifactKind.text => 'text',
    LanComputeArtifactKind.regions => 'regions',
    LanComputeArtifactKind.overlay => 'overlay',
  };
}

enum LanComputeProgressStage { queued, running, finalizing }

extension LanComputeProgressStageWire on LanComputeProgressStage {
  String get wireName => switch (this) {
    LanComputeProgressStage.queued => 'queued',
    LanComputeProgressStage.running => 'running',
    LanComputeProgressStage.finalizing => 'finalizing',
  };
}

enum LanComputeCancelReason {
  user,
  deadline,
  disconnected,
  superseded,
  shutdown,
}

extension LanComputeCancelReasonWire on LanComputeCancelReason {
  String get wireName => switch (this) {
    LanComputeCancelReason.user => 'user',
    LanComputeCancelReason.deadline => 'deadline',
    LanComputeCancelReason.disconnected => 'disconnected',
    LanComputeCancelReason.superseded => 'superseded',
    LanComputeCancelReason.shutdown => 'shutdown',
  };
}

enum LanComputeErrorCode {
  unsupportedSchema,
  unsupportedCapability,
  notReady,
  notAuthorized,
  invalidRequest,
  hashMismatch,
  deadlineExceeded,
  cancelled,
  executorUnavailable,
  resourceExhausted,
  staleGeneration,
  failed,
}

extension LanComputeErrorCodeWire on LanComputeErrorCode {
  String get wireName => switch (this) {
    LanComputeErrorCode.unsupportedSchema => 'unsupportedSchema',
    LanComputeErrorCode.unsupportedCapability => 'unsupportedCapability',
    LanComputeErrorCode.notReady => 'notReady',
    LanComputeErrorCode.notAuthorized => 'notAuthorized',
    LanComputeErrorCode.invalidRequest => 'invalidRequest',
    LanComputeErrorCode.hashMismatch => 'hashMismatch',
    LanComputeErrorCode.deadlineExceeded => 'deadlineExceeded',
    LanComputeErrorCode.cancelled => 'cancelled',
    LanComputeErrorCode.executorUnavailable => 'executorUnavailable',
    LanComputeErrorCode.resourceExhausted => 'resourceExhausted',
    LanComputeErrorCode.staleGeneration => 'staleGeneration',
    LanComputeErrorCode.failed => 'failed',
  };
}

enum LanComputeUnsupportedReason {
  unsupportedSchema,
  unsupportedCapability,
  notReady,
  notAuthorized,
}

extension LanComputeUnsupportedReasonWire on LanComputeUnsupportedReason {
  String get wireName => switch (this) {
    LanComputeUnsupportedReason.unsupportedSchema => 'unsupportedSchema',
    LanComputeUnsupportedReason.unsupportedCapability =>
      'unsupportedCapability',
    LanComputeUnsupportedReason.notReady => 'notReady',
    LanComputeUnsupportedReason.notAuthorized => 'notAuthorized',
  };
}

enum LanComputeSupportStatus {
  supported,
  unsupportedSchema,
  unsupportedCapability,
}

class LanComputeSupportDecision {
  final LanComputeCapability capability;
  final LanComputeSupportStatus status;

  const LanComputeSupportDecision({
    required this.capability,
    required this.status,
  });

  bool get supported => status == LanComputeSupportStatus.supported;
}

abstract class LanComputeMessage {
  const LanComputeMessage();

  String get type;
  Map<String, dynamic> toJson();

  String get canonicalJson => LanComputeProtocol.canonicalJson(toJson());

  String get messageHash => LanComputeProtocol.hashCanonical(toJson());
}

class LanComputeExecutorIdentity {
  final String deviceId;
  final String executorId;
  final LanComputePlatform platform;

  LanComputeExecutorIdentity({
    required this.deviceId,
    required this.executorId,
    required this.platform,
  }) {
    _Json.identifierValue(deviceId, 'deviceId');
    _Json.identifierValue(executorId, 'executorId');
  }

  factory LanComputeExecutorIdentity.fromJson(Object? value) {
    final Map<String, dynamic> json = _Json.object(value, 'executor');
    _Json.assertKeys(
      json,
      allowed: const <String>{'deviceId', 'executorId', 'platform'},
      required: const <String>{'deviceId', 'executorId', 'platform'},
    );
    return LanComputeExecutorIdentity(
      deviceId: _Json.identifier(json['deviceId'], 'deviceId'),
      executorId: _Json.identifier(json['executorId'], 'executorId'),
      platform: _Json.enumValue(
        json['platform'],
        'platform',
        LanComputePlatform.values,
        (LanComputePlatform value) => value.wireName,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deviceId': deviceId,
    'executorId': executorId,
    'platform': platform.wireName,
  };
}

class LanComputeCommitGate {
  final String targetId;
  final int generation;
  final String gateId;

  LanComputeCommitGate({
    required this.targetId,
    required this.generation,
    required this.gateId,
  }) {
    _Json.identifierValue(targetId, 'targetId');
    _Json.generationValue(generation, 'generation');
    _Json.identifierValue(gateId, 'gateId');
  }

  factory LanComputeCommitGate.fromJson(Object? value) {
    final Map<String, dynamic> json = _Json.object(value, 'commitGate');
    _Json.assertKeys(
      json,
      allowed: const <String>{'targetId', 'generation', 'gateId'},
      required: const <String>{'targetId', 'generation', 'gateId'},
    );
    return LanComputeCommitGate(
      targetId: _Json.identifier(json['targetId'], 'targetId'),
      generation: _Json.generation(json['generation'], 'generation'),
      gateId: _Json.identifier(json['gateId'], 'gateId'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetId': targetId,
    'generation': generation,
    'gateId': gateId,
  };
}

class LanComputeDataRef {
  final LanComputeArtifactKind kind;
  final String hash;
  final int sizeBytes;

  LanComputeDataRef({
    required this.kind,
    required this.hash,
    required this.sizeBytes,
  }) {
    _Json.hashValue(hash, 'hash');
    _Json.artifactSize(sizeBytes, 'sizeBytes');
  }

  factory LanComputeDataRef.fromJson(Object? value, {required String field}) {
    final Map<String, dynamic> json = _Json.object(value, field);
    _Json.assertKeys(
      json,
      allowed: const <String>{'kind', 'hash', 'sizeBytes'},
      required: const <String>{'kind', 'hash', 'sizeBytes'},
    );
    return LanComputeDataRef(
      kind: _Json.enumValue(
        json['kind'],
        '$field.kind',
        LanComputeArtifactKind.values,
        (LanComputeArtifactKind value) => value.wireName,
      ),
      hash: _Json.hash(json['hash'], '$field.hash'),
      sizeBytes: _Json.artifactSize(json['sizeBytes'], '$field.sizeBytes'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.wireName,
    'hash': hash,
    'sizeBytes': sizeBytes,
  };
}

class LanComputeCapabilityDescriptor extends LanComputeMessage {
  final bool ready;
  final LanComputeCapability capability;
  final LanComputeReadinessReason reason;
  final LanComputeExecutorIdentity executor;
  final String? modelHash;
  final String? configHash;
  final String schemaHash;

  LanComputeCapabilityDescriptor({
    required this.ready,
    required this.capability,
    required this.reason,
    required this.executor,
    required this.schemaHash,
    this.modelHash,
    this.configHash,
  }) {
    _Json.schemaHashValue(schemaHash);
    if (ready && reason != LanComputeReadinessReason.ready) {
      throw const LanComputeProtocolException(
        'ready capability must use the ready reason',
      );
    }
    if (!ready && reason == LanComputeReadinessReason.ready) {
      throw const LanComputeProtocolException(
        'unavailable capability cannot use the ready reason',
      );
    }
    if (modelHash != null) {
      _Json.hashValue(modelHash!, 'modelHash');
    }
    if (configHash != null) {
      _Json.hashValue(configHash!, 'configHash');
    }
    if (ready && (modelHash == null || configHash == null)) {
      throw const LanComputeProtocolException(
        'ready capability requires modelHash and configHash',
      );
    }
  }

  @override
  String get type => 'capabilityDescriptor';

  factory LanComputeCapabilityDescriptor.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'capabilityDescriptor',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'capability',
        'ready',
        'reason',
        'executor',
        'modelHash',
        'configHash',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'capability',
        'ready',
        'reason',
        'executor',
      },
    );
    return LanComputeCapabilityDescriptor(
      ready: _Json.boolean(value['ready'], 'ready'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      reason: _Json.enumValue(
        value['reason'],
        'reason',
        LanComputeReadinessReason.values,
        (LanComputeReadinessReason item) => item.wireName,
      ),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      modelHash: _Json.optionalHash(value, 'modelHash'),
      configHash: _Json.optionalHash(value, 'configHash'),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'capability': capability.wireName,
    'ready': ready,
    'reason': reason.wireName,
    'executor': executor.toJson(),
    if (modelHash != null) 'modelHash': modelHash,
    if (configHash != null) 'configHash': configHash,
  };
}

class LanComputeTaskRequest extends LanComputeMessage {
  final String taskId;
  final LanComputeCapability capability;
  final String modelHash;
  final String configHash;
  final String? promptHash;
  final LanComputeDataRef input;
  final int deadlineEpochMs;
  final LanComputeExecutorIdentity executor;
  final LanComputeCommitGate commitGate;
  final String schemaHash;

  LanComputeTaskRequest({
    required this.taskId,
    required this.capability,
    required this.modelHash,
    required this.configHash,
    required this.input,
    required this.deadlineEpochMs,
    required this.executor,
    required this.commitGate,
    required this.schemaHash,
    this.promptHash,
  }) {
    _Json.identifierValue(taskId, 'taskId');
    _Json.hashValue(modelHash, 'modelHash');
    _Json.hashValue(configHash, 'configHash');
    if (promptHash != null) {
      _Json.hashValue(promptHash!, 'promptHash');
    }
    _Json.epochValue(deadlineEpochMs, 'deadlineEpochMs');
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'taskRequest';

  factory LanComputeTaskRequest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'taskRequest',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'modelHash',
        'configHash',
        'promptHash',
        'input',
        'deadlineEpochMs',
        'executor',
        'commitGate',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'modelHash',
        'configHash',
        'input',
        'deadlineEpochMs',
        'executor',
        'commitGate',
      },
    );
    return LanComputeTaskRequest(
      taskId: _Json.identifier(value['taskId'], 'taskId'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      modelHash: _Json.hash(value['modelHash'], 'modelHash'),
      configHash: _Json.hash(value['configHash'], 'configHash'),
      promptHash: _Json.optionalHash(value, 'promptHash'),
      input: LanComputeDataRef.fromJson(value['input'], field: 'input'),
      deadlineEpochMs: _Json.epoch(value['deadlineEpochMs'], 'deadlineEpochMs'),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      commitGate: LanComputeCommitGate.fromJson(value['commitGate']),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'taskId': taskId,
    'capability': capability.wireName,
    'modelHash': modelHash,
    'configHash': configHash,
    if (promptHash != null) 'promptHash': promptHash,
    'input': input.toJson(),
    'deadlineEpochMs': deadlineEpochMs,
    'executor': executor.toJson(),
    'commitGate': commitGate.toJson(),
  };
}

class LanComputeProgress extends LanComputeMessage {
  final String taskId;
  final LanComputeCapability capability;
  final LanComputeProgressStage stage;
  final double progress;
  final int observedAtEpochMs;
  final LanComputeExecutorIdentity executor;
  final LanComputeCommitGate commitGate;
  final String schemaHash;

  LanComputeProgress({
    required this.taskId,
    required this.capability,
    required this.stage,
    required this.progress,
    required this.observedAtEpochMs,
    required this.executor,
    required this.commitGate,
    required this.schemaHash,
  }) {
    _Json.identifierValue(taskId, 'taskId');
    _Json.progressValue(progress);
    _Json.epochValue(observedAtEpochMs, 'observedAtEpochMs');
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'progress';

  factory LanComputeProgress.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'progress',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'stage',
        'progress',
        'observedAtEpochMs',
        'executor',
        'commitGate',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'stage',
        'progress',
        'observedAtEpochMs',
        'executor',
        'commitGate',
      },
    );
    return LanComputeProgress(
      taskId: _Json.identifier(value['taskId'], 'taskId'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      stage: _Json.enumValue(
        value['stage'],
        'stage',
        LanComputeProgressStage.values,
        (LanComputeProgressStage item) => item.wireName,
      ),
      progress: _Json.progress(value['progress']),
      observedAtEpochMs: _Json.epoch(
        value['observedAtEpochMs'],
        'observedAtEpochMs',
      ),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      commitGate: LanComputeCommitGate.fromJson(value['commitGate']),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'taskId': taskId,
    'capability': capability.wireName,
    'stage': stage.wireName,
    'progress': progress,
    'observedAtEpochMs': observedAtEpochMs,
    'executor': executor.toJson(),
    'commitGate': commitGate.toJson(),
  };
}

class LanComputeCancel extends LanComputeMessage {
  final String taskId;
  final LanComputeCapability capability;
  final LanComputeCancelReason reason;
  final int requestedAtEpochMs;
  final LanComputeExecutorIdentity executor;
  final LanComputeCommitGate commitGate;
  final String schemaHash;

  LanComputeCancel({
    required this.taskId,
    required this.capability,
    required this.reason,
    required this.requestedAtEpochMs,
    required this.executor,
    required this.commitGate,
    required this.schemaHash,
  }) {
    _Json.identifierValue(taskId, 'taskId');
    _Json.epochValue(requestedAtEpochMs, 'requestedAtEpochMs');
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'cancel';

  factory LanComputeCancel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'cancel',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'reason',
        'requestedAtEpochMs',
        'executor',
        'commitGate',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'reason',
        'requestedAtEpochMs',
        'executor',
        'commitGate',
      },
    );
    return LanComputeCancel(
      taskId: _Json.identifier(value['taskId'], 'taskId'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      reason: _Json.enumValue(
        value['reason'],
        'reason',
        LanComputeCancelReason.values,
        (LanComputeCancelReason item) => item.wireName,
      ),
      requestedAtEpochMs: _Json.epoch(
        value['requestedAtEpochMs'],
        'requestedAtEpochMs',
      ),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      commitGate: LanComputeCommitGate.fromJson(value['commitGate']),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'taskId': taskId,
    'capability': capability.wireName,
    'reason': reason.wireName,
    'requestedAtEpochMs': requestedAtEpochMs,
    'executor': executor.toJson(),
    'commitGate': commitGate.toJson(),
  };
}

class LanComputeTerminalResult extends LanComputeMessage {
  final String taskId;
  final LanComputeCapability capability;
  final LanComputeDataRef output;
  final int completedAtEpochMs;
  final LanComputeExecutorIdentity executor;
  final LanComputeCommitGate commitGate;
  final String schemaHash;

  LanComputeTerminalResult({
    required this.taskId,
    required this.capability,
    required this.output,
    required this.completedAtEpochMs,
    required this.executor,
    required this.commitGate,
    required this.schemaHash,
  }) {
    _Json.identifierValue(taskId, 'taskId');
    _Json.epochValue(completedAtEpochMs, 'completedAtEpochMs');
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'terminalResult';

  factory LanComputeTerminalResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'terminalResult',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'output',
        'completedAtEpochMs',
        'executor',
        'commitGate',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'output',
        'completedAtEpochMs',
        'executor',
        'commitGate',
      },
    );
    return LanComputeTerminalResult(
      taskId: _Json.identifier(value['taskId'], 'taskId'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      output: LanComputeDataRef.fromJson(value['output'], field: 'output'),
      completedAtEpochMs: _Json.epoch(
        value['completedAtEpochMs'],
        'completedAtEpochMs',
      ),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      commitGate: LanComputeCommitGate.fromJson(value['commitGate']),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'taskId': taskId,
    'capability': capability.wireName,
    'output': output.toJson(),
    'completedAtEpochMs': completedAtEpochMs,
    'executor': executor.toJson(),
    'commitGate': commitGate.toJson(),
  };
}

class LanComputeTerminalError extends LanComputeMessage {
  final String taskId;
  final LanComputeCapability capability;
  final LanComputeErrorCode code;
  final bool retryable;
  final int completedAtEpochMs;
  final LanComputeExecutorIdentity executor;
  final LanComputeCommitGate commitGate;
  final String schemaHash;

  LanComputeTerminalError({
    required this.taskId,
    required this.capability,
    required this.code,
    required this.retryable,
    required this.completedAtEpochMs,
    required this.executor,
    required this.commitGate,
    required this.schemaHash,
  }) {
    _Json.identifierValue(taskId, 'taskId');
    _Json.epochValue(completedAtEpochMs, 'completedAtEpochMs');
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'terminalError';

  factory LanComputeTerminalError.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'terminalError',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'code',
        'retryable',
        'completedAtEpochMs',
        'executor',
        'commitGate',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'taskId',
        'capability',
        'code',
        'retryable',
        'completedAtEpochMs',
        'executor',
        'commitGate',
      },
    );
    return LanComputeTerminalError(
      taskId: _Json.identifier(value['taskId'], 'taskId'),
      capability: _Json.enumValue(
        value['capability'],
        'capability',
        LanComputeCapability.values,
        (LanComputeCapability item) => item.wireName,
      ),
      code: _Json.enumValue(
        value['code'],
        'code',
        LanComputeErrorCode.values,
        (LanComputeErrorCode item) => item.wireName,
      ),
      retryable: _Json.boolean(value['retryable'], 'retryable'),
      completedAtEpochMs: _Json.epoch(
        value['completedAtEpochMs'],
        'completedAtEpochMs',
      ),
      executor: LanComputeExecutorIdentity.fromJson(value['executor']),
      commitGate: LanComputeCommitGate.fromJson(value['commitGate']),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'taskId': taskId,
    'capability': capability.wireName,
    'code': code.wireName,
    'retryable': retryable,
    'completedAtEpochMs': completedAtEpochMs,
    'executor': executor.toJson(),
    'commitGate': commitGate.toJson(),
  };
}

class LanComputeUnsupported extends LanComputeMessage {
  final String capability;
  final LanComputeUnsupportedReason reason;
  final String? taskId;
  final String schemaHash;

  LanComputeUnsupported({
    required this.capability,
    required this.reason,
    required this.schemaHash,
    this.taskId,
  }) {
    _Json.identifierValue(capability, 'capability');
    if (taskId != null) {
      _Json.identifierValue(taskId!, 'taskId');
    }
    _Json.schemaHashValue(schemaHash);
  }

  @override
  String get type => 'unsupported';

  factory LanComputeUnsupported.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> value = _Json.envelope(
      json,
      type: 'unsupported',
      allowed: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'capability',
        'reason',
        'taskId',
      },
      required: const <String>{
        'schema',
        'version',
        'type',
        'schemaHash',
        'capability',
        'reason',
      },
    );
    return LanComputeUnsupported(
      capability: _Json.identifier(value['capability'], 'capability'),
      reason: _Json.enumValue(
        value['reason'],
        'reason',
        LanComputeUnsupportedReason.values,
        (LanComputeUnsupportedReason item) => item.wireName,
      ),
      taskId: _Json.optionalIdentifier(value, 'taskId'),
      schemaHash: value['schemaHash'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': LanComputeProtocol.schema,
    'version': LanComputeProtocol.version,
    'type': type,
    'schemaHash': schemaHash,
    'capability': capability,
    'reason': reason.wireName,
    if (taskId != null) 'taskId': taskId,
  };
}

class LanComputeProtocolException implements Exception {
  final String message;

  const LanComputeProtocolException(this.message);

  @override
  String toString() => 'LanComputeProtocolException: $message';
}

class _Json {
  static final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9._:-]+$');
  static final RegExp _hashPattern = RegExp(r'^[0-9a-f]{64}$');
  static const Set<String> _sensitiveFragments = <String>{
    'cookie',
    'apikey',
    'api_key',
    'authorization',
    'password',
    'proxy',
    'secret',
    'credential',
    'token',
    'originalimage',
    'rawimage',
    'imagebytes',
  };

  static Map<String, dynamic> object(Object? value, String field) {
    if (value is! Map) {
      throw LanComputeProtocolException('$field must be an object');
    }
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      if (entry.key is! String) {
        throw LanComputeProtocolException('$field has a non-string key');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static void assertKeys(
    Map<String, dynamic> json, {
    required Set<String> allowed,
    required Set<String> required,
  }) {
    for (final String key in json.keys) {
      if (!allowed.contains(key)) {
        if (_isSensitiveKey(key)) {
          throw const LanComputeProtocolException(
            'secret fields are not allowed in compute messages',
          );
        }
        throw LanComputeProtocolException('unknown compute field: $key');
      }
    }
    for (final String key in required) {
      if (!json.containsKey(key)) {
        throw LanComputeProtocolException('missing compute field: $key');
      }
    }
  }

  static Map<String, dynamic> envelope(
    Object? raw, {
    required String type,
    required Set<String> allowed,
    required Set<String> required,
  }) {
    final Map<String, dynamic> json = object(raw, 'compute message');
    assertKeys(json, allowed: allowed, required: required);
    if (json['schema'] != LanComputeProtocol.schema) {
      throw const LanComputeProtocolException('unsupported compute schema');
    }
    if (integer(json['version'], 'version') != LanComputeProtocol.version) {
      throw const LanComputeProtocolException('unsupported compute version');
    }
    if (json['type'] != type) {
      throw const LanComputeProtocolException('compute message type mismatch');
    }
    schemaHashValue(json['schemaHash']);
    final int bytes =
        utf8.encode(LanComputeProtocol.canonicalJson(json)).length;
    if (bytes > LanComputeProtocol.maxMessageBytes) {
      throw const LanComputeProtocolException('compute message is too large');
    }
    return json;
  }

  static String string(Object? value, String field, {int max = 128}) {
    if (value is! String || value.isEmpty || value.length > max) {
      throw LanComputeProtocolException('$field must be a bounded string');
    }
    if (value.contains('\u0000') ||
        value.contains('\n') ||
        value.contains('\r')) {
      throw LanComputeProtocolException('$field contains control characters');
    }
    return value;
  }

  static String identifier(Object? value, String field) {
    final String result = string(
      value,
      field,
      max: LanComputeProtocol.maxIdentifierLength,
    );
    if (!_identifierPattern.hasMatch(result)) {
      throw LanComputeProtocolException('$field has an invalid identifier');
    }
    return result;
  }

  static String? optionalIdentifier(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      return null;
    }
    return identifier(json[field], field);
  }

  static void identifierValue(String value, String field) {
    identifier(value, field);
  }

  static bool boolean(Object? value, String field) {
    if (value is! bool) {
      throw LanComputeProtocolException('$field must be a boolean');
    }
    return value;
  }

  static int integer(Object? value, String field) {
    if (value is! int || value is bool) {
      throw LanComputeProtocolException('$field must be an integer');
    }
    return value;
  }

  static int generation(Object? value, String field) {
    final int result = integer(value, field);
    if (result < 0 || result > LanComputeProtocol.maxSafeInteger) {
      throw LanComputeProtocolException('$field is outside the safe range');
    }
    return result;
  }

  static void generationValue(int value, String field) {
    generation(value, field);
  }

  static int epoch(Object? value, String field) {
    final int result = integer(value, field);
    if (result < 1 || result > LanComputeProtocol.maxSafeInteger) {
      throw LanComputeProtocolException('$field is outside the safe range');
    }
    return result;
  }

  static void epochValue(int value, String field) {
    epoch(value, field);
  }

  static double progress(Object? value) {
    if (value is! num || value is bool) {
      throw const LanComputeProtocolException('progress must be a number');
    }
    final double result = value.toDouble();
    return progressValue(result);
  }

  static double progressValue(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw const LanComputeProtocolException(
        'progress must be between 0 and 1',
      );
    }
    return value;
  }

  static int artifactSize(Object? value, String field) {
    final int result = integer(value, field);
    if (result < 1 || result > LanComputeProtocol.maxArtifactBytes) {
      throw LanComputeProtocolException('$field is outside the size limit');
    }
    return result;
  }

  static String hash(Object? value, String field) {
    final String result = string(value, field, max: 64);
    if (!_hashPattern.hasMatch(result)) {
      throw LanComputeProtocolException(
        '$field must be a lowercase SHA-256 hash',
      );
    }
    return result;
  }

  static String? optionalHash(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) {
      return null;
    }
    return hash(json[field], field);
  }

  static void hashValue(String value, String field) {
    hash(value, field);
  }

  static void schemaHashValue(Object? value) {
    if (value != LanComputeProtocol.schemaHash) {
      throw const LanComputeProtocolException('compute schema hash mismatch');
    }
  }

  static T enumValue<T>(
    Object? value,
    String field,
    Iterable<T> values,
    String Function(T value) wireName,
  ) {
    if (value is! String) {
      throw LanComputeProtocolException('$field must be an enum string');
    }
    for (final T candidate in values) {
      if (wireName(candidate) == value) {
        return candidate;
      }
    }
    throw LanComputeProtocolException('$field has an unsupported enum value');
  }

  static bool _isSensitiveKey(String key) {
    final String normalized = key.toLowerCase().replaceAll('-', '');
    return _sensitiveFragments.any(normalized.contains);
  }
}
