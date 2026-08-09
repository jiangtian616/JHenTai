import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_sharing_runtime.dart';
import 'package:jhentai/src/service/lan_trust_repository.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:path/path.dart' as path;

void main() {
  setUp(() => advancedSetting.enableLanSharing.value = true);

  tearDown(() => advancedSetting.enableLanSharing.value = false);

  test(
    'two LAN runtimes pair by approval and establish a trusted session',
    () async {
      final Directory phoneCache = await Directory.systemTemp.createTemp(
        'jh-lan-phone-cache-',
      );
      const String imagePageHref = 'https://e-hentai.org/s/hash/123-1';
      const String imageUrl =
          'https://example.test/image.jpg?fileindex=42&keystamp=old';
      final List<int> imageBytes = List<int>.generate(256, (index) => index);
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(101),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(202),
        registerWithGet: false,
      );
      await deviceA.doInitBean();
      await deviceB.doInitBean();

      final LanSharingRuntime runtimeA = LanSharingRuntime(
        trustService: deviceA,
        useServiceDiscovery: false,
        bindAddress: InternetAddress.loopbackIPv4,
        secureRandom: Random(303),
        imageCacheDirectory: phoneCache.path,
      );
      final LanSharingRuntime runtimeB = LanSharingRuntime(
        trustService: deviceB,
        useServiceDiscovery: false,
        bindAddress: InternetAddress.loopbackIPv4,
        secureRandom: Random(404),
        imageCacheResolver: (href) async {
          if (href != imagePageHref) {
            return null;
          }
          return LanSharedImage(
            image: {
              'url': imageUrl,
              'height': 1200.0,
              'width': 800.0,
              'originalImageUrl': null,
              'originalImageHeight': null,
              'originalImageWidth': null,
              'reloadKey': null,
              'imageHash': null,
              'path': null,
              'downloadStatus': 0,
            },
            bytes: imageBytes,
          );
        },
      );
      await runtimeA.doInitBean();
      await runtimeB.doInitBean();

      final LanDiscoveredPeer peerB = _peerFor(deviceB, runtimeB.serverPort!);
      await deviceA.handlePeerDiscovered(peerB);
      final Future<LanPairingAcceptance> pairing = deviceA
          .trustDiscoveredDevice(
            deviceId: deviceB.localDeviceId,
            permissions: const {
              LanSharePermission.downloads,
              LanSharePermission.imageCache,
            },
          );

      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      expect(deviceB.trustedDevices, isEmpty);
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {
          LanSharePermission.imageCache,
          LanSharePermission.translationResults,
        },
      );
      await pairing;

      expect(deviceA.deviceById(deviceB.localDeviceId), isNotNull);
      expect(deviceB.deviceById(deviceA.localDeviceId), isNotNull);
      expect(deviceB.incomingPairingRequests, isEmpty);

      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      final LanSharedImage? raw = await deviceA.requestImageCache(
        imagePageHref,
      );
      expect(raw?.bytes, imageBytes);
      final dynamic image = await runtimeA.fetchCachedImage(imagePageHref);
      expect(image?.url, imageUrl);
      expect(
        await File(
          path.join(phoneCache.path, normalizedImageCacheKey(imageUrl)),
        ).readAsBytes(),
        imageBytes,
      );

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await phoneCache.delete(recursive: true);
    },
  );
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

Future<void> _waitUntil(bool Function() predicate) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
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
