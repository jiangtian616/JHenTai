import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';

import 'jh_service.dart';
import 'lan_trust_repository.dart';
import 'log.dart';
import 'path_service.dart';

LanDeviceTrustService lanDeviceTrustService = LanDeviceTrustService();

abstract interface class LanPeerSession {
  Future<void> get closed;

  Future<void> close();
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
  static const String connectionIdPrefix = 'lanConnection';
  static const Duration retryCooldown = Duration(seconds: 10);

  final LanTrustRepository? _repositoryOverride;
  final bool _registerWithGet;
  LanPeerConnector? _connector;
  LanPeerPairer? _pairer;
  StreamSubscription<LanDiscoveredPeer>? _discoverySubscription;
  final Map<String, LanPeerSession> _sessions = {};
  final Map<String, Future<void>> _connecting = {};
  final Map<String, DateTime> _retryAfter = {};
  final Map<String, LanConnectionSnapshot> _connectionStates = {};
  final Map<String, LanDiscoveredPeer> _discoveredPeers = {};
  final Map<String, DateTime> _discoveredAt = {};
  final Map<String, _PendingIncomingPairing> _incomingPairings = {};
  final Set<String> _pairingDeviceIds = {};
  final Random _secureRandom;

  late LanTrustRepository _repository;
  SimpleKeyPair? _localIdentityKeyPair;
  bool isEnabled = false;
  String localDeviceId = '';
  String localDisplayName = '';
  String localIdentityPublicKey = '';
  String localIdentityFingerprint = '';
  final List<TrustedLanDevice> trustedDevices = [];

  LanDeviceTrustService({
    LanTrustRepository? repository,
    LanPeerConnector? connector,
    LanPeerPairer? pairer,
    Random? secureRandom,
    bool registerWithGet = true,
  }) : _repositoryOverride = repository,
       _registerWithGet = registerWithGet,
       _connector = connector,
       _pairer = pairer,
       _secureRandom = secureRandom ?? Random.secure();

  @override
  List<JHLifeCircleBean> get initDependencies => [
    pathService,
    log,
    advancedSetting,
  ];

  @override
  Future<void> doInitBean() async {
    _repository =
        _repositoryOverride ??
        FileLanTrustRepository(
          directory: pathService.jhLanDir,
          secretStore: PlatformLanSecretStore(),
        );
    await _repository.init();
    localDeviceId = await _repository.ensureLocalDeviceId(_generateDeviceId);
    isEnabled = advancedSetting.enableLanSharing.value;
    if (isEnabled) {
      await _loadOrCreateLocalIdentity();
    }
    localDisplayName = _defaultDisplayName();
    trustedDevices
      ..clear()
      ..addAll(await _repository.loadDevices());
    if (_registerWithGet) {
      Get.put(this, permanent: true);
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}

  String connectionId(String deviceId) => '$connectionIdPrefix::$deviceId';

  LanConnectionSnapshot connectionFor(String deviceId) =>
      _connectionStates[deviceId] ??
      const LanConnectionSnapshot(LanPeerConnectionState.offline);

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
      isEnabled = true;
    } else {
      isEnabled = false;
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      for (final String deviceId in _sessions.keys.toList()) {
        await disconnect(deviceId);
      }
      _discoveredPeers.clear();
      _discoveredAt.clear();
      for (final _PendingIncomingPairing pending in _incomingPairings.values) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete(null);
        }
      }
      _incomingPairings.clear();
    }
    update([
      identityChangedId,
      discoveredDevicesChangedId,
      incomingPairingsChangedId,
    ]);
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
    final DateTime now = DateTime.now().toUtc();
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
    _setConnection(
      device.deviceId,
      const LanConnectionSnapshot(LanPeerConnectionState.discovered),
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
    final String requestId = _randomBase64Url(18);
    final Completer<LanPairingAcceptance?> completer = Completer();
    final LanIncomingPairingRequest request = LanIncomingPairingRequest(
      requestId: requestId,
      peer: peer,
      requestedAt: DateTime.now().toUtc(),
    );
    final _PendingIncomingPairing? previous = _incomingPairings.remove(
      peer.deviceId,
    );
    if (previous != null && !previous.completer.isCompleted) {
      previous.completer.complete(null);
    }
    while (_incomingPairings.length >= 16) {
      final _PendingIncomingPairing oldest = _incomingPairings.values.reduce(
        (a, b) => a.request.requestedAt.isBefore(b.request.requestedAt) ? a : b,
      );
      _incomingPairings.remove(oldest.request.peer.deviceId);
      if (!oldest.completer.isCompleted) {
        oldest.completer.complete(null);
      }
    }
    _incomingPairings[peer.deviceId] = _PendingIncomingPairing(
      request: request,
      remoteAccessToken: remoteAccessToken,
      completer: completer,
    );
    update([incomingPairingsChangedId]);
    try {
      return await completer.future.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      return null;
    } finally {
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
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(null);
    }
    update([incomingPairingsChangedId]);
  }

  void ignoreDiscoveredDevice(String deviceId) {
    _discoveredPeers.remove(deviceId);
    _discoveredAt.remove(deviceId);
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
      await disconnect(deviceId);
    }
  }

  Future<void> revokeTrust(String deviceId) async {
    await disconnect(deviceId);
    await _repository.revokeDevice(deviceId);
    trustedDevices.removeWhere((device) => device.deviceId == deviceId);
    _connectionStates.remove(deviceId);
    _retryAfter.remove(deviceId);
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

    final DateTime now = DateTime.now().toUtc();
    final TrustedLanDevice seen = device.copyWith(
      displayName:
          peer.displayName.trim().isEmpty
              ? device.displayName
              : peer.displayName.trim(),
      lastSeenAt: now,
      protocolVersion: peer.protocolVersion,
    );
    _replaceDevice(seen);
    if (now.difference(device.lastSeenAt).abs() > const Duration(minutes: 5)) {
      await _repository.updateDevice(seen);
    }
    _setConnection(
      peer.deviceId,
      const LanConnectionSnapshot(LanPeerConnectionState.discovered),
    );

    if (!seen.autoConnect ||
        _connector == null ||
        _sessions.containsKey(peer.deviceId)) {
      return;
    }
    final DateTime? retryAfter = _retryAfter[peer.deviceId];
    if (retryAfter != null && now.isBefore(retryAfter)) {
      return;
    }
    await _connecting.putIfAbsent(
      peer.deviceId,
      () => _connectTrustedPeer(peer, seen),
    );
  }

  Future<void> disconnect(String deviceId) async {
    final LanPeerSession? session = _sessions.remove(deviceId);
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
      _sessions[peer.deviceId] = session;
      _retryAfter.remove(peer.deviceId);
      final TrustedLanDevice connected = device.copyWith(
        lastSeenAt: DateTime.now().toUtc(),
        lastConnectedAt: DateTime.now().toUtc(),
      );
      await _repository.updateDevice(connected);
      _replaceDevice(connected);
      _setConnection(
        peer.deviceId,
        const LanConnectionSnapshot(LanPeerConnectionState.connected),
      );
      unawaited(
        session.closed.whenComplete(() {
          if (identical(_sessions[peer.deviceId], session)) {
            _sessions.remove(peer.deviceId);
            _setConnection(
              peer.deviceId,
              const LanConnectionSnapshot(LanPeerConnectionState.offline),
            );
          }
        }),
      );
    } on Object catch (error, stack) {
      _retryAfter[peer.deviceId] = DateTime.now().toUtc().add(retryCooldown);
      _setConnection(
        peer.deviceId,
        LanConnectionSnapshot(
          LanPeerConnectionState.failed,
          errorMessage: error.toString(),
        ),
      );
      log.warning('Auto-connect trusted LAN device failed: ${peer.deviceId}');
      log.trace(stack);
    } finally {
      _connecting.remove(peer.deviceId);
    }
  }

  void _replaceDevice(TrustedLanDevice device) {
    trustedDevices.removeWhere((entry) => entry.deviceId == device.deviceId);
    trustedDevices.add(device);
    trustedDevices.sort((a, b) => a.displayName.compareTo(b.displayName));
    update([devicesChangedId]);
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
    final DateTime now = DateTime.now().toUtc();
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
    update([discoveredDevicesChangedId]);
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
    if (peer.protocolVersion != 1) {
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
    for (final LanPeerSession session in _sessions.values) {
      unawaited(session.close());
    }
    _sessions.clear();
    _localIdentityKeyPair?.destroy();
    super.onClose();
  }
}
