import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_trust_repository.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';

const String _peerId = 'peer_device_123456';
late SimpleKeyPair _peerKeyPair;
late String _publicKey;
late String _fingerprint;
const String _otherFingerprint =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _remoteToken = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;

  setUpAll(() async {
    _peerKeyPair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 1),
    );
    final SimplePublicKey publicKey = await _peerKeyPair.extractPublicKey();
    _publicKey = base64UrlEncode(publicKey.bytes).replaceAll('=', '');
    _fingerprint = TrustedLanDevice.fingerprintForPublicKey(_publicKey);
  });

  tearDownAll(() => _peerKeyPair.destroy());

  setUp(() => advancedSetting.enableLanSharing.value = true);

  tearDown(() {
    advancedSetting.enableLanSharing.value = false;
    Get.reset();
  });

  test('trusted device JSON round-trips and rejects malformed identities', () {
    final DateTime now = DateTime.utc(2026, 8, 9, 12);
    final TrustedLanDevice device = TrustedLanDevice(
      deviceId: _peerId,
      displayName: 'Desktop',
      identityPublicKey: _publicKey,
      identityFingerprint: _fingerprint,
      permissions: const {
        LanSharePermission.downloads,
        LanSharePermission.translationResults,
      },
      autoConnect: true,
      pairedAt: now,
      lastSeenAt: now,
    );

    final TrustedLanDevice restored = TrustedLanDevice.fromJson(
      device.toJson(),
    );
    expect(restored.deviceId, _peerId);
    expect(restored.permissions, device.permissions);
    expect(restored.autoConnect, isTrue);
    expect(
      () => TrustedLanDevice.fromJson({
        ...device.toJson(),
        'identityFingerprint': '../not-a-fingerprint',
      }),
      throwsFormatException,
    );
  });

  test(
    'repository keeps metadata on disk and credentials in secret storage',
    () async {
      final Directory temporary = await Directory.systemTemp.createTemp(
        'jhentai_lan_trust',
      );
      final _MemorySecretStore secrets = _MemorySecretStore();
      final FileLanTrustRepository repository = FileLanTrustRepository(
        directory: temporary,
        secretStore: secrets,
      );
      await repository.init();
      expect(
        await repository.ensureLocalDeviceId(() => 'jht_local_device_123456'),
        'jht_local_device_123456',
      );
      const String identitySeed = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE';
      await repository.saveLocalIdentitySeed(identitySeed);
      expect(await repository.readLocalIdentitySeed(), identitySeed);

      final TrustedLanDevice device = _device();
      await repository.saveDevice(
        device,
        remoteAccessToken: _remoteToken,
        inboundAccessToken: 'iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii',
      );

      final FileLanTrustRepository reloaded = FileLanTrustRepository(
        directory: temporary,
        secretStore: secrets,
      );
      await reloaded.init();
      expect((await reloaded.loadDevices()).single.deviceId, _peerId);
      expect(
        (await reloaded.credentialsFor(_peerId))!.remoteAccessToken,
        _remoteToken,
      );
      final String metadata =
          await File('${temporary.path}/trusted_devices.json').readAsString();
      expect(metadata, isNot(contains(_remoteToken)));
      expect(metadata, isNot(contains(identitySeed)));

      await reloaded.revokeDevice(_peerId);
      expect(await reloaded.loadDevices(), isEmpty);
      expect(await reloaded.credentialsFor(_peerId), isNull);
      await temporary.delete(recursive: true);
    },
  );

  test(
    'encrypted file secret store persists without exposing values',
    () async {
      final Directory temporary = await Directory.systemTemp.createTemp(
        'jhentai_lan_encrypted_secrets',
      );
      final EncryptedFileLanSecretStore first = EncryptedFileLanSecretStore(
        directory: temporary,
        secureRandom: Random(41),
      );
      const String identitySeed = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE';
      await first.write('identity', identitySeed);
      await first.write('token', _remoteToken);

      final File vault = File('${temporary.path}/credentials.v1.enc');
      final File key = File('${temporary.path}/.credential-key');
      final String encrypted = await vault.readAsString();
      expect(encrypted, isNot(contains(identitySeed)));
      expect(encrypted, isNot(contains(_remoteToken)));
      expect(await key.length(), 32);

      final EncryptedFileLanSecretStore reloaded = EncryptedFileLanSecretStore(
        directory: temporary,
        secureRandom: Random(42),
      );
      expect(await reloaded.read('identity'), identitySeed);
      expect(await reloaded.read('token'), _remoteToken);
      await temporary.delete(recursive: true);
    },
  );

  test('encrypted file secret store rejects a modified vault', () async {
    final Directory temporary = await Directory.systemTemp.createTemp(
      'jhentai_lan_tampered_secrets',
    );
    final EncryptedFileLanSecretStore store = EncryptedFileLanSecretStore(
      directory: temporary,
      secureRandom: Random(43),
    );
    await store.write('token', _remoteToken);

    final File vault = File('${temporary.path}/credentials.v1.enc');
    final Map<String, dynamic> envelope = Map<String, dynamic>.from(
      jsonDecode(await vault.readAsString()) as Map,
    );
    final List<int> cipherText = base64Url.decode(
      base64Url.normalize(envelope['cipherText'] as String),
    );
    cipherText[0] ^= 1;
    envelope['cipherText'] = base64UrlEncode(cipherText);
    await vault.writeAsString(jsonEncode(envelope), flush: true);

    await expectLater(
      store.read('token'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await temporary.delete(recursive: true);
  });

  test(
    'pairing persists trust and inbound authentication checks both factors',
    () async {
      final _MemoryTrustRepository repository = _MemoryTrustRepository();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: repository,
        secureRandom: Random(1),
      );
      await service.doInitBean();

      final LanPairingAcceptance acceptance = await service.completePairing(
        peer: _peer(),
        remoteAccessToken: _remoteToken,
        permissions: const {LanSharePermission.downloads},
      );

      expect(service.trustedDevices.single.deviceId, _peerId);
      expect(acceptance.localIdentityPublicKey, isNotEmpty);
      expect(
        acceptance.localIdentityFingerprint,
        TrustedLanDevice.fingerprintForPublicKey(
          acceptance.localIdentityPublicKey,
        ),
      );
      expect(acceptance.accessTokenForRemote.length, greaterThanOrEqualTo(43));
      final List<int> challenge = List<int>.generate(32, (index) => index);
      final Signature proof = await Ed25519().sign(
        challenge,
        keyPair: _peerKeyPair,
      );
      expect(
        await service.authenticateInbound(
          deviceId: _peerId,
          identityFingerprint: _fingerprint,
          presentedToken: acceptance.accessTokenForRemote,
          challenge: challenge,
          challengeSignature: proof.bytes,
        ),
        isTrue,
      );
      expect(
        await service.authenticateInbound(
          deviceId: _peerId,
          identityFingerprint: _otherFingerprint,
          presentedToken: acceptance.accessTokenForRemote,
          challenge: challenge,
          challengeSignature: proof.bytes,
        ),
        isFalse,
      );
      expect(
        await service.authenticateInbound(
          deviceId: _peerId,
          identityFingerprint: _fingerprint,
          presentedToken: 'wrong',
          challenge: challenge,
          challengeSignature: proof.bytes,
        ),
        isFalse,
      );
      expect(
        await service.authenticateInbound(
          deviceId: _peerId,
          identityFingerprint: _fingerprint,
          presentedToken: acceptance.accessTokenForRemote,
          challenge: challenge,
          challengeSignature: List<int>.filled(64, 0),
        ),
        isFalse,
      );
    },
  );

  test(
    'trusted discovery auto-connects once and rejects identity changes',
    () async {
      final _MemoryTrustRepository repository = _MemoryTrustRepository();
      final _RecordingConnector connector = _RecordingConnector();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: repository,
        connector: connector,
        secureRandom: Random(2),
      );
      await service.doInitBean();
      await service.completePairing(
        peer: _peer(),
        remoteAccessToken: _remoteToken,
        permissions: const {LanSharePermission.imageCache},
      );

      await service.handlePeerDiscovered(_peer());
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connected,
      );
      await service.handlePeerDiscovered(_peer());
      expect(connector.connectCount, 1);

      await service.disconnect(_peerId);
      await service.handlePeerDiscovered(_peer(fingerprint: _otherFingerprint));
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.identityMismatch,
      );
    },
  );

  test('disabling auto-connect closes the current trusted session', () async {
    final _MemoryTrustRepository repository = _MemoryTrustRepository();
    final _RecordingConnector connector = _RecordingConnector();
    final LanDeviceTrustService service = LanDeviceTrustService(
      repository: repository,
      connector: connector,
      secureRandom: Random(3),
    );
    await service.doInitBean();
    await service.completePairing(
      peer: _peer(),
      remoteAccessToken: _remoteToken,
      permissions: const {LanSharePermission.translationResults},
    );
    await service.handlePeerDiscovered(_peer());

    await service.setAutoConnect(_peerId, false);
    expect(connector.session.closedByClient, isTrue);
    expect(service.deviceById(_peerId)!.autoConnect, isFalse);
    expect(
      service.connectionFor(_peerId).state,
      LanPeerConnectionState.offline,
    );
  });

  test('an untrusted discovery requires an explicit trust decision', () async {
    final _MemoryTrustRepository repository = _MemoryTrustRepository();
    final _RecordingPairer pairer = _RecordingPairer();
    final LanDeviceTrustService service = LanDeviceTrustService(
      repository: repository,
      pairer: pairer,
      secureRandom: Random(4),
    );
    await service.doInitBean();

    await service.handlePeerDiscovered(_peer());
    expect(service.discoveredPeers.single.deviceId, _peerId);
    expect(service.trustedDevices, isEmpty);

    service.ignoreDiscoveredDevice(_peerId);
    expect(service.discoveredPeers, isEmpty);
    expect(service.trustedDevices, isEmpty);

    await service.handlePeerDiscovered(_peer());
    await service.trustDiscoveredDevice(
      deviceId: _peerId,
      permissions: const {LanSharePermission.translationResults},
    );
    expect(pairer.requestCount, 1);
    expect(service.discoveredPeers, isEmpty);
    expect(service.trustedDevices.single.deviceId, _peerId);
  });

  test('disabled LAN sharing ignores discovery', () async {
    advancedSetting.enableLanSharing.value = false;
    final LanDeviceTrustService service = LanDeviceTrustService(
      repository: _MemoryTrustRepository(),
      secureRandom: Random(5),
    );
    await service.doInitBean();

    await service.handlePeerDiscovered(_peer());
    expect(service.isEnabled, isFalse);
    expect(service.discoveredPeers, isEmpty);
    expect(service.localIdentityPublicKey, isEmpty);
  });
}

TrustedLanDevice _device() {
  final DateTime now = DateTime.utc(2026, 8, 9, 12);
  return TrustedLanDevice(
    deviceId: _peerId,
    displayName: 'Desktop',
    identityPublicKey: _publicKey,
    identityFingerprint: _fingerprint,
    permissions: const {LanSharePermission.downloads},
    autoConnect: true,
    pairedAt: now,
    lastSeenAt: now,
  );
}

LanDiscoveredPeer _peer({String? fingerprint}) => LanDiscoveredPeer(
  deviceId: _peerId,
  displayName: 'Desktop',
  host: '192.168.1.8',
  port: 43821,
  identityPublicKey: _publicKey,
  identityFingerprint: fingerprint ?? _fingerprint,
);

class _MemorySecretStore implements LanSecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryTrustRepository implements LanTrustRepository {
  String? localDeviceId;
  String? localIdentitySeed;
  final Map<String, TrustedLanDevice> devices = {};
  final Map<String, LanDeviceCredentials> credentials = {};

  @override
  Future<LanDeviceCredentials?> credentialsFor(String deviceId) async =>
      credentials[deviceId];

  @override
  Future<String> ensureLocalDeviceId(String Function() generator) async =>
      localDeviceId ??= generator();

  @override
  Future<void> init() async {}

  @override
  Future<String?> readLocalIdentitySeed() async => localIdentitySeed;

  @override
  Future<void> saveLocalIdentitySeed(String seed) async {
    localIdentitySeed = seed;
  }

  @override
  Future<List<TrustedLanDevice>> loadDevices() async => devices.values.toList();

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
  Future<void> updateDevice(TrustedLanDevice device) async {
    devices[device.deviceId] = device;
  }
}

class _RecordingConnector implements LanPeerConnector {
  int connectCount = 0;
  final _FakeSession session = _FakeSession();

  @override
  Future<LanPeerSession> connect({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) async {
    connectCount++;
    expect(accessToken, _remoteToken);
    expect(expectedIdentityPublicKey, _publicKey);
    expect(expectedIdentityFingerprint, _fingerprint);
    return session;
  }
}

class _RecordingPairer implements LanPeerPairer {
  int requestCount = 0;

  @override
  Future<LanPairingExchange> requestPairing({
    required LanDiscoveredPeer peer,
    required String localDeviceId,
    required String localIdentityPublicKey,
    required String localIdentityFingerprint,
  }) async {
    requestCount++;
    expect(peer.deviceId, _peerId);
    expect(localDeviceId, isNotEmpty);
    expect(localIdentityPublicKey, isNotEmpty);
    expect(localIdentityFingerprint, isNotEmpty);
    return const LanPairingExchange(
      remoteAccessToken: _remoteToken,
      localInboundAccessToken: 'lllllllllllllllllllllllllllllllllllllllllll',
    );
  }
}

class _FakeSession implements LanPeerSession {
  final Completer<void> _closed = Completer<void>();
  bool closedByClient = false;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> close() async {
    closedByClient = true;
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}
