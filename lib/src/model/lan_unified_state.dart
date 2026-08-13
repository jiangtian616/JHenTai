import 'dart:convert';

enum LanUnifiedRecordType { galleryHistory, readProgress, bookmark }

extension LanUnifiedRecordTypeWire on LanUnifiedRecordType {
  String get wireName => switch (this) {
    LanUnifiedRecordType.galleryHistory => 'galleryHistory',
    LanUnifiedRecordType.readProgress => 'readProgress',
    LanUnifiedRecordType.bookmark => 'bookmark',
  };

  static LanUnifiedRecordType parse(String value) =>
      LanUnifiedRecordType.values.firstWhere(
        (type) => type.wireName == value,
        orElse:
            () =>
                throw const FormatException('Unknown LAN unified record type'),
      );
}

class LanUnifiedRecord {
  final LanUnifiedRecordType type;
  final String key;
  final DateTime updatedAt;
  final bool tombstone;
  final Map<String, dynamic> value;
  final String sourceDeviceId;

  const LanUnifiedRecord({
    required this.type,
    required this.key,
    required this.updatedAt,
    required this.tombstone,
    required this.value,
    required this.sourceDeviceId,
  });

  LanUnifiedRecord copyWith({
    DateTime? updatedAt,
    bool? tombstone,
    Map<String, dynamic>? value,
    String? sourceDeviceId,
  }) => LanUnifiedRecord(
    type: type,
    key: key,
    updatedAt: updatedAt ?? this.updatedAt,
    tombstone: tombstone ?? this.tombstone,
    value: value ?? this.value,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
  );

  String get storageKey => '${type.wireName}::$key';

  Map<String, dynamic> toJson() => {
    'type': type.wireName,
    'key': key,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'tombstone': tombstone,
    'value': value,
    'sourceDeviceId': sourceDeviceId,
  };

  factory LanUnifiedRecord.fromJson(Map<String, dynamic> json) {
    final dynamic rawValue = json['value'];
    if (rawValue is! Map) {
      throw const FormatException('LAN unified record value must be an object');
    }
    final String key = json['key'] as String? ?? '';
    if (key.isEmpty || key.length > 512) {
      throw const FormatException('Invalid LAN unified record key');
    }
    return LanUnifiedRecord(
      type: LanUnifiedRecordTypeWire.parse(json['type'] as String? ?? ''),
      key: key,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      tombstone: json['tombstone'] as bool? ?? false,
      value: Map<String, dynamic>.from(rawValue),
      sourceDeviceId: json['sourceDeviceId'] as String? ?? '',
    );
  }
}

class LanLoginStateSnapshot {
  final List<String> sites;
  final int accountId;
  final List<String> cookies;
  final DateTime exportedAt;

  const LanLoginStateSnapshot({
    required this.sites,
    required this.accountId,
    required this.cookies,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
    'sites': sites,
    'accountId': accountId,
    'cookies': cookies,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
  };

  factory LanLoginStateSnapshot.fromJson(Map<String, dynamic> json) =>
      LanLoginStateSnapshot(
        sites:
            (json['sites'] as List? ?? const []).whereType<String>().toList(),
        accountId: (json['accountId'] as num?)?.toInt() ?? 0,
        cookies:
            (json['cookies'] as List? ?? const []).whereType<String>().toList(),
        exportedAt: DateTime.parse(json['exportedAt'] as String).toUtc(),
      );
}

class LanUnifiedStatePayload {
  static const int schemaVersion = 1;

  final String capability;
  final String sourceDeviceId;
  final DateTime generatedAt;
  final LanLoginStateSnapshot? loginState;
  final List<LanUnifiedRecord> records;

  const LanUnifiedStatePayload({
    required this.capability,
    required this.sourceDeviceId,
    required this.generatedAt,
    this.loginState,
    this.records = const [],
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> payload = {
      'schemaVersion': schemaVersion,
      'capability': capability,
      'sourceDeviceId': sourceDeviceId,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      if (loginState != null) 'loginState': loginState!.toJson(),
      'records': records.map((record) => record.toJson()).toList(),
    };
    LanUnifiedPayloadGuard.validate(payload);
    return payload;
  }

  factory LanUnifiedStatePayload.fromJson(Map<String, dynamic> json) {
    LanUnifiedPayloadGuard.validate(json);
    final dynamic rawRecords = json['records'];
    if (rawRecords is! List) {
      throw const FormatException('LAN unified payload records must be a list');
    }
    return LanUnifiedStatePayload(
      capability: json['capability'] as String? ?? '',
      sourceDeviceId: json['sourceDeviceId'] as String? ?? '',
      generatedAt: DateTime.parse(json['generatedAt'] as String).toUtc(),
      loginState:
          json['loginState'] is Map
              ? LanLoginStateSnapshot.fromJson(
                Map<String, dynamic>.from(json['loginState'] as Map),
              )
              : null,
      records:
          rawRecords
              .whereType<Map>()
              .map(
                (record) => LanUnifiedRecord.fromJson(
                  Map<String, dynamic>.from(record),
                ),
              )
              .toList(),
    );
  }
}

class LanUnifiedPayloadGuard {
  static const Set<String> _forbiddenKeys = {
    'apikey',
    'api_key',
    'translationapikey',
    'proxypassword',
    'proxy_password',
    'applockpassword',
    'app_lock_password',
  };

  static void validate(Object? value) {
    if (value is Map) {
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        if (entry.key is String &&
            _forbiddenKeys.contains((entry.key as String).toLowerCase())) {
          throw const FormatException(
            'LAN unified payload contains a forbidden secret field',
          );
        }
        validate(entry.value);
      }
    } else if (value is Iterable) {
      for (final Object? item in value) {
        validate(item);
      }
    }
  }
}

class LanUnifiedStateMerger {
  static List<LanUnifiedRecord> merge(
    Iterable<LanUnifiedRecord> local,
    Iterable<LanUnifiedRecord> remote,
  ) {
    final Map<String, LanUnifiedRecord> merged = {
      for (final LanUnifiedRecord record in local) record.storageKey: record,
    };
    for (final LanUnifiedRecord incoming in remote) {
      final LanUnifiedRecord? current = merged[incoming.storageKey];
      if (current == null || _wins(incoming, current)) {
        merged[incoming.storageKey] = incoming;
      }
    }
    return merged.values.toList()
      ..sort((a, b) => a.storageKey.compareTo(b.storageKey));
  }

  static bool _wins(LanUnifiedRecord incoming, LanUnifiedRecord current) {
    if (incoming.updatedAt.isAfter(current.updatedAt)) {
      return true;
    }
    if (incoming.updatedAt.isBefore(current.updatedAt)) {
      return false;
    }
    if (incoming.tombstone != current.tombstone) {
      return incoming.tombstone;
    }
    return incoming.sourceDeviceId.compareTo(current.sourceDeviceId) > 0;
  }
}

enum LanLoginImportOutcome {
  imported,
  refreshed,
  rejectedDifferentAccount,
  invalidCookie,
  unavailable,
}

class LanLoginImportResult {
  final LanLoginImportOutcome outcome;
  final String? failureReason;

  const LanLoginImportResult(this.outcome, {this.failureReason});

  bool get succeeded =>
      outcome == LanLoginImportOutcome.imported ||
      outcome == LanLoginImportOutcome.refreshed;
}

class LanUnifiedSyncStatus {
  final String sourceDeviceId;
  final String type;
  final DateTime at;
  final int count;
  final String? failureReason;

  const LanUnifiedSyncStatus({
    required this.sourceDeviceId,
    required this.type,
    required this.at,
    required this.count,
    this.failureReason,
  });
}

String encodeLanUnifiedRecords(Iterable<LanUnifiedRecord> records) =>
    jsonEncode(records.map((record) => record.toJson()).toList());
