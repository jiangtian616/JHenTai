import 'dart:convert';

import 'package:crypto/crypto.dart';

enum LanSharePermission {
  downloads,
  imageCache,
  translationResults,
  translationCompute,
}

enum LanPeerConnectionState {
  offline,
  discovered,
  connecting,
  connected,
  failed,
  identityMismatch,
}

class TrustedLanDevice {
  static final RegExp deviceIdPattern = RegExp(r'^[a-zA-Z0-9_-]{16,128}$');
  static final RegExp fingerprintPattern = RegExp(r'^[a-f0-9]{64}$');

  final String deviceId;
  final String displayName;
  final String identityPublicKey;
  final String identityFingerprint;
  final Set<LanSharePermission> permissions;
  final bool autoConnect;
  final DateTime pairedAt;
  final DateTime lastSeenAt;
  final DateTime? lastConnectedAt;
  final int protocolVersion;

  const TrustedLanDevice({
    required this.deviceId,
    required this.displayName,
    required this.identityPublicKey,
    required this.identityFingerprint,
    required this.permissions,
    required this.autoConnect,
    required this.pairedAt,
    required this.lastSeenAt,
    this.lastConnectedAt,
    this.protocolVersion = 1,
  });

  TrustedLanDevice copyWith({
    String? displayName,
    String? identityPublicKey,
    String? identityFingerprint,
    Set<LanSharePermission>? permissions,
    bool? autoConnect,
    DateTime? lastSeenAt,
    DateTime? lastConnectedAt,
    int? protocolVersion,
  }) {
    return TrustedLanDevice(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      identityPublicKey: identityPublicKey ?? this.identityPublicKey,
      identityFingerprint: identityFingerprint ?? this.identityFingerprint,
      permissions: permissions ?? this.permissions,
      autoConnect: autoConnect ?? this.autoConnect,
      pairedAt: pairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      protocolVersion: protocolVersion ?? this.protocolVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'displayName': displayName,
    'identityPublicKey': identityPublicKey,
    'identityFingerprint': identityFingerprint,
    'permissions':
        permissions.map((permission) => permission.name).toList()..sort(),
    'autoConnect': autoConnect,
    'pairedAt': pairedAt.toUtc().toIso8601String(),
    'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
    if (lastConnectedAt != null)
      'lastConnectedAt': lastConnectedAt!.toUtc().toIso8601String(),
    'protocolVersion': protocolVersion,
  };

  factory TrustedLanDevice.fromJson(Map<String, dynamic> json) {
    final String deviceId = json['deviceId'] as String? ?? '';
    final String publicKey = json['identityPublicKey'] as String? ?? '';
    final String fingerprint =
        (json['identityFingerprint'] as String? ?? '').toLowerCase();
    if (!deviceIdPattern.hasMatch(deviceId)) {
      throw const FormatException('Invalid LAN device id');
    }
    if (!_isValidPublicKey(publicKey) ||
        !fingerprintPattern.hasMatch(fingerprint) ||
        fingerprintForPublicKey(publicKey) != fingerprint) {
      throw const FormatException('Invalid LAN identity key');
    }

    final Set<LanSharePermission> permissions =
        (json['permissions'] as List? ?? const [])
            .whereType<String>()
            .map(
              (name) =>
                  LanSharePermission.values
                      .where((permission) => permission.name == name)
                      .firstOrNull,
            )
            .whereType<LanSharePermission>()
            .toSet();

    return TrustedLanDevice(
      deviceId: deviceId,
      displayName: (json['displayName'] as String? ?? deviceId).trim(),
      identityPublicKey: publicKey,
      identityFingerprint: fingerprint,
      permissions: permissions,
      autoConnect: json['autoConnect'] as bool? ?? true,
      pairedAt: DateTime.parse(json['pairedAt'] as String).toUtc(),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String).toUtc(),
      lastConnectedAt:
          json['lastConnectedAt'] == null
              ? null
              : DateTime.parse(json['lastConnectedAt'] as String).toUtc(),
      protocolVersion: json['protocolVersion'] as int? ?? 1,
    );
  }

  static String fingerprintForPublicKey(String publicKey) =>
      sha256
          .convert(base64Url.decode(base64Url.normalize(publicKey)))
          .toString();

  static bool _isValidPublicKey(String publicKey) {
    try {
      return base64Url.decode(base64Url.normalize(publicKey)).length == 32;
    } on FormatException {
      return false;
    }
  }
}

class LanDiscoveredPeer {
  final String deviceId;
  final String displayName;
  final String host;
  final int port;
  final String identityPublicKey;
  final String identityFingerprint;
  final int protocolVersion;

  const LanDiscoveredPeer({
    required this.deviceId,
    required this.displayName,
    required this.host,
    required this.port,
    required this.identityPublicKey,
    required this.identityFingerprint,
    this.protocolVersion = 1,
  });
}

class LanConnectionSnapshot {
  final LanPeerConnectionState state;
  final String? errorMessage;

  const LanConnectionSnapshot(this.state, {this.errorMessage});
}

class LanPairingAcceptance {
  final String localDeviceId;
  final String localIdentityPublicKey;
  final String localIdentityFingerprint;
  final String accessTokenForRemote;

  const LanPairingAcceptance({
    required this.localDeviceId,
    required this.localIdentityPublicKey,
    required this.localIdentityFingerprint,
    required this.accessTokenForRemote,
  });
}

/// A single downloaded-gallery summary a trusted host serves to a peer, so the
/// peer can browse the host's library without fetching gallery metadata itself.
class LanSharedGallerySummary {
  final String deviceId;
  final String deviceName;
  final int gid;
  final String token;
  final String title;
  final String galleryUrl;
  final int pageCount;
  final String category;
  final String publishTime;
  final String? coverUrl;

  const LanSharedGallerySummary({
    required this.deviceId,
    required this.deviceName,
    required this.gid,
    required this.token,
    required this.title,
    required this.galleryUrl,
    required this.pageCount,
    required this.category,
    required this.publishTime,
    this.coverUrl,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'gid': gid,
    'token': token,
    'title': title,
    'galleryUrl': galleryUrl,
    'pageCount': pageCount,
    'category': category,
    'publishTime': publishTime,
    if (coverUrl != null) 'coverUrl': coverUrl,
  };

  factory LanSharedGallerySummary.fromJson(Map<String, dynamic> json) =>
      LanSharedGallerySummary(
        deviceId: json['deviceId'] as String? ?? '',
        deviceName: json['deviceName'] as String? ?? '',
        gid: (json['gid'] as num?)?.toInt() ?? 0,
        token: json['token'] as String? ?? '',
        title: json['title'] as String? ?? '',
        galleryUrl: json['galleryUrl'] as String? ?? '',
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        category: json['category'] as String? ?? '',
        publishTime: json['publishTime'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
      );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
