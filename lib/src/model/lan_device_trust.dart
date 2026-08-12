import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gallery_thumbnail.dart';

enum LanSharePermission {
  downloads,
  imageCache,
  translationResults,
  translationCompute,
  ocrCompute,
  loginState,
  applicationHistory,
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
    'permissions': permissions.map((permission) => permission.name).toList()
      ..sort(),
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
    final String fingerprint = (json['identityFingerprint'] as String? ?? '')
        .toLowerCase();
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
              (name) => LanSharePermission.values
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
      lastConnectedAt: json['lastConnectedAt'] == null
          ? null
          : DateTime.parse(json['lastConnectedAt'] as String).toUtc(),
      protocolVersion: json['protocolVersion'] as int? ?? 1,
    );
  }

  static String fingerprintForPublicKey(String publicKey) => sha256
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
    this.protocolVersion = 2,
  });
}

class LanConnectionSnapshot {
  final LanPeerConnectionState state;
  final String? errorMessage;

  const LanConnectionSnapshot(this.state, {this.errorMessage});
}

class LanGalleryManifestPage {
  final int pageIndex;
  final GalleryThumbnail thumbnail;

  const LanGalleryManifestPage({
    required this.pageIndex,
    required this.thumbnail,
  });

  Map<String, dynamic> toJson() => {
    'pageIndex': pageIndex,
    'thumbnail': thumbnail.toMap(),
  };

  factory LanGalleryManifestPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> thumbnail = Map<String, dynamic>.from(
      json['thumbnail'] as Map? ?? const <String, dynamic>{},
    );
    return LanGalleryManifestPage(
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      thumbnail: GalleryThumbnail(
        href: thumbnail['href'] as String? ?? '',
        isLarge: thumbnail['isLarge'] as bool? ?? false,
        thumbUrl: thumbnail['thumbUrl'] as String? ?? '',
        thumbHeight: (thumbnail['thumbHeight'] as num?)?.toDouble(),
        thumbWidth: (thumbnail['thumbWidth'] as num?)?.toDouble(),
        offSet: (thumbnail['offSet'] as num?)?.toDouble(),
        originImageHash: thumbnail['originImageHash'] as String?,
      ),
    );
  }
}

class LanGalleryManifest {
  final String galleryUrl;
  final int pageCount;
  final int thumbnailsCountPerPage;
  final List<LanGalleryManifestPage> pages;

  const LanGalleryManifest({
    required this.galleryUrl,
    required this.pageCount,
    required this.thumbnailsCountPerPage,
    required this.pages,
  });

  Map<String, dynamic> toJson() => {
    'galleryUrl': galleryUrl,
    'pageCount': pageCount,
    'thumbnailsCountPerPage': thumbnailsCountPerPage,
    'pages': pages.map((LanGalleryManifestPage page) => page.toJson()).toList(),
  };

  factory LanGalleryManifest.fromJson(Map<String, dynamic> json) =>
      LanGalleryManifest(
        galleryUrl: json['galleryUrl'] as String? ?? '',
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        thumbnailsCountPerPage:
            (json['thumbnailsCountPerPage'] as num?)?.toInt() ?? 0,
        pages: (json['pages'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map page) => LanGalleryManifestPage.fromJson(
                Map<String, dynamic>.from(page),
              ),
            )
            .toList(growable: false),
      );
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
  final List<int>? coverBytes;
  final String? coverCachePath;

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
    this.coverBytes,
    this.coverCachePath,
  });

  LanSharedGallerySummary copyWith({
    String? deviceId,
    String? deviceName,
    String? coverUrl,
    List<int>? coverBytes,
    String? coverCachePath,
  }) => LanSharedGallerySummary(
    deviceId: deviceId ?? this.deviceId,
    deviceName: deviceName ?? this.deviceName,
    gid: gid,
    token: token,
    title: title,
    galleryUrl: galleryUrl,
    pageCount: pageCount,
    category: category,
    publishTime: publishTime,
    coverUrl: coverUrl ?? this.coverUrl,
    coverBytes: coverBytes ?? this.coverBytes,
    coverCachePath: coverCachePath ?? this.coverCachePath,
  );

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
    if (coverBytes != null) 'coverBytes': base64UrlEncode(coverBytes!),
  };

  factory LanSharedGallerySummary.fromJson(Map<String, dynamic> json) {
    List<int>? coverBytes;
    final String? encodedCover = json['coverBytes'] as String?;
    if (encodedCover != null && encodedCover.isNotEmpty) {
      try {
        coverBytes = base64Url.decode(base64Url.normalize(encodedCover));
      } on FormatException {
        coverBytes = null;
      }
    }
    return LanSharedGallerySummary(
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
      coverBytes: coverBytes,
    );
  }
}

/// A gallery a trusted peer asks this device to download on its behalf (LAN
/// remote download). Carries the metadata needed to seed the download task;
/// the host fills in its own group/settings and fetches details over its own
/// network connection.
class LanRemoteDownloadRequest {
  final int gid;
  final String galleryUrl;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String? uploader;
  final String publishTime;
  final List<String> tags;
  final bool downloadOriginalImage;

  const LanRemoteDownloadRequest({
    required this.gid,
    required this.galleryUrl,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    this.uploader,
    this.publishTime = '',
    this.tags = const <String>[],
    this.downloadOriginalImage = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gid': gid,
    'galleryUrl': galleryUrl,
    'token': token,
    'title': title,
    'category': category,
    'pageCount': pageCount,
    if (uploader != null) 'uploader': uploader,
    'publishTime': publishTime,
    'tags': tags,
    'downloadOriginalImage': downloadOriginalImage,
  };
}

class LanSharedGalleryPage {
  final String revision;
  final String? nextCursor;
  final List<LanSharedGallerySummary> galleries;
  final bool incremental;

  const LanSharedGalleryPage({
    required this.revision,
    required this.nextCursor,
    required this.galleries,
    this.incremental = false,
  });

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'nextCursor': nextCursor,
    'incremental': incremental,
    'galleries': galleries.map((gallery) => gallery.toJson()).toList(),
  };

  factory LanSharedGalleryPage.fromJson(Map<String, dynamic> json) =>
      LanSharedGalleryPage(
        revision: json['revision'] as String? ?? '',
        nextCursor: json['nextCursor'] as String?,
        incremental: json['incremental'] as bool? ?? false,
        galleries: (json['galleries'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (gallery) => LanSharedGallerySummary.fromJson(
                Map<String, dynamic>.from(gallery),
              ),
            )
            .toList(),
      );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
