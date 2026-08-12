import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/en_US.dart';
import 'package:jhentai/src/l18n/zh_CN.dart';
import 'package:jhentai/src/l18n/zh_TW.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_trust_repository.dart';
import 'package:jhentai/src/service/lan_unified_state_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';

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
    log.logDirPath = '${Directory.systemTemp.path}/jhentai-lan-test-logs';
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

  test('OCR and translation compute permissions stay independent', () {
    final DateTime now = DateTime.utc(2026, 8, 9, 12);
    final TrustedLanDevice ocrOnly = TrustedLanDevice(
      deviceId: _peerId,
      displayName: 'Desktop',
      identityPublicKey: _publicKey,
      identityFingerprint: _fingerprint,
      permissions: const {LanSharePermission.ocrCompute},
      autoConnect: true,
      pairedAt: now,
      lastSeenAt: now,
    );
    final TrustedLanDevice translationOnly = TrustedLanDevice(
      deviceId: _peerId,
      displayName: 'Desktop',
      identityPublicKey: _publicKey,
      identityFingerprint: _fingerprint,
      permissions: const {LanSharePermission.translationCompute},
      autoConnect: true,
      pairedAt: now,
      lastSeenAt: now,
    );

    expect(ocrOnly.permissions, {LanSharePermission.ocrCompute});
    expect(
      ocrOnly.permissions.contains(LanSharePermission.translationCompute),
      isFalse,
    );
    expect(translationOnly.permissions, {
      LanSharePermission.translationCompute,
    });
    expect(
      translationOnly.permissions.contains(LanSharePermission.ocrCompute),
      isFalse,
    );
  });

  test('remote download request serializes its gallery metadata', () {
    final LanRemoteDownloadRequest request = LanRemoteDownloadRequest(
      gid: 42,
      galleryUrl: 'https://e-hentai.org/g/42/abcdefgh/',
      token: 'token',
      title: 'Gallery Title',
      category: 'Manga',
      pageCount: 12,
      uploader: 'uploader',
      publishTime: '2026-01-01 00:00',
      tags: const <String>['artist:name', 'female:big'],
      downloadOriginalImage: true,
    );
    final Map<String, dynamic> json = request.toJson();
    expect(json['gid'], 42);
    expect(json['galleryUrl'], 'https://e-hentai.org/g/42/abcdefgh/');
    expect(json['token'], 'token');
    expect(json['pageCount'], 12);
    expect(json['uploader'], 'uploader');
    expect(json['tags'], <String>['artist:name', 'female:big']);
    expect(json['downloadOriginalImage'], isTrue);
  });

  test('old permission JSON keeps behavior and ignores unknown names', () {
    final Map<String, dynamic> oldJson = {
      ..._device().toJson(),
      'permissions': ['translationCompute', 'futureCompute', 42],
    };
    final TrustedLanDevice restored = TrustedLanDevice.fromJson(oldJson);

    expect(restored.permissions, {LanSharePermission.translationCompute});
    expect(
      restored.permissions.contains(LanSharePermission.ocrCompute),
      isFalse,
    );

    final Map<String, dynamic> missingPermissionField =
        _device().toJson()..remove('permissions');
    expect(
      TrustedLanDevice.fromJson(missingPermissionField).permissions,
      isEmpty,
    );
  });

  test('known permission JSON round-trips with stable ordering', () {
    final TrustedLanDevice device = _device().copyWith(
      permissions: const {
        LanSharePermission.ocrCompute,
        LanSharePermission.translationCompute,
      },
    );
    final Map<String, dynamic> encoded = device.toJson();
    final TrustedLanDevice restored = TrustedLanDevice.fromJson(encoded);

    expect(restored.toJson(), encoded);
    expect(encoded['permissions'], ['ocrCompute', 'translationCompute']);
  });

  test(
    'revoked compute permission stays revoked in offline persisted record',
    () async {
      final Directory temporary = await Directory.systemTemp.createTemp(
        'jhentai_lan_permission_revoke',
      );
      final _MemorySecretStore secrets = _MemorySecretStore();
      try {
        final FileLanTrustRepository repository = FileLanTrustRepository(
          directory: temporary,
          secretStore: secrets,
        );
        final LanDeviceTrustService service = LanDeviceTrustService(
          repository: repository,
          secureRandom: Random(12),
        );
        await service.doInitBean();
        await service.completePairing(
          peer: _peer(),
          remoteAccessToken: _remoteToken,
          permissions: const {
            LanSharePermission.ocrCompute,
            LanSharePermission.translationCompute,
          },
        );
        await service.disconnect(_peerId);

        await service.setPermissions(_peerId, const {
          LanSharePermission.translationCompute,
        });

        final FileLanTrustRepository reloadedRepository =
            FileLanTrustRepository(directory: temporary, secretStore: secrets);
        final LanDeviceTrustService reloadedService = LanDeviceTrustService(
          repository: reloadedRepository,
          secureRandom: Random(13),
        );
        await reloadedService.doInitBean();

        expect(reloadedService.deviceById(_peerId)!.permissions, {
          LanSharePermission.translationCompute,
        });
        expect(
          reloadedService
              .deviceById(_peerId)!
              .permissions
              .contains(LanSharePermission.ocrCompute),
          isFalse,
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
  );

  test('OCR permission display copy is present with translation copy', () {
    for (final Map<String, String> locale in [
      en_US.keys(),
      zh_CN.keys(),
      zh_TW.keys(),
    ]) {
      expect(locale['lanPermission_ocrCompute'], isNotEmpty);
      expect(locale['lanPermission_translationCompute'], isNotEmpty);
      expect(
        locale['lanPermission_ocrCompute'],
        isNot(locale['lanPermission_translationCompute']),
      );
    }
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
      pathService.tempDir = Directory.systemTemp;

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
      final Directory logDirectory = Directory(
        '${Directory.systemTemp.path}/jhentai-lan-test-logs',
      )..createSync(recursive: true);
      log.logDirPath = logDirectory.path;
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

  test(
    'duplicate discovery keeps a failed session state until its retry timer fires',
    () async {
      final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
      final _SequenceConnector connector = _SequenceConnector([
        StateError('connection refused'),
        StateError('still refused'),
        _FakeSession(),
      ]);
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        connector: connector,
        timerScheduler: scheduler,
        retryDelay: const Duration(minutes: 10),
        maxRetryDelay: const Duration(minutes: 30),
        secureRandom: Random(6),
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
        LanPeerConnectionState.failed,
      );
      expect(service.connectionFor(_peerId).errorMessage, contains('refused'));

      await service.handlePeerDiscovered(_peer());
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.failed,
      );

      scheduler.fireNext();
      await _flushMicrotasks();
      expect(connector.connectCount, 2);
      expect(scheduler.delays, [
        const Duration(minutes: 10),
        const Duration(minutes: 20),
      ]);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.failed,
      );

      await service.handlePeerDiscovered(_peer());
      expect(connector.connectCount, 2);
      scheduler.fireNext();
      await _flushMicrotasks();
      expect(connector.connectCount, 3);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connected,
      );
    },
  );

  test(
    'discovery churn does not replace an in-flight authenticated session',
    () async {
      final _BlockingConnector connector = _BlockingConnector();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        connector: connector,
        secureRandom: Random(8),
      );
      await service.doInitBean();
      await service.completePairing(
        peer: _peer(),
        remoteAccessToken: _remoteToken,
        permissions: const {LanSharePermission.imageCache},
      );

      final Future<void> first = service.handlePeerDiscovered(_peer());
      await _flushMicrotasks();
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connecting,
      );

      final Future<void> duplicate = service.handlePeerDiscovered(
        _peer(host: '192.168.1.9', port: 43822),
      );
      await _flushMicrotasks();
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connecting,
      );

      final _FakeSession session = _FakeSession();
      connector.complete(session);
      await Future.wait([first, duplicate]);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connected,
      );
    },
  );

  test(
    'a closed session becomes failed and reconnects through its own timer',
    () async {
      final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
      final _FakeSession firstSession = _FakeSession();
      final _FakeSession secondSession = _FakeSession();
      final _SequenceConnector connector = _SequenceConnector([
        firstSession,
        secondSession,
      ]);
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        connector: connector,
        timerScheduler: scheduler,
        retryDelay: const Duration(minutes: 10),
        maxRetryDelay: const Duration(minutes: 10),
        secureRandom: Random(9),
      );
      await service.doInitBean();
      await service.completePairing(
        peer: _peer(),
        remoteAccessToken: _remoteToken,
        permissions: const {LanSharePermission.imageCache},
      );

      await service.handlePeerDiscovered(_peer());
      firstSession.closeRemotely();
      await _flushMicrotasks();
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.failed,
      );
      expect(scheduler.delays, [const Duration(minutes: 10)]);

      scheduler.fireNext();
      await _flushMicrotasks();
      expect(connector.connectCount, 2);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connected,
      );
    },
  );

  test(
    'expired incoming pairing requests are removed by the controllable timer',
    () async {
      final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        timerScheduler: scheduler,
        incomingPairingDelay: const Duration(minutes: 2),
        secureRandom: Random(7),
      );
      await service.doInitBean();

      final Future<LanPairingAcceptance?> approval = service
          .requestIncomingPairingApproval(
            peer: _peer(),
            remoteAccessToken: _remoteToken,
          );
      expect(service.incomingPairingRequests, hasLength(1));

      scheduler.fireNext();
      expect(await approval, isNull);
      expect(service.incomingPairingRequests, isEmpty);
    },
  );

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

  test(
    'connecting to a trusted peer syncs login state and application history',
    () async {
      final LanLoginStateSnapshot snapshot = LanLoginStateSnapshot(
        sites: const ['eh', 'jh'],
        accountId: 12345,
        cookies: const ['ipb_member_id=12345', 'ipb_pass_hash=hash'],
        exportedAt: DateTime.utc(2026, 8, 9, 12),
      );
      final LanUnifiedStatePayload history = LanUnifiedStatePayload(
        capability: 'applicationHistoryV1',
        sourceDeviceId: _peerId,
        generatedAt: DateTime.utc(2026, 8, 9, 12),
        records: [
          LanUnifiedRecord(
            type: LanUnifiedRecordType.galleryHistory,
            key: '42',
            updatedAt: DateTime.utc(2026, 8, 9, 12),
            tombstone: false,
            value: const {'jsonBody': '{}'},
            sourceDeviceId: _peerId,
          ),
        ],
      );
      final _UnifiedStateSession session = _UnifiedStateSession(
        loginSnapshot: snapshot,
        historyPayload: history,
      );
      final _UnifiedStateConnector connector = _UnifiedStateConnector(session);
      final _RecordingUnifiedStateService unifiedState =
          _RecordingUnifiedStateService();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        connector: connector,
        unifiedState: unifiedState,
        secureRandom: Random(7),
      );
      await service.doInitBean();
      await service.completePairing(
        peer: _peer(),
        remoteAccessToken: _remoteToken,
        permissions: const {
          LanSharePermission.loginState,
          LanSharePermission.applicationHistory,
        },
      );

      await service.handlePeerDiscovered(_peer());
      expect(connector.connectCount, 1);
      expect(
        service.connectionFor(_peerId).state,
        LanPeerConnectionState.connected,
      );
      for (int index = 0; index < 10; index++) {
        await _flushMicrotasks();
      }

      expect(session.loginStateRequests, 1);
      expect(session.historyRequests, 1);
      expect(unifiedState.loginImportCount, 1);
      expect(unifiedState.lastLoginSnapshot?.accountId, 12345);
      expect(unifiedState.historyImportCount, 1);
      expect(unifiedState.lastHistoryPayload?.records.single.key, '42');
      // After pulling the peer's history, the merged history must be pushed
      // back so the peer also ends up with both sides' records.
      expect(session.historyPushes, 1);
      expect(session.lastPushedHistory, isNotNull);
      expect(unifiedState.historyExportCount, 1);
    },
  );

  test(
    'an already-logged-in device skips login-state pull but still merges history',
    () async {
      final int? previous = userSetting.ipbMemberId.value;
      userSetting.ipbMemberId.value = 777;
      final LanUnifiedStatePayload history = LanUnifiedStatePayload(
        capability: 'applicationHistoryV1',
        sourceDeviceId: _peerId,
        generatedAt: DateTime.utc(2026, 8, 9, 12),
        records: [
          LanUnifiedRecord(
            type: LanUnifiedRecordType.readProgress,
            key: '42',
            updatedAt: DateTime.utc(2026, 8, 9, 12),
            tombstone: false,
            value: const {'index': 3},
            sourceDeviceId: _peerId,
          ),
        ],
      );
      final _UnifiedStateSession session = _UnifiedStateSession(
        historyPayload: history,
      );
      final _UnifiedStateConnector connector = _UnifiedStateConnector(session);
      final _RecordingUnifiedStateService unifiedState =
          _RecordingUnifiedStateService();
      final LanDeviceTrustService service = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        connector: connector,
        unifiedState: unifiedState,
        secureRandom: Random(8),
      );
      try {
        await service.doInitBean();
        await service.completePairing(
          peer: _peer(),
          remoteAccessToken: _remoteToken,
          permissions: const {
            LanSharePermission.loginState,
            LanSharePermission.applicationHistory,
          },
        );
        await service.handlePeerDiscovered(_peer());
        expect(
          service.connectionFor(_peerId).state,
          LanPeerConnectionState.connected,
        );
        for (int index = 0; index < 10; index++) {
          await _flushMicrotasks();
        }
        expect(session.loginStateRequests, 0);
        expect(session.historyRequests, 1);
        expect(unifiedState.loginImportCount, 0);
        expect(unifiedState.historyImportCount, 1);
        expect(unifiedState.lastHistoryPayload?.records.single.key, '42');
      } finally {
        userSetting.ipbMemberId.value = previous;
      }
    },
  );
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

LanDiscoveredPeer _peer({
  String? fingerprint,
  String host = '192.168.1.8',
  int port = 43821,
}) => LanDiscoveredPeer(
  deviceId: _peerId,
  displayName: 'Desktop',
  host: host,
  port: port,
  identityPublicKey: _publicKey,
  identityFingerprint: fingerprint ?? _fingerprint,
);

Future<void> _flushMicrotasks() async {
  for (int index = 0; index < 3; index++) {
    await Future<void>.value();
  }
}

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
  String? localDeviceName;
  final Map<String, TrustedLanDevice> devices = {};
  final Map<String, LanDeviceCredentials> credentials = {};

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
  Future<LanSharedImage?> requestImageCache(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
  }) async => null;

  @override
  Future<List<LanSharedGallerySummary>> listDownloadedGalleries() async =>
      const <LanSharedGallerySummary>[];

  @override
  Future<LanSharedGalleryPage> listDownloadedGalleriesPage({
    String? cursor,
    int limit = 50,
    String? knownRevision,
  }) async => const LanSharedGalleryPage(
    revision: '',
    nextCursor: null,
    galleries: <LanSharedGallerySummary>[],
  );

  @override
  Future<bool> requestDownloadGallery(LanRemoteDownloadRequest request) async =>
      false;

  @override
  Future<bool> pushCacheFile(String key, List<int> bytes) async => false;

  @override
  Future<bool> pushHistory(LanUnifiedStatePayload payload) async => false;

  @override
  Future<bool> pushLoginState(LanLoginStateSnapshot snapshot) async => false;

  @override
  Future<void> close() async {
    closedByClient = true;
    closeRemotely();
  }

  void closeRemotely() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}

class _BlockingConnector implements LanPeerConnector {
  final Completer<LanPeerSession> _result = Completer<LanPeerSession>();
  int connectCount = 0;

  @override
  Future<LanPeerSession> connect({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) {
    connectCount++;
    return _result.future;
  }

  void complete(LanPeerSession session) => _result.complete(session);
}

class _SequenceConnector implements LanPeerConnector {
  final List<Object> _outcomes;
  int connectCount = 0;

  _SequenceConnector(this._outcomes);

  @override
  Future<LanPeerSession> connect({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) async {
    connectCount++;
    final Object outcome = _outcomes.removeAt(0);
    if (outcome is LanPeerSession) {
      return outcome;
    }
    throw outcome;
  }
}

class _FakeTimerScheduler implements LanTimerScheduler {
  final List<_FakeScheduledTask> _tasks = [];
  final List<Duration> delays = [];

  @override
  LanScheduledTask schedule(Duration delay, void Function() callback) {
    delays.add(delay);
    final _FakeScheduledTask task = _FakeScheduledTask(callback);
    _tasks.add(task);
    return task;
  }

  void fireNext() {
    final _FakeScheduledTask task = _tasks.removeAt(0);
    task.fire();
  }
}

class _FakeScheduledTask implements LanScheduledTask {
  final void Function() _callback;
  bool _cancelled = false;

  _FakeScheduledTask(this._callback);

  @override
  void cancel() => _cancelled = true;

  void fire() {
    if (!_cancelled) {
      _callback();
    }
  }
}

/// A peer session that also answers unified-state requests, so the sync-on-
/// connect path can be exercised without a real v2 socket.
class _UnifiedStateSession implements LanPeerSession, LanUnifiedStateSession {
  final LanLoginStateSnapshot? loginSnapshot;
  final LanUnifiedStatePayload? historyPayload;
  final Completer<void> _closed = Completer<void>();
  int loginStateRequests = 0;
  int historyRequests = 0;
  int historyPushes = 0;
  LanUnifiedStatePayload? lastPushedHistory;

  _UnifiedStateSession({this.loginSnapshot, this.historyPayload});

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<LanSharedImage?> requestImageCache(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
  }) async => null;

  @override
  Future<List<LanSharedGallerySummary>> listDownloadedGalleries() async =>
      const <LanSharedGallerySummary>[];

  @override
  Future<LanSharedGalleryPage> listDownloadedGalleriesPage({
    String? cursor,
    int limit = 50,
    String? knownRevision,
  }) async => const LanSharedGalleryPage(
    revision: '',
    nextCursor: null,
    galleries: <LanSharedGallerySummary>[],
  );

  @override
  Future<LanLoginStateSnapshot?> requestLoginState() async {
    loginStateRequests++;
    return loginSnapshot;
  }

  @override
  Future<LanUnifiedStatePayload?> requestApplicationHistory() async {
    historyRequests++;
    return historyPayload;
  }

  @override
  Future<bool> requestDownloadGallery(LanRemoteDownloadRequest request) async =>
      false;

  @override
  Future<bool> pushCacheFile(String key, List<int> bytes) async => false;

  @override
  Future<bool> pushHistory(LanUnifiedStatePayload payload) async {
    historyPushes++;
    lastPushedHistory = payload;
    return true;
  }

  @override
  Future<bool> pushLoginState(LanLoginStateSnapshot snapshot) async => false;

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}

class _UnifiedStateConnector implements LanPeerConnector {
  final LanPeerSession session;
  int connectCount = 0;

  _UnifiedStateConnector(this.session);

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

class _RecordingUnifiedStateService extends LanUnifiedStateService {
  int loginImportCount = 0;
  int historyImportCount = 0;
  int historyExportCount = 0;
  LanLoginStateSnapshot? lastLoginSnapshot;
  LanUnifiedStatePayload? lastHistoryPayload;

  @override
  Future<LanLoginImportResult> importLoginState(
    LanLoginStateSnapshot snapshot,
  ) async {
    loginImportCount++;
    lastLoginSnapshot = snapshot;
    return const LanLoginImportResult(LanLoginImportOutcome.imported);
  }

  @override
  Future<int> importHistory(LanUnifiedStatePayload payload) async {
    historyImportCount++;
    lastHistoryPayload = payload;
    return payload.records.length;
  }

  @override
  Future<LanUnifiedStatePayload> exportHistory({
    required String sourceDeviceId,
    Iterable<LanUnifiedRecord> bookmarks = const <LanUnifiedRecord>[],
  }) async {
    historyExportCount++;
    return LanUnifiedStatePayload(
      capability: 'applicationHistoryV1',
      sourceDeviceId: sourceDeviceId,
      generatedAt: DateTime.utc(2026, 1, 1),
      records: const <LanUnifiedRecord>[],
    );
  }
}
