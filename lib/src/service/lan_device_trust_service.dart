import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/lan_trust_dialog.dart';

import 'jh_service.dart';
import 'lan_compute_runtime.dart';
import 'lan_trust_repository.dart';
import 'lan_unified_state_service.dart';
import 'log.dart';
import 'path_service.dart';

LanDeviceTrustService lanDeviceTrustService = LanDeviceTrustService();

abstract interface class LanPeerSession {
  Future<void> get closed;

  /// Requests an image by its image-page URL. [galleryUrl] + [pageIndex] let
  /// the host fall back to its downloaded gallery when the image is not in the
  /// online image cache; both are optional (older peers omit them).
  Future<LanSharedImage?> requestImageCache(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
  });

  /// Lists the downloaded galleries the peer shares (needs the `downloads`
  /// permission on the host side).
  Future<List<LanSharedGallerySummary>> listDownloadedGalleries();

  Future<LanSharedGalleryPage> listDownloadedGalleriesPage({
    String? cursor,
    int limit = 50,
    String? knownRevision,
  }) async {
    // Keep older test doubles and third-party session adapters source
    // compatible while allowing v2 peers to provide a real cursor page.
    final List<LanSharedGallerySummary> galleries =
        await listDownloadedGalleries();
    return LanSharedGalleryPage(
      revision: '',
      nextCursor: null,
      galleries: galleries,
    );
  }

  /// Asks the peer to download a gallery on this device (LAN remote download).
  /// Returns whether the host accepted the request. Older peers and test
  /// doubles return false (not supported).
  Future<bool> requestDownloadGallery(LanRemoteDownloadRequest request) async =>
      false;

  /// Pushes one cache file to the peer so it can serve it later (the "move
  /// cache to server" flow). Returns whether the host stored it.
  Future<bool> pushCacheFile(String key, List<int> bytes) async => false;

  /// Sends this device's (merged) application history to the peer so the host
  /// ends up with both sides' histories after a pull. Returns whether the host
  /// imported it.
  Future<bool> pushHistory(LanUnifiedStatePayload payload) async => false;

  /// Sends this device's login state to the peer so an unlogged device adopts
  /// the account even when THIS device initiated the connection. Returns
  /// whether the peer imported it.
  Future<bool> pushLoginState(LanLoginStateSnapshot snapshot) async => false;

  Future<void> close();
}

abstract interface class LanGalleryManifestSession {
  Future<LanGalleryManifest?> fetchGalleryManifest(String galleryUrl);
}

/// Optional cache-upload surface that transfers the image-page index together
/// with the bytes. A bare cache key cannot later be resolved from the page URL.
abstract interface class LanIndexedCacheSession {
  Future<bool> pushIndexedCacheFile({
    required String key,
    required List<int> bytes,
    required String imagePageHref,
    required Map<String, dynamic> image,
  });
}

/// Optional v2 capability surface. Keeping this separate from the frozen
/// image/gallery session contract lets older test doubles and peers continue
/// to connect without widening the connection-state machine.
abstract interface class LanUnifiedStateSession {
  Future<LanLoginStateSnapshot?> requestLoginState();

  Future<LanUnifiedStatePayload?> requestApplicationHistory();
}

abstract interface class LanScheduledTask {
  void cancel();
}

abstract interface class LanTimerScheduler {
  LanScheduledTask schedule(Duration delay, void Function() callback);
}

class RealLanTimerScheduler implements LanTimerScheduler {
  const RealLanTimerScheduler();

  @override
  LanScheduledTask schedule(Duration delay, void Function() callback) =>
      _RealLanScheduledTask(Timer(delay, callback));
}

class _RealLanScheduledTask implements LanScheduledTask {
  final Timer _timer;

  const _RealLanScheduledTask(this._timer);

  @override
  void cancel() => _timer.cancel();
}

class LanSharedImage {
  final Map<String, dynamic> image;
  final List<int> bytes;

  const LanSharedImage({required this.image, required this.bytes});
}

abstract interface class LanPeerConnector {
  Future<LanPeerSession> connect({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  });
}

abstract interface class LanPeerPairer {
  Future<LanPairingExchange> requestPairing({
    required LanDiscoveredPeer peer,
    required String localDeviceId,
    required String localIdentityPublicKey,
    required String localIdentityFingerprint,
  });
}

class LanPairingExchange {
  final String remoteAccessToken;
  final String localInboundAccessToken;

  const LanPairingExchange({
    required this.remoteAccessToken,
    required this.localInboundAccessToken,
  });
}

class LanIncomingPairingRequest {
  final String requestId;
  final LanDiscoveredPeer peer;
  final DateTime requestedAt;

  const LanIncomingPairingRequest({
    required this.requestId,
    required this.peer,
    required this.requestedAt,
  });
}

class _PendingIncomingPairing {
  final LanIncomingPairingRequest request;
  final String remoteAccessToken;
  final Completer<LanPairingAcceptance?> completer;

  const _PendingIncomingPairing({
    required this.request,
    required this.remoteAccessToken,
    required this.completer,
  });
}

class LanDeviceTrustService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String devicesChangedId = 'lanTrustedDevices';
  static const String discoveredDevicesChangedId = 'lanDiscoveredDevices';
  static const String incomingPairingsChangedId = 'lanIncomingPairings';
  static const String identityChangedId = 'lanLocalIdentity';
  static const String trafficChangedId = 'lanTraffic';
  static const String connectionIdPrefix = 'lanConnection';
  static const Duration retryCooldown = Duration(seconds: 10);
  static const Duration maxRetryCooldown = Duration(minutes: 5);
  static const Duration peerRequestTimeout = Duration(seconds: 3);
  static const Duration incomingPairingTimeout = Duration(minutes: 2);

  final LanTrustRepository? _repositoryOverride;
  final LanUnifiedStateService? _unifiedStateOverride;
  final bool _registerWithGet;
  LanPeerConnector? _connector;
  LanPeerPairer? _pairer;
  StreamSubscription<LanDiscoveredPeer>? _discoverySubscription;
  final Map<String, LanPeerSession> _sessions = {};
  final Map<String, Future<void>> _connecting = {};
  final Map<String, LanScheduledTask> _retryTimers = {};
  final Map<String, int> _retryAttempts = {};
  final Map<String, LanConnectionSnapshot> _connectionStates = {};
  final Map<String, LanDiscoveredPeer> _discoveredPeers = {};
  final Map<String, DateTime> _discoveredAt = {};

  /// Devices already shown the global trust dialog this session, so a
  /// re-broadcast heartbeat does not re-prompt.
  final Set<String> _promptedDeviceIds = <String>{};
  /// Incoming pairing dialogs are serialized so simultaneous requests do not
  /// stack multiple modal routes on top of each other.
  final Set<String> _promptingIncomingPairingDeviceIds = <String>{};
  Future<void> _incomingPairingPromptQueue = Future<void>.value();
  final Map<String, _PendingIncomingPairing> _incomingPairings = {};
  final Set<String> _pairingDeviceIds = {};
  final Map<String, LanScheduledTask> _incomingPairingTimers = {};
  final Random _secureRandom;
  final LanTimerScheduler _timerScheduler;
  final DateTime Function() _clock;
  final Duration _retryDelay;
  final Duration _maxRetryDelay;
  final Duration _incomingPairingDelay;
  final Set<String> _disconnectRequested = {};
  final Future<LanTrustDecision?> Function(LanDiscoveredPeer peer)
      _trustDialogPresenter;
  bool _globalDialogReady = false;

  late LanTrustRepository _repository;
  SimpleKeyPair? _localIdentityKeyPair;
  bool isEnabled = false;
  String localDeviceId = '';
  String localDisplayName = '';
  String localIdentityPublicKey = '';
  String localIdentityFingerprint = '';
  final List<TrustedLanDevice> trustedDevices = [];
  int sentBytes = 0;
  int receivedBytes = 0;

  int get totalTransferredBytes => sentBytes + receivedBytes;

  LanDeviceTrustService({
    LanTrustRepository? repository,
    LanPeerConnector? connector,
    LanPeerPairer? pairer,
    LanUnifiedStateService? unifiedState,
    Random? secureRandom,
    LanTimerScheduler? timerScheduler,
    DateTime Function()? clock,
    Duration retryDelay = retryCooldown,
    Duration maxRetryDelay = maxRetryCooldown,
    Duration incomingPairingDelay = incomingPairingTimeout,
    Future<LanTrustDecision?> Function(LanDiscoveredPeer peer)?
    trustDialogPresenter,
    bool registerWithGet = true,
  }) : _repositoryOverride = repository,
       _unifiedStateOverride = unifiedState,
       _registerWithGet = registerWithGet,
       _connector = connector,
       _pairer = pairer,
       _secureRandom = secureRandom ?? Random.secure(),
       _timerScheduler = timerScheduler ?? const RealLanTimerScheduler(),
       _clock = clock ?? DateTime.now,
       _retryDelay = retryDelay,
       _maxRetryDelay = maxRetryDelay,
       _incomingPairingDelay = incomingPairingDelay,
       _trustDialogPresenter = trustDialogPresenter ?? showLanTrustDialog;

  @override
  List<JHLifeCircleBean> get initDependencies => [
    pathService,
    log,
    advancedSetting,
    userSetting,
  ];

  @override
  Future<void> doInitBean() async {
    _repository =
        _repositoryOverride ??
        FileLanTrustRepository(
          directory: pathService.jhLanDir,
          secretStore: EncryptedFileLanSecretStore(
            directory: pathService.jhLanSecretDir,
          ),
        );
    await _repository.init();
    localDeviceId = await _repository.ensureLocalDeviceId(_generateDeviceId);
    isEnabled = advancedSetting.enableLanSharing.value;
    if (isEnabled) {
      await _loadOrCreateLocalIdentity();
    }
    localDisplayName =
        await _repository.readLocalDeviceName() ?? _defaultDisplayName();
    trustedDevices
      ..clear()
      ..addAll(await _repository.loadDevices());
    if (_registerWithGet) {
      Get.put(this, permanent: true);
    }
    log.info(
      'LAN sharing initialized: deviceId=$localDeviceId '
      'name=$localDisplayName enabled=$isEnabled trusted=${trustedDevices.length}',
    );
  }

  @override
  Future<void> doAfterBeanReady() async {
    _globalDialogReady = true;
    for (final LanIncomingPairingRequest request in incomingPairingRequests) {
      _scheduleIncomingPairingPrompt(request);
    }
  }

  String connectionId(String deviceId) => '$connectionIdPrefix::$deviceId';

  LanConnectionSnapshot connectionFor(String deviceId) {
    if (_sessions.containsKey(deviceId)) {
      return const LanConnectionSnapshot(LanPeerConnectionState.connected);
    }
    if (_connecting.containsKey(deviceId)) {
      return const LanConnectionSnapshot(LanPeerConnectionState.connecting);
    }
    return _connectionStates[deviceId] ??
        const LanConnectionSnapshot(LanPeerConnectionState.offline);
  }

  DateTime get _now => _clock().toUtc();

  List<LanDiscoveredPeer> get discoveredPeers {
    final List<LanDiscoveredPeer> peers = _discoveredPeers.values.toList();
    peers.sort((a, b) => a.displayName.compareTo(b.displayName));
    return List.unmodifiable(peers);
  }

  List<LanIncomingPairingRequest> get incomingPairingRequests {
    final requests =
        _incomingPairings.values.map((entry) => entry.request).toList();
    requests.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return List.unmodifiable(requests);
  }

  bool isPairingWith(String deviceId) => _pairingDeviceIds.contains(deviceId);

  TrustedLanDevice? deviceById(String deviceId) {
    for (final TrustedLanDevice device in trustedDevices) {
      if (device.deviceId == deviceId) {
        return device;
      }
    }
    return null;
  }

  /// Returns the compute surface only for an already-authenticated session.
  /// The caller still supplies the task hashes and commit gate; permissions
  /// are checked again by the host runtime at request time.
  LanComputeSession? computeSession(String deviceId) {
    final LanPeerSession? session = _sessions[deviceId];
    return session is LanComputeSession ? session as LanComputeSession : null;
  }

  Future<LanSharedImage?> requestImageCache(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
    String? sourceDeviceId,
  }) async {
    final String? preferred =
        sourceDeviceId ?? advancedSetting.lanPreferredServerDeviceId.value;
    final Iterable<MapEntry<String, LanPeerSession>> entries =
        preferred == null || preferred.isEmpty
            ? _sessions.entries
            : _sessions.entries.where((entry) => entry.key == preferred);
    for (final MapEntry<String, LanPeerSession> entry in entries.toList()) {
      try {
        // No fixed outer deadline here: a chunked image transfer can legitimately
        // take far longer than peerRequestTimeout, and the session keeps the
        // request alive while chunks keep arriving (see LanPendingRequestRegistry
        // touch + the session's per-chunk extension).
        final LanSharedImage? image = await entry.value.requestImageCache(
          imagePageHref,
          galleryUrl: galleryUrl,
          pageIndex: pageIndex,
        );
        if (image != null) {
          return image;
        }
      } on Object catch (error) {
        log.warning('LAN image cache request failed: $error');
      }
    }
    return null;
  }

  Future<LanLoginStateSnapshot?> requestLoginState({
    String? sourceDeviceId,
  }) async {
    final List<LanPeerSession> entries = _sessions.entries
        .where((entry) => sourceDeviceId == null || entry.key == sourceDeviceId)
        .map((entry) => entry.value)
        .toList(growable: false);
    for (final LanPeerSession session in entries) {
      if (session is! LanUnifiedStateSession) {
        continue;
      }
      try {
        final LanUnifiedStateSession unified =
            session as LanUnifiedStateSession;
        final LanLoginStateSnapshot? snapshot = await unified
            .requestLoginState()
            .timeout(peerRequestTimeout, onTimeout: () => null);
        if (snapshot != null) {
          return snapshot;
        }
      } on Object catch (error) {
        _logSyncWarning('LAN login-state request failed: ${error.runtimeType}');
      }
    }
    return null;
  }

  Future<LanUnifiedStatePayload?> requestApplicationHistory({
    String? sourceDeviceId,
  }) async {
    final List<LanPeerSession> entries = _sessions.entries
        .where((entry) => sourceDeviceId == null || entry.key == sourceDeviceId)
        .map((entry) => entry.value)
        .toList(growable: false);
    for (final LanPeerSession session in entries) {
      if (session is! LanUnifiedStateSession) {
        continue;
      }
      try {
        final LanUnifiedStateSession unified =
            session as LanUnifiedStateSession;
        final LanUnifiedStatePayload? payload = await unified
            .requestApplicationHistory()
            .timeout(peerRequestTimeout, onTimeout: () => null);
        if (payload != null) {
          return payload;
        }
      } on Object catch (error) {
        _logSyncWarning('LAN history request failed: ${error.runtimeType}');
      }
    }
    return null;
  }

  /// Merges the downloaded-gallery lists from every connected trusted peer.
  /// A peer only appears here if it granted us the `downloads` permission.
  Future<List<LanSharedGallerySummary>> listDownloadedGalleries() async {
    final List<LanSharedGallerySummary> result = [];
    final String? preferred = advancedSetting.lanPreferredServerDeviceId.value;
    final Iterable<MapEntry<String, LanPeerSession>> entries =
        preferred == null || preferred.isEmpty
            ? _sessions.entries
            : _sessions.entries.where((entry) => entry.key == preferred);
    for (final MapEntry<String, LanPeerSession> entry in entries.toList()) {
      try {
        String? cursor;
        String? revision;
        do {
          final LanSharedGalleryPage page = await entry.value
              .listDownloadedGalleriesPage(
                cursor: cursor,
                knownRevision: revision,
              )
              .timeout(peerRequestTimeout);
          revision = page.revision;
          result.addAll(
            page.galleries.map(
              (gallery) => gallery.copyWith(deviceId: entry.key),
            ),
          );
          cursor = page.nextCursor;
        } while (cursor != null);
      } on Object catch (error) {
        log.warning('LAN gallery list request failed: $error');
      }
    }
    return result;
  }

  Future<LanGalleryManifest?> fetchGalleryManifest({
    required String galleryUrl,
    String? sourceDeviceId,
  }) async {
    final String? preferred =
        sourceDeviceId ?? advancedSetting.lanPreferredServerDeviceId.value;
    final Iterable<MapEntry<String, LanPeerSession>> entries =
        preferred == null || preferred.isEmpty
            ? _sessions.entries
            : _sessions.entries.where((entry) => entry.key == preferred);
    for (final MapEntry<String, LanPeerSession> entry in entries.toList()) {
      final LanPeerSession session = entry.value;
      if (session is! LanGalleryManifestSession) {
        continue;
      }
      final LanGalleryManifestSession manifestSession =
          session as LanGalleryManifestSession;
      try {
        final LanGalleryManifest? manifest = await manifestSession
            .fetchGalleryManifest(galleryUrl)
            .timeout(peerRequestTimeout);
        if (manifest != null) {
          return manifest;
        }
      } on Object catch (error) {
        log.warning('LAN gallery manifest request failed: $error');
      }
    }
    return null;
  }

  /// Asks a specific trusted peer to download a gallery on this device (LAN
  /// remote download). Returns whether the host accepted the request.
  Future<bool> requestDownloadGallery(
    String deviceId,
    LanRemoteDownloadRequest request,
  ) async {
    final LanPeerSession? session = _sessions[deviceId];
    if (session == null) {
      log.warning('LAN remote download request: no session for $deviceId');
      return false;
    }
    try {
      final bool accepted = await session.requestDownloadGallery(request);
      log.info(
        'LAN remote download ${accepted ? 'accepted' : 'rejected'} '
        'by $deviceId: gid ${request.gid}',
      );
      return accepted;
    } on Object catch (error) {
      log.warning('LAN remote download request failed for $deviceId: $error');
      return false;
    }
  }

  /// Whether any trusted device currently has a live session (used to gate
  /// LAN-only actions such as moving the cache to the server).
  bool get hasConnectedDevice => trustedDevices.any(
    (TrustedLanDevice device) =>
        connectionFor(device.deviceId).state ==
        LanPeerConnectionState.connected,
  );

  /// Pushes one cache file to the preferred server (or any connected peer).
  /// Returns whether at least one host stored it.
  Future<bool> pushCacheFileToServer(String key, List<int> bytes) async {
    final String? preferred = advancedSetting.lanPreferredServerDeviceId.value;
    final Iterable<MapEntry<String, LanPeerSession>> entries =
        preferred == null || preferred.isEmpty
            ? _sessions.entries
            : _sessions.entries.where((entry) => entry.key == preferred);
    for (final MapEntry<String, LanPeerSession> entry in entries.toList()) {
      try {
        final bool ok = await entry.value.pushCacheFile(key, bytes);
        if (ok) {
          return true;
        }
      } on Object catch (error) {
        log.warning('LAN push cache failed for ${entry.key}: $error');
      }
    }
    return false;
  }

  /// Pushes a cache file and the page-to-image metadata required for the host
  /// to serve it later. Peers without the indexed-upload capability are
  /// skipped instead of reporting a successful but unreadable migration.
  Future<bool> pushIndexedCacheFileToServer({
    required String key,
    required List<int> bytes,
    required String imagePageHref,
    required Map<String, dynamic> image,
  }) async {
    final String? preferred = advancedSetting.lanPreferredServerDeviceId.value;
    final Iterable<MapEntry<String, LanPeerSession>> entries =
        preferred == null || preferred.isEmpty
        ? _sessions.entries
        : _sessions.entries.where((entry) => entry.key == preferred);
    for (final MapEntry<String, LanPeerSession> entry in entries.toList()) {
      final LanPeerSession session = entry.value;
      if (session is! LanIndexedCacheSession) {
        continue;
      }
      try {
        final bool ok = await (session as LanIndexedCacheSession)
            .pushIndexedCacheFile(
              key: key,
              bytes: bytes,
              imagePageHref: imagePageHref,
              image: image,
            );
        if (ok) {
          return true;
        }
      } on Object catch (error) {
        log.warning('LAN indexed cache push failed for ${entry.key}: $error');
      }
    }
    return false;
  }

  void attachConnector(LanPeerConnector connector) {
    _connector = connector;
  }

  void attachPairer(LanPeerPairer pairer) {
    _pairer = pairer;
  }

  Future<void> setEnabled(bool value) async {
    if (isEnabled == value) {
      return;
    }
    if (value) {
      await _loadOrCreateLocalIdentity();
      sentBytes = 0;
      receivedBytes = 0;
      isEnabled = true;
    } else {
      isEnabled = false;
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      for (final String deviceId in _sessions.keys.toList()) {
        await disconnect(deviceId);
      }
      _disconnectRequested.addAll(_connecting.keys);
      for (final LanScheduledTask timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
      _retryAttempts.clear();
      _discoveredPeers.clear();
      _discoveredAt.clear();
      for (final _PendingIncomingPairing pending in _incomingPairings.values) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete(null);
        }
      }
      for (final LanScheduledTask timer in _incomingPairingTimers.values) {
        timer.cancel();
      }
      _incomingPairingTimers.clear();
      _incomingPairings.clear();
      _promptingIncomingPairingDeviceIds.clear();
    }
    update([
      identityChangedId,
      trafficChangedId,
      discoveredDevicesChangedId,
      incomingPairingsChangedId,
    ]);
  }

  /// Throttle for the traffic tile: byte counters are updated on every network
  /// chunk, but the tile must not rebuild hundreds of times per second while a
  /// transfer is active. One coalesced update at most every 500 ms keeps the
  /// settings page smooth during heavy sharing.
  Timer? _trafficUpdateTimer;

  void recordTrafficSent(int bytes) {
    if (bytes <= 0) {
      return;
    }
    sentBytes += bytes;
    _scheduleTrafficUpdate();
  }

  void recordTrafficReceived(int bytes) {
    if (bytes <= 0) {
      return;
    }
    receivedBytes += bytes;
    _scheduleTrafficUpdate();
  }

  void _scheduleTrafficUpdate() {
    _trafficUpdateTimer ??= Timer(const Duration(milliseconds: 500), () {
      _trafficUpdateTimer = null;
      update([trafficChangedId]);
    });
  }

  Future<void> observeDiscovery(Stream<LanDiscoveredPeer> peers) async {
    await _discoverySubscription?.cancel();
    if (!isEnabled) {
      return;
    }
    _discoverySubscription = peers.listen(
      (peer) => unawaited(handlePeerDiscovered(peer)),
      onError: (Object error, StackTrace stack) {
        log.warning('LAN discovery stream failed: $error');
        log.trace(stack);
      },
    );
  }

  Future<LanPairingAcceptance> completePairing({
    required LanDiscoveredPeer peer,
    required String remoteAccessToken,
    required Set<LanSharePermission> permissions,
    bool autoConnect = true,
    String? localInboundAccessToken,
  }) async {
    if (!isEnabled) {
      throw StateError('LAN sharing is disabled');
    }
    await _loadOrCreateLocalIdentity();
    _validatePeer(peer);
    final DateTime now = _now;
    final String inboundToken =
        localInboundAccessToken ?? _generateAccessToken();
    final TrustedLanDevice device = TrustedLanDevice(
      deviceId: peer.deviceId,
      displayName:
          peer.displayName.trim().isEmpty
              ? peer.deviceId
              : peer.displayName.trim(),
      identityPublicKey: peer.identityPublicKey,
      identityFingerprint: peer.identityFingerprint.toLowerCase(),
      permissions: Set.unmodifiable(permissions),
      autoConnect: autoConnect,
      pairedAt: now,
      lastSeenAt: now,
      protocolVersion: peer.protocolVersion,
    );
    await _repository.saveDevice(
      device,
      remoteAccessToken: remoteAccessToken,
      inboundAccessToken: inboundToken,
    );
    _replaceDevice(device);
    log.info(
      'LAN paired with ${peer.deviceId}: permissions='
      '${permissions.map((p) => p.name).join(',')} '
      'autoConnect=$autoConnect',
    );
    return LanPairingAcceptance(
      localDeviceId: localDeviceId,
      localIdentityPublicKey: localIdentityPublicKey,
      localIdentityFingerprint: localIdentityFingerprint,
      accessTokenForRemote: inboundToken,
    );
  }

  Future<LanPairingAcceptance> trustDiscoveredDevice({
    required String deviceId,
    required Set<LanSharePermission> permissions,
    bool autoConnect = true,
  }) async {
    if (!isEnabled) {
      throw StateError('LAN sharing is disabled');
    }
    final LanDiscoveredPeer? peer = _discoveredPeers[deviceId];
    if (peer == null) {
      throw StateError('LAN device is no longer available');
    }
    final LanPeerPairer? pairer = _pairer;
    if (pairer == null) {
      throw StateError('LAN pairing transport is unavailable');
    }
    if (!_pairingDeviceIds.add(deviceId)) {
      throw StateError('LAN pairing is already in progress');
    }
    update([discoveredDevicesChangedId]);
    try {
      await _loadOrCreateLocalIdentity();
      final LanPairingExchange exchange = await pairer.requestPairing(
        peer: peer,
        localDeviceId: localDeviceId,
        localIdentityPublicKey: localIdentityPublicKey,
        localIdentityFingerprint: localIdentityFingerprint,
      );
      final LanPairingAcceptance acceptance = await completePairing(
        peer: peer,
        remoteAccessToken: exchange.remoteAccessToken,
        permissions: permissions,
        autoConnect: autoConnect,
        localInboundAccessToken: exchange.localInboundAccessToken,
      );
      _discoveredPeers.remove(deviceId);
      _discoveredAt.remove(deviceId);
      if (autoConnect && _connector != null) {
        await handlePeerDiscovered(peer);
      }
      return acceptance;
    } finally {
      _pairingDeviceIds.remove(deviceId);
      update([discoveredDevicesChangedId]);
    }
  }

  Future<LanPairingAcceptance?> requestIncomingPairingApproval({
    required LanDiscoveredPeer peer,
    required String remoteAccessToken,
  }) async {
    if (!isEnabled) {
      return null;
    }
    _validatePeer(peer);
    if (!_isValidAccessToken(remoteAccessToken)) {
      throw const FormatException('Invalid LAN access token');
    }
    // Active broadcast: a one-sided trust on the initiator should also
    // establish trust here, so the pairing completes without a manual accept
    // on this device (the user already opted into auto-pairing).
    if (advancedSetting.lanActiveBroadcast.value) {
      log.info(
        'LAN active broadcast auto-accepting pairing from ${peer.deviceId} '
        '(${peer.displayName})',
      );
      return completePairing(
        peer: peer,
        remoteAccessToken: remoteAccessToken,
        permissions: _defaultPairPermissions,
        autoConnect: true,
      );
    }
    final String requestId = _randomBase64Url(18);
    final Completer<LanPairingAcceptance?> completer = Completer();
    final LanIncomingPairingRequest request = LanIncomingPairingRequest(
      requestId: requestId,
      peer: peer,
      requestedAt: _now,
    );
    final _PendingIncomingPairing? previous = _incomingPairings.remove(
      peer.deviceId,
    );
    _incomingPairingTimers.remove(peer.deviceId)?.cancel();
    if (previous != null && !previous.completer.isCompleted) {
      previous.completer.complete(null);
    }
    while (_incomingPairings.length >= 16) {
      final _PendingIncomingPairing oldest = _incomingPairings.values.reduce(
        (a, b) => a.request.requestedAt.isBefore(b.request.requestedAt) ? a : b,
      );
      _incomingPairings.remove(oldest.request.peer.deviceId);
      _incomingPairingTimers.remove(oldest.request.peer.deviceId)?.cancel();
      if (!oldest.completer.isCompleted) {
        oldest.completer.complete(null);
      }
    }
    _incomingPairings[peer.deviceId] = _PendingIncomingPairing(
      request: request,
      remoteAccessToken: remoteAccessToken,
      completer: completer,
    );
    _incomingPairingTimers[peer.deviceId]?.cancel();
    _incomingPairingTimers[peer
        .deviceId] = _timerScheduler.schedule(_incomingPairingDelay, () {
      final _PendingIncomingPairing? current = _incomingPairings[peer.deviceId];
      if (!identical(current?.completer, completer)) {
        return;
      }
      _incomingPairings.remove(peer.deviceId);
      _incomingPairingTimers.remove(peer.deviceId);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      update([incomingPairingsChangedId]);
    });
    update([incomingPairingsChangedId]);
    _scheduleIncomingPairingPrompt(request);
    try {
      return await completer.future;
    } finally {
      _incomingPairingTimers.remove(peer.deviceId)?.cancel();
      if (identical(_incomingPairings[peer.deviceId]?.completer, completer)) {
        _incomingPairings.remove(peer.deviceId);
        update([incomingPairingsChangedId]);
      }
    }
  }

  Future<void> acceptIncomingPairing({
    required String deviceId,
    required Set<LanSharePermission> permissions,
    bool autoConnect = true,
  }) async {
    final _PendingIncomingPairing? pending = _incomingPairings[deviceId];
    if (pending == null || pending.completer.isCompleted) {
      return;
    }
    try {
      final LanPairingAcceptance acceptance = await completePairing(
        peer: pending.request.peer,
        remoteAccessToken: pending.remoteAccessToken,
        permissions: permissions,
        autoConnect: autoConnect,
      );
      pending.completer.complete(acceptance);
    } on Object catch (error, stack) {
      pending.completer.completeError(error, stack);
      Error.throwWithStackTrace(error, stack);
    }
  }

  void declineIncomingPairing(String deviceId) {
    final _PendingIncomingPairing? pending = _incomingPairings.remove(deviceId);
    _incomingPairingTimers.remove(deviceId)?.cancel();
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(null);
    }
    update([incomingPairingsChangedId]);
  }

  void ignoreDiscoveredDevice(String deviceId) {
    _discoveredPeers.remove(deviceId);
    _discoveredAt.remove(deviceId);
    // A later broadcast may prompt again instead of being silently dropped.
    _promptedDeviceIds.remove(deviceId);
    update([discoveredDevicesChangedId]);
  }

  Future<void> setAutoConnect(String deviceId, bool value) async {
    final TrustedLanDevice? existing = deviceById(deviceId);
    if (existing == null) {
      return;
    }
    final TrustedLanDevice updated = existing.copyWith(autoConnect: value);
    await _repository.updateDevice(updated);
    _replaceDevice(updated);
    if (!value) {
      _retryTimers.remove(deviceId)?.cancel();
      _retryAttempts.remove(deviceId);
      await disconnect(deviceId);
    }
  }

  /// Updates only the granted capability set. Revoking a capability closes
  /// the current session so no already-negotiated request can start another
  /// sync; a future reconnect observes the persisted permission set.
  Future<void> setPermissions(
    String deviceId,
    Set<LanSharePermission> permissions,
  ) async {
    final TrustedLanDevice? existing = deviceById(deviceId);
    if (existing == null) {
      return;
    }
    final TrustedLanDevice updated = existing.copyWith(
      permissions: Set.unmodifiable(permissions),
    );
    await _repository.updateDevice(updated);
    _replaceDevice(updated);
    log.info(
      'LAN permissions updated for $deviceId: '
      '${permissions.map((p) => p.name).join(',')}',
    );
    final LanDiscoveredPeer? peer = _discoveredPeers[deviceId];
    final Future<void>? inFlightConnection = _connecting[deviceId];
    await disconnect(deviceId);
    // A permission change closes the authenticated session so the new grant is
    // enforced immediately. Reconnect the already-discovered auto-connect peer
    // instead of waiting for another mDNS resolve event that may never arrive.
    await inFlightConnection;
    if (peer != null &&
        updated.autoConnect &&
        isEnabled &&
        _connector != null) {
      await handlePeerDiscovered(peer);
    }
    update([devicesChangedId, connectionId(deviceId)]);
  }

  Future<void> revokeTrust(String deviceId) async {
    await disconnect(deviceId);
    await _repository.revokeDevice(deviceId);
    trustedDevices.removeWhere((device) => device.deviceId == deviceId);
    _connectionStates.remove(deviceId);
    _retryTimers.remove(deviceId)?.cancel();
    _retryAttempts.remove(deviceId);
    update([devicesChangedId, connectionId(deviceId)]);
  }

  Future<bool> authenticateInbound({
    required String deviceId,
    required String identityFingerprint,
    required String presentedToken,
    required List<int> challenge,
    required List<int> challengeSignature,
  }) async {
    final TrustedLanDevice? device = deviceById(deviceId);
    if (device == null ||
        !_constantTimeEquals(
          device.identityFingerprint,
          identityFingerprint.toLowerCase(),
        )) {
      return false;
    }
    final LanDeviceCredentials? credentials = await _repository.credentialsFor(
      deviceId,
    );
    return credentials != null &&
        _constantTimeEquals(credentials.inboundAccessToken, presentedToken) &&
        await verifyPeerChallenge(
          deviceId: deviceId,
          challenge: challenge,
          signature: challengeSignature,
        );
  }

  Future<List<int>> signChallenge(List<int> challenge) async {
    await _loadOrCreateLocalIdentity();
    _validateChallenge(challenge);
    final Signature signature = await Ed25519().sign(
      challenge,
      keyPair: _localIdentityKeyPair!,
    );
    return signature.bytes;
  }

  Future<bool> verifyPeerChallenge({
    required String deviceId,
    required List<int> challenge,
    required List<int> signature,
  }) async {
    final TrustedLanDevice? device = deviceById(deviceId);
    if (device == null || signature.length != 64) {
      return false;
    }
    try {
      _validateChallenge(challenge);
      final SimplePublicKey publicKey = SimplePublicKey(
        base64Url.decode(base64Url.normalize(device.identityPublicKey)),
        type: KeyPairType.ed25519,
      );
      return Ed25519().verify(
        challenge,
        signature: Signature(signature, publicKey: publicKey),
      );
    } on Object {
      return false;
    }
  }

  Future<void> handlePeerDiscovered(LanDiscoveredPeer peer) async {
    if (!isEnabled) {
      return;
    }
    try {
      _validatePeer(peer);
    } on FormatException {
      if (deviceById(peer.deviceId) != null) {
        _setConnection(
          peer.deviceId,
          const LanConnectionSnapshot(
            LanPeerConnectionState.identityMismatch,
            errorMessage: 'LAN_IDENTITY_MISMATCH',
          ),
        );
      }
      return;
    }
    _rememberDiscoveredPeer(peer);
    final TrustedLanDevice? device = deviceById(peer.deviceId);
    if (device == null) {
      log.debug(
        'LAN peer discovered but not trusted: ${peer.deviceId} '
        '(${peer.displayName} ${peer.host}:${peer.port})',
      );
      if (advancedSetting.lanActiveBroadcast.value) {
        unawaited(_autoPairDiscovered(peer));
      } else if (_promptedDeviceIds.add(peer.deviceId)) {
        // Surface a newly broadcast device everywhere, not just in the LAN
        // sharing page.
        unawaited(_promptTrust(peer));
      }
      return;
    }
    if (!_constantTimeEquals(
          device.identityFingerprint,
          peer.identityFingerprint.toLowerCase(),
        ) ||
        !_constantTimeEquals(
          device.identityPublicKey,
          peer.identityPublicKey,
        )) {
      _setConnection(
        peer.deviceId,
        const LanConnectionSnapshot(
          LanPeerConnectionState.identityMismatch,
          errorMessage: 'LAN_IDENTITY_MISMATCH',
        ),
      );
      return;
    }

    final DateTime now = _now;
    final TrustedLanDevice seen = device.copyWith(
      displayName:
          peer.displayName.trim().isEmpty
              ? device.displayName
              : peer.displayName.trim(),
      lastSeenAt: now,
      protocolVersion: peer.protocolVersion,
    );
    // A routine heartbeat only bumps lastSeenAt — update the list silently so
    // the page does not rebuild the whole trusted-devices section on every
    // broadcast; the connection-tile refresh below re-reads the list. A change
    // the user can see (name / protocol) still triggers the full rebuild.
    _replaceDevice(
      seen,
      notify:
          seen.displayName != device.displayName ||
          seen.protocolVersion != device.protocolVersion,
    );
    if (now.difference(device.lastSeenAt).abs() > const Duration(minutes: 5)) {
      await _repository.updateDevice(seen);
    }
    if (!seen.autoConnect ||
        _connector == null ||
        _sessions.containsKey(peer.deviceId) ||
        _connecting.containsKey(peer.deviceId)) {
      if (seen.autoConnect &&
          _connector != null &&
          !_sessions.containsKey(peer.deviceId)) {
        log.debug(
          'LAN peer ${peer.deviceId} auto-connect held: '
          'connecting=${_connecting.containsKey(peer.deviceId)} '
          'retryPending=${_retryTimers.containsKey(peer.deviceId)}',
        );
      }
      return;
    }
    if (_retryTimers.containsKey(peer.deviceId)) {
      return;
    }
    log.info(
      'LAN auto-connecting to trusted peer: ${peer.deviceId} '
      '(${peer.displayName} ${peer.host}:${peer.port})',
    );
    await _connecting.putIfAbsent(
      peer.deviceId,
      () => _connectTrustedPeer(peer, seen),
    );
  }

  /// Cooldown (per device) for the active-broadcast auto-pairing, so repeated
  /// heartbeats from a peer that declined do not spam pairing requests.
  final Map<String, DateTime> _autoPairCooldown = {};

  static const Set<LanSharePermission> _defaultPairPermissions = {
    LanSharePermission.downloads,
    LanSharePermission.imageCache,
    LanSharePermission.translationResults,
    LanSharePermission.loginState,
    LanSharePermission.applicationHistory,
  };

  /// Reviews an untrusted discovered device with the global trust dialog, so
  /// a newly broadcast device is surfaced everywhere instead of only in the
  /// LAN sharing page. One prompt per session per device; ignoring a device
  /// lets a later broadcast prompt again.
  Future<void> _promptTrust(LanDiscoveredPeer peer) async {
    final LanTrustDecision? decision = await _trustDialogPresenter(peer);
    if (decision == null) {
      return;
    }
    if (!decision.trust) {
      ignoreDiscoveredDevice(peer.deviceId);
      return;
    }
    try {
      await trustDiscoveredDevice(
        deviceId: peer.deviceId,
        permissions: decision.permissions,
        autoConnect: decision.autoConnect,
      );
      toast('lanTrustGranted'.tr);
    } on Object {
      toast('lanPairingFailed'.tr);
    }
  }

  /// Reviews an incoming pairing request from the global navigator. The
  /// request remains visible in LAN settings when the dialog is dismissed, so
  /// the settings page remains a reliable fallback for a missed prompt.
  void _scheduleIncomingPairingPrompt(LanIncomingPairingRequest request) {
    if (!_globalDialogReady ||
        !_promptingIncomingPairingDeviceIds.add(request.peer.deviceId)) {
      return;
    }
    _incomingPairingPromptQueue = _incomingPairingPromptQueue.then<void>((_) async {
      try {
        final LanTrustDecision? decision = await _trustDialogPresenter(
          request.peer,
        );
        final _PendingIncomingPairing? pending =
            _incomingPairings[request.peer.deviceId];
        if (pending == null ||
            pending.request.requestId != request.requestId ||
            decision == null) {
          return;
        }
        if (!decision.trust) {
          declineIncomingPairing(request.peer.deviceId);
          return;
        }
        try {
          await acceptIncomingPairing(
            deviceId: request.peer.deviceId,
            permissions: decision.permissions,
            autoConnect: decision.autoConnect,
          );
          toast('lanTrustGranted'.tr);
        } on Object catch (error, stack) {
          log.warning(
            'LAN incoming pairing approval failed for '
            '${request.peer.deviceId}: $error',
          );
          log.trace(stack);
          toast('lanPairingFailed'.tr);
        }
      } on Object catch (error, stack) {
        // A dialog cannot be shown during app teardown or before the root
        // navigator is ready. Keep the request in the settings-page queue.
        log.warning('LAN incoming pairing prompt failed: $error');
        log.trace(stack);
      } finally {
        _promptingIncomingPairingDeviceIds.remove(request.peer.deviceId);
        final _PendingIncomingPairing? current =
            _incomingPairings[request.peer.deviceId];
        if (current != null &&
            current.request.requestId != request.requestId) {
          _scheduleIncomingPairingPrompt(current.request);
        }
      }
    });
  }

  /// Active-broadcast mode: proactively sends a pairing request to a
  /// newly-discovered, untrusted device. The peer still decides whether to
  /// accept; a declined or failed attempt is retried after a cooldown.
  Future<void> _autoPairDiscovered(LanDiscoveredPeer peer) async {
    final DateTime now = _now;
    final DateTime? last = _autoPairCooldown[peer.deviceId];
    if (last != null &&
        now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _autoPairCooldown[peer.deviceId] = now;
    try {
      log.info(
        'LAN active broadcast: sending pairing request to new device '
        '${peer.deviceId} (${peer.displayName})',
      );
      await trustDiscoveredDevice(
        deviceId: peer.deviceId,
        permissions: _defaultPairPermissions,
        autoConnect: true,
      );
    } on Object catch (error) {
      log.warning(
        'LAN active broadcast pairing failed for ${peer.deviceId}: $error',
      );
    }
  }

  Future<void> disconnect(String deviceId) async {
    _retryTimers.remove(deviceId)?.cancel();
    _retryAttempts.remove(deviceId);
    if (_connecting.containsKey(deviceId)) {
      _disconnectRequested.add(deviceId);
    } else {
      _disconnectRequested.remove(deviceId);
    }
    final LanPeerSession? session = _sessions.remove(deviceId);
    log.info('LAN disconnect requested: $deviceId');
    await session?.close();
    _setConnection(
      deviceId,
      const LanConnectionSnapshot(LanPeerConnectionState.offline),
    );
  }

  Future<void> _connectTrustedPeer(
    LanDiscoveredPeer peer,
    TrustedLanDevice device,
  ) async {
    _setConnection(
      peer.deviceId,
      const LanConnectionSnapshot(LanPeerConnectionState.connecting),
    );
    try {
      final LanDeviceCredentials? credentials = await _repository
          .credentialsFor(peer.deviceId);
      if (credentials == null) {
        throw StateError('LAN credentials are unavailable');
      }
      final LanPeerSession session = await _connector!.connect(
        peer: peer,
        accessToken: credentials.remoteAccessToken,
        expectedIdentityPublicKey: device.identityPublicKey,
        expectedIdentityFingerprint: device.identityFingerprint,
      );
      if (_disconnectRequested.remove(peer.deviceId)) {
        await session.close();
        _setConnection(
          peer.deviceId,
          const LanConnectionSnapshot(LanPeerConnectionState.offline),
        );
        return;
      }
      _sessions[peer.deviceId] = session;
      _retryTimers.remove(peer.deviceId)?.cancel();
      _retryAttempts.remove(peer.deviceId);
      final DateTime connectedAt = _now;
      final TrustedLanDevice connected = device.copyWith(
        lastSeenAt: connectedAt,
        lastConnectedAt: connectedAt,
      );
      await _repository.updateDevice(connected);
      _replaceDevice(connected);
      _setConnection(
        peer.deviceId,
        const LanConnectionSnapshot(LanPeerConnectionState.connected),
      );
      log.info(
        'LAN connected to trusted peer: ${peer.deviceId} '
        '(${peer.displayName} ${peer.host}:${peer.port})',
      );
      // Once the trusted session is live, pull the peer's login state and
      // application history so an unlogged device can adopt the account and
      // merge reading records. Fire-and-forget: connection setup must not
      // block on the sync, and each capability is imported independently.
      unawaited(_syncUnifiedStateFrom(peer.deviceId));
      unawaited(
        session.closed.whenComplete(() {
          if (identical(_sessions[peer.deviceId], session)) {
            _sessions.remove(peer.deviceId);
            _setConnection(
              peer.deviceId,
              const LanConnectionSnapshot(
                LanPeerConnectionState.failed,
                errorMessage: 'LAN_SESSION_CLOSED',
              ),
            );
            log.warning(
              'LAN session to peer closed: ${peer.deviceId} '
              '(LAN_SESSION_CLOSED)',
            );
            _scheduleRetry(peer.deviceId);
          }
        }),
      );
    } on Object catch (error, stack) {
      final bool cancelled =
          _disconnectRequested.remove(peer.deviceId) || !isEnabled;
      _setConnection(
        peer.deviceId,
        cancelled
            ? const LanConnectionSnapshot(LanPeerConnectionState.offline)
            : LanConnectionSnapshot(
              LanPeerConnectionState.failed,
              errorMessage: error.toString(),
            ),
      );
      if (!cancelled) {
        _scheduleRetry(peer.deviceId);
      }
      log.warning(
        'LAN auto-connect to trusted peer failed: ${peer.deviceId}: $error',
      );
      log.trace(stack);
    } finally {
      _connecting.remove(peer.deviceId);
    }
  }

  /// Pulls a newly-connected peer's login state and application history and
  /// applies them locally, so an unlogged device can adopt the peer's account
  /// and merge its reading records. Login state is only adopted when this
  /// device is not already logged in — a logged-in device must not clobber its
  /// own session with the peer's cookies on every reconnect. Each capability
  /// is requested and imported independently: the peer's server still enforces
  /// its own permission grant, and a failure in one flow must not drop the
  /// other.
  Future<void> _syncUnifiedStateFrom(String deviceId) async {
    final LanPeerSession? session = _sessions[deviceId];
    if (session is! LanUnifiedStateSession) {
      return;
    }
    final LanUnifiedStateService unifiedState =
        _unifiedStateOverride ?? lanUnifiedStateService;
    if (!userSetting.hasLoggedIn()) {
      try {
        final LanLoginStateSnapshot? snapshot = await requestLoginState(
          sourceDeviceId: deviceId,
        );
        if (snapshot == null) {
          _logSyncWarning(
            'LAN login-state sync: peer $deviceId returned no snapshot '
            '(permission denied, peer not logged in, or no response)',
          );
        } else {
          _logSyncInfo('LAN login-state sync: received snapshot from $deviceId');
          final LanLoginImportResult result = await unifiedState
              .importLoginState(snapshot);
          _logSyncInfo(
            'LAN login-state sync: import ${result.outcome.name} '
            'from $deviceId${result.failureReason == null ? '' : ' (${result.failureReason})'}',
          );
        }
      } on Object catch (error) {
        _logSyncWarning('LAN login-state sync failed: $error');
      }
    } else {
      // This device is logged in: push its login state to the peer so an
      // unlogged device adopts the account even when this device initiated
      // the connection (the sync must work in both directions).
      final bool pushed = await _pushLoginStateTo(deviceId, unifiedState);
      _logSyncInfo(
        pushed
            ? 'LAN login-state sync: pushed login state to $deviceId'
            : 'LAN login-state sync: login push to $deviceId not supported',
      );
    }
    try {
      final LanUnifiedStatePayload? payload = await requestApplicationHistory(
        sourceDeviceId: deviceId,
      );
      if (payload == null) {
        _logSyncWarning(
          'LAN history sync: peer $deviceId returned no payload '
          '(permission denied or no response)',
        );
      } else {
        _logSyncInfo(
          'LAN history sync: received ${payload.records.length} records '
          'from $deviceId',
        );
        final int imported = await unifiedState.importHistory(payload);
        _logSyncInfo(
          'LAN history sync: imported $imported records from $deviceId',
        );
        // Push the merged history back so the peer ALSO ends up with both
        // sides' histories — the sync must be bidirectional even though only
        // the connecting device pulls.
        final bool pushed = await _pushHistoryBack(deviceId, unifiedState);
        _logSyncInfo(
          pushed
              ? 'LAN history sync: pushed merged history back to $deviceId'
              : 'LAN history sync: push-back to $deviceId not supported',
        );
      }
    } on Object catch (error) {
      _logSyncWarning('LAN history sync failed: $error');
    }
  }

  /// Exports this device's current (merged) application history and sends it
  /// to [deviceId] so the host imports both sides' records.
  Future<bool> _pushHistoryBack(
    String deviceId,
    LanUnifiedStateService unifiedState,
  ) async {
    final LanPeerSession? session = _sessions[deviceId];
    if (session == null) {
      return false;
    }
    try {
      final LanUnifiedStatePayload merged = await unifiedState.exportHistory(
        sourceDeviceId: localDeviceId,
      );
      return await session.pushHistory(merged);
    } on Object catch (error) {
      _logSyncWarning('LAN history push-back failed: $error');
      return false;
    }
  }

  /// Exports this device's login state and sends it to [deviceId] so an
  /// unlogged peer adopts the account.
  Future<bool> _pushLoginStateTo(
    String deviceId,
    LanUnifiedStateService unifiedState,
  ) async {
    final LanPeerSession? session = _sessions[deviceId];
    if (session == null) {
      return false;
    }
    try {
      final LanLoginStateSnapshot? snapshot = await unifiedState.exportLoginState(
        sourceDeviceId: localDeviceId,
      );
      if (snapshot == null) {
        return false;
      }
      return await session.pushLoginState(snapshot);
    } on Object catch (error) {
      _logSyncWarning('LAN login-state push failed: $error');
      return false;
    }
  }

  /// Logs a unified-state sync warning without letting the logger take down
  /// the fire-and-forget sync path — the log service may not be initialized
  /// yet when the first LAN connection completes during startup. `log.warning`
  /// is async, so its failure must be caught on the returned future.
  void _logSyncWarning(String message) {
    unawaited(log.warning(message).catchError((Object _) {
      // Logging is best-effort here; swallow so the sync can continue.
    }));
  }

  /// Like [_logSyncWarning], for informational sync messages.
  void _logSyncInfo(String message) {
    unawaited(log.info(message).catchError((Object _) {
      // Logging is best-effort here; swallow so the sync can continue.
    }));
  }

  void _scheduleRetry(String deviceId) {
    final TrustedLanDevice? device = deviceById(deviceId);
    if (!isEnabled || device == null || !device.autoConnect) {
      return;
    }
    if (_retryTimers.containsKey(deviceId)) {
      return;
    }
    final int attempt = (_retryAttempts[deviceId] ?? 0) + 1;
    _retryAttempts[deviceId] = attempt;
    _retryTimers[deviceId] = _timerScheduler.schedule(
      _retryDelayFor(attempt),
      () {
        _retryTimers.remove(deviceId);
        final LanDiscoveredPeer? peer = _discoveredPeers[deviceId];
        final TrustedLanDevice? device = deviceById(deviceId);
        if (!isEnabled ||
            peer == null ||
            device == null ||
            !device.autoConnect ||
            _connector == null ||
            _sessions.containsKey(deviceId) ||
            _connecting.containsKey(deviceId)) {
          return;
        }
        unawaited(handlePeerDiscovered(peer));
      },
    );
  }

  Duration _retryDelayFor(int attempt) {
    Duration delay = _retryDelay;
    for (int index = 1; index < attempt && delay < _maxRetryDelay; index++) {
      final Duration doubled = delay * 2;
      delay = doubled > _maxRetryDelay ? _maxRetryDelay : doubled;
    }
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }

  void _replaceDevice(TrustedLanDevice device, {bool notify = true}) {
    trustedDevices.removeWhere((entry) => entry.deviceId == device.deviceId);
    trustedDevices.add(device);
    trustedDevices.sort((a, b) => a.displayName.compareTo(b.displayName));
    if (notify) {
      update([devicesChangedId]);
    }
  }

  void _setConnection(String deviceId, LanConnectionSnapshot snapshot) {
    _connectionStates[deviceId] = snapshot;
    update([connectionId(deviceId)]);
  }

  String _generateDeviceId() => 'jht_${_randomBase64Url(24)}';

  String _generateAccessToken() => _randomBase64Url(32);

  Future<void> _loadOrCreateLocalIdentity() async {
    if (_localIdentityKeyPair != null) {
      return;
    }
    final Ed25519 algorithm = Ed25519();
    String? encodedSeed = await _repository.readLocalIdentitySeed();
    List<int>? seed;
    if (encodedSeed != null) {
      try {
        final List<int> decoded = base64Url.decode(
          base64Url.normalize(encodedSeed),
        );
        if (decoded.length == 32) {
          seed = decoded;
        }
      } on FormatException {
        // Replace damaged key material with a new identity.
      }
    }
    if (seed == null) {
      final SimpleKeyPair generated = await algorithm.newKeyPair();
      seed = List<int>.from(await generated.extractPrivateKeyBytes());
      encodedSeed = base64UrlEncode(seed).replaceAll('=', '');
      await _repository.saveLocalIdentitySeed(encodedSeed);
      generated.destroy();
    }
    _localIdentityKeyPair = await algorithm.newKeyPairFromSeed(seed);
    final SimplePublicKey publicKey =
        await _localIdentityKeyPair!.extractPublicKey();
    localIdentityPublicKey = base64UrlEncode(
      publicKey.bytes,
    ).replaceAll('=', '');
    localIdentityFingerprint = TrustedLanDevice.fingerprintForPublicKey(
      localIdentityPublicKey,
    );
  }

  void _rememberDiscoveredPeer(LanDiscoveredPeer peer) {
    final DateTime now = _now;
    // Broadcasts from the same device repeat; only rebuild the discovered
    // section when the peer's visible fields actually changed, so a busy LAN
    // does not rebuild the page on every heartbeat.
    final LanDiscoveredPeer? existing = _discoveredPeers[peer.deviceId];
    final bool changed =
        existing == null ||
        existing.displayName != peer.displayName ||
        existing.host != peer.host ||
        existing.port != peer.port ||
        existing.identityFingerprint != peer.identityFingerprint ||
        existing.identityPublicKey != peer.identityPublicKey;
    _discoveredPeers[peer.deviceId] = peer;
    _discoveredAt[peer.deviceId] = now;
    final List<String> expired =
        _discoveredAt.entries
            .where(
              (entry) =>
                  now.difference(entry.value) > const Duration(minutes: 5),
            )
            .map((entry) => entry.key)
            .toList();
    for (final String deviceId in expired) {
      _discoveredPeers.remove(deviceId);
      _discoveredAt.remove(deviceId);
    }
    while (_discoveredPeers.length > 64) {
      final String oldest =
          _discoveredAt.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
      _discoveredPeers.remove(oldest);
      _discoveredAt.remove(oldest);
    }
    if (changed) {
      update([discoveredDevicesChangedId]);
    }
  }

  String _randomBase64Url(int byteCount) {
    final List<int> bytes = List<int>.generate(
      byteCount,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _defaultDisplayName() {
    try {
      final String name = Platform.localHostname.trim();
      if (name.isNotEmpty) {
        return name;
      }
    } on Object {
      // A stable device id remains available when the hostname is unavailable.
    }
    return 'JHenTai ${localDeviceId.substring(localDeviceId.length - 6)}';
  }

  /// Persists a custom display name for this device and refreshes the UI.
  /// Returns a human-readable error message, or null on success.
  Future<String?> setLocalDisplayName(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'lanDeviceNameRequired'.tr;
    }
    if (trimmed.length > 128) {
      return 'lanDeviceNameTooLong'.tr;
    }
    await _repository.saveLocalDeviceName(trimmed);
    localDisplayName = trimmed;
    // The page's GetBuilders all carry specific ids, so a bare update() would
    // only reach id-less listeners and the new name would not appear until the
    // next unrelated rebuild. Refresh the identity + device sections directly.
    update([identityChangedId, devicesChangedId]);
    return null;
  }

  void _validatePeer(LanDiscoveredPeer peer) {
    if (!TrustedLanDevice.deviceIdPattern.hasMatch(peer.deviceId)) {
      throw const FormatException('Invalid LAN peer id');
    }
    if (peer.displayName.trim().isEmpty || peer.displayName.length > 128) {
      throw const FormatException('Invalid LAN peer name');
    }
    final String expectedFingerprint;
    try {
      expectedFingerprint = TrustedLanDevice.fingerprintForPublicKey(
        peer.identityPublicKey,
      );
    } on FormatException {
      throw const FormatException('Invalid LAN peer identity');
    }
    if (!TrustedLanDevice.fingerprintPattern.hasMatch(
          peer.identityFingerprint.toLowerCase(),
        ) ||
        expectedFingerprint != peer.identityFingerprint.toLowerCase()) {
      throw const FormatException('Invalid LAN peer identity');
    }
    if (peer.port < 1 || peer.port > 65535) {
      throw const FormatException('Invalid LAN peer port');
    }
    if (peer.protocolVersion != 1 && peer.protocolVersion != 2) {
      throw const FormatException('Unsupported LAN protocol version');
    }
  }

  bool _isValidAccessToken(String token) =>
      token.length >= 43 &&
      token.length <= 256 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token);

  void _validateChallenge(List<int> challenge) {
    if (challenge.length < 16 || challenge.length > 1024) {
      throw const FormatException('Invalid LAN authentication challenge');
    }
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    final List<int> a = utf8.encode(left);
    final List<int> b = utf8.encode(right);
    int difference = a.length ^ b.length;
    final int length = max(a.length, b.length);
    for (int i = 0; i < length; i++) {
      difference |= a[i % a.length] ^ b[i % b.length];
    }
    return difference == 0;
  }

  @override
  void onClose() {
    _discoverySubscription?.cancel();
    _trafficUpdateTimer?.cancel();
    _trafficUpdateTimer = null;
    for (final LanScheduledTask timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    for (final LanScheduledTask timer in _incomingPairingTimers.values) {
      timer.cancel();
    }
    _incomingPairingTimers.clear();
    _promptingIncomingPairingDeviceIds.clear();
    for (final LanPeerSession session in _sessions.values) {
      unawaited(session.close());
    }
    _sessions.clear();
    _disconnectRequested.clear();
    _localIdentityKeyPair?.destroy();
    super.onClose();
  }
}
