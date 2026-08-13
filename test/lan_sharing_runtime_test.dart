import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_sharing_runtime.dart';
import 'package:jhentai/src/service/lan_trust_repository.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:path/path.dart' as path;

void main() {
  setUpAll(() {
    log.logDirPath = '${Directory.systemTemp.path}/jhentai-lan-test-logs';
  });

  setUp(() {
    advancedSetting.enableLanSharing.value = true;
    advancedSetting.lanActAsServer.value = true;
    advancedSetting.lanServerMode.value = false;
  });

  tearDown(() {
    advancedSetting.enableLanSharing.value = false;
    advancedSetting.lanActAsServer.value = false;
    advancedSetting.lanServerMode.value = false;
  });

  test(
    'pending LAN requests are completed and removed by a fake timeout',
    () async {
      final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
      final LanPendingRequestRegistry<String> registry =
          LanPendingRequestRegistry<String>(
            timerScheduler: scheduler,
            timeout: const Duration(minutes: 10),
          );

      final Future<String> pending = registry.register(
        'request-1',
        timeoutValue: 'timed out',
      );
      expect(registry.length, 1);
      expect(scheduler.delays, [const Duration(minutes: 10)]);

      scheduler.fireNext();
      expect(await pending, 'timed out');
      expect(registry.length, 0);
    },
  );

  test('completing a LAN request cancels its timeout task', () async {
    final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
    final LanPendingRequestRegistry<String> registry =
        LanPendingRequestRegistry<String>(
          timerScheduler: scheduler,
          timeout: const Duration(seconds: 3),
        );

    final Future<String> pending = registry.register(
      'request-2',
      timeoutValue: 'timed out',
    );
    expect(registry.complete('request-2', 'response'), isTrue);
    scheduler.fireNext();
    expect(await pending, 'response');
    expect(registry.length, 0);
  });

  test('touching a pending LAN request extends its deadline', () async {
    final _FakeTimerScheduler scheduler = _FakeTimerScheduler();
    final LanPendingRequestRegistry<String> registry =
        LanPendingRequestRegistry<String>(
          timerScheduler: scheduler,
          timeout: const Duration(seconds: 3),
        );

    final Future<String> pending = registry.register(
      'request-3',
      timeoutValue: 'timed out',
    );
    expect(registry.length, 1);

    // Incoming chunks keep the transfer alive: the original deadline is
    // cancelled and a fresh one is scheduled.
    registry.touch('request-3');
    expect(scheduler.delays, [
      const Duration(seconds: 3),
      const Duration(seconds: 3),
    ]);

    // Firing the now-cancelled original timer is a no-op...
    scheduler.fireNext();
    expect(registry.length, 1);
    // ...only the rescheduled timer completes the request.
    scheduler.fireNext();
    expect(await pending, 'timed out');
    expect(registry.length, 0);
  });

  test(
    'mobile-like peer endpoint pairs without enabling desktop server mode',
    () async {
      advancedSetting.lanActAsServer.value = false;
      advancedSetting.lanServerMode.value = false;
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
      expect(deviceA.receivedBytes, imageBytes.length);
      expect(deviceB.sentBytes, imageBytes.length);
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

  test(
    'host serves a page from its downloaded gallery when the image cache misses',
    () async {
      final Directory phoneCache = await Directory.systemTemp.createTemp(
        'jh-lan-dl-cache-',
      );
      const String galleryUrl = 'https://e-hentai.org/g/123456/abcdef/';
      const String imagePageHref = 'https://e-hentai.org/s/hash/123-1';
      const String imageUrl = 'https://example.test/downloaded.jpg';
      final List<int> downloadBytes = List<int>.generate(
        512,
        (index) => index % 251,
      );
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(111),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(222),
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
        imageCacheDirectory: phoneCache.path,
        // Online image cache always misses; only the downloaded-gallery
        // resolver serves — the peer must still receive the bytes.
        imageCacheResolver: (href) async => null,
        downloadResolver: (url, pageIndex) async {
          if (url != galleryUrl || pageIndex != 0) {
            return null;
          }
          return LanSharedImage(
            image: <String, dynamic>{
              'url': imageUrl,
              'height': 800.0,
              'width': 600.0,
              'originalImageUrl': null,
              'originalImageHeight': null,
              'originalImageWidth': null,
              'reloadKey': null,
              'imageHash': null,
              'path': null,
              'downloadStatus': 2,
            },
            bytes: downloadBytes,
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
            permissions: const {LanSharePermission.imageCache},
          );

      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      // Host B grants A the downloads permission so the download path opens.
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {
          LanSharePermission.downloads,
          LanSharePermission.imageCache,
        },
      );
      await pairing;
      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      final LanSharedImage? raw = await deviceA.requestImageCache(
        imagePageHref,
        galleryUrl: galleryUrl,
        pageIndex: 0,
      );
      expect(raw, isNotNull);
      expect(raw!.bytes, downloadBytes);
      expect(raw.image['url'], imageUrl);
      expect(deviceA.receivedBytes, downloadBytes.length);
      expect(deviceB.sentBytes, downloadBytes.length);

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await phoneCache.delete(recursive: true);
    },
  );

  test(
    'peer lists the host\'s downloaded galleries with the downloads permission',
    () async {
      final Directory phoneCache = await Directory.systemTemp.createTemp(
        'jh-lan-list-cache-',
      );
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(151),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(252),
        registerWithGet: false,
      );
      await deviceA.doInitBean();
      await deviceB.doInitBean();

      final LanSharedGallerySummary summary = LanSharedGallerySummary(
        deviceId: deviceB.localDeviceId,
        deviceName: deviceB.localDisplayName,
        gid: 123456,
        token: 'abcdefghijklmnop',
        title: 'Test Gallery',
        galleryUrl: 'https://e-hentai.org/g/123456/abcdefgh/',
        pageCount: 12,
        category: 'Manga',
        publishTime: '2026-01-01 00:00',
        coverUrl: 'https://example.test/cover.jpg',
      );
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
        imageCacheDirectory: phoneCache.path,
        galleryListOverride: () => <LanSharedGallerySummary>[summary],
      );
      await runtimeA.doInitBean();
      await runtimeB.doInitBean();

      final LanDiscoveredPeer peerB = _peerFor(deviceB, runtimeB.serverPort!);
      await deviceA.handlePeerDiscovered(peerB);
      final Future<LanPairingAcceptance> pairing = deviceA
          .trustDiscoveredDevice(
            deviceId: deviceB.localDeviceId,
            permissions: const {LanSharePermission.imageCache},
          );
      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      // Host B grants A the downloads permission so the catalog opens.
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {
          LanSharePermission.downloads,
          LanSharePermission.imageCache,
        },
      );
      await pairing;
      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      final List<LanSharedGallerySummary> galleries =
          await deviceA.listDownloadedGalleries();
      expect(galleries, hasLength(1));
      expect(galleries.single.gid, summary.gid);
      expect(galleries.single.token, summary.token);
      expect(galleries.single.title, 'Test Gallery');
      expect(galleries.single.galleryUrl, summary.galleryUrl);
      expect(galleries.single.deviceId, deviceB.localDeviceId);
      expect(galleries.single.coverUrl, summary.coverUrl);

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await phoneCache.delete(recursive: true);
    },
  );

  test(
    'peer lists more than one page of the host\'s downloaded galleries',
    () async {
      final Directory phoneCache = await Directory.systemTemp.createTemp(
        'jh-lan-page-cache-',
      );
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(161),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(262),
        registerWithGet: false,
      );
      await deviceA.doInitBean();
      await deviceB.doInitBean();

      // More than one 50-item page; the incremental "no change" short-circuit
      // must not truncate mid-pagination.
      final List<LanSharedGallerySummary> manySummaries =
          List<LanSharedGallerySummary>.generate(
            55,
            (index) => LanSharedGallerySummary(
              deviceId: deviceB.localDeviceId,
              deviceName: deviceB.localDisplayName,
              gid: 1000 + index,
              token: 'token-$index',
              title: 'Gallery $index',
              galleryUrl: 'https://e-hentai.org/g/${1000 + index}/abcdefgh/',
              pageCount: 1 + index % 20,
              category: 'Manga',
              publishTime: '2026-01-01 00:00',
              coverUrl: 'https://example.test/$index.jpg',
            ),
          );
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
        imageCacheDirectory: phoneCache.path,
        galleryListOverride: () => manySummaries,
      );
      await runtimeA.doInitBean();
      await runtimeB.doInitBean();

      final LanDiscoveredPeer peerB = _peerFor(deviceB, runtimeB.serverPort!);
      await deviceA.handlePeerDiscovered(peerB);
      final Future<LanPairingAcceptance> pairing = deviceA
          .trustDiscoveredDevice(
            deviceId: deviceB.localDeviceId,
            permissions: const {LanSharePermission.imageCache},
          );
      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {
          LanSharePermission.downloads,
          LanSharePermission.imageCache,
        },
      );
      await pairing;
      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      final List<LanSharedGallerySummary> galleries =
          await deviceA.listDownloadedGalleries();
      expect(galleries, hasLength(55));
      expect(galleries.first.gid, 1000);
      expect(galleries.last.gid, 1054);

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await phoneCache.delete(recursive: true);
    },
  );

  test(
    'remote download is rejected when the host has not granted downloads',
    () async {
      final Directory phoneCache = await Directory.systemTemp.createTemp(
        'jh-lan-dl-req-cache-',
      );
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(171),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(272),
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
        imageCacheDirectory: phoneCache.path,
      );
      await runtimeA.doInitBean();
      await runtimeB.doInitBean();

      final LanDiscoveredPeer peerB = _peerFor(deviceB, runtimeB.serverPort!);
      await deviceA.handlePeerDiscovered(peerB);
      final Future<LanPairingAcceptance> pairing = deviceA
          .trustDiscoveredDevice(
            deviceId: deviceB.localDeviceId,
            permissions: const {LanSharePermission.imageCache},
          );
      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      // Host B grants A image cache but NOT the downloads permission, so the
      // remote-download request must be refused.
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {LanSharePermission.imageCache},
      );
      await pairing;
      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      final bool accepted = await deviceA.requestDownloadGallery(
        deviceB.localDeviceId,
        LanRemoteDownloadRequest(
          gid: 999,
          galleryUrl: 'https://e-hentai.org/g/999/abcdefgh/',
          token: 'token',
          title: 'Remote',
          category: 'Manga',
          pageCount: 3,
        ),
      );
      expect(accepted, isFalse);

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await phoneCache.delete(recursive: true);
    },
  );

  test(
    'indexed cache upload can be fetched later by its image-page URL',
    () async {
      final Directory sourceCache = await Directory.systemTemp.createTemp(
        'jh-lan-cache-push-source-',
      );
      final Directory serverCache = await Directory.systemTemp.createTemp(
        'jh-lan-cache-push-server-',
      );
      final LanDeviceTrustService deviceA = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(181),
        registerWithGet: false,
      );
      final LanDeviceTrustService deviceB = LanDeviceTrustService(
        repository: _MemoryTrustRepository(),
        secureRandom: Random(282),
        registerWithGet: false,
      );
      await deviceA.doInitBean();
      await deviceB.doInitBean();
      final LanSharingRuntime runtimeA = LanSharingRuntime(
        trustService: deviceA,
        useServiceDiscovery: false,
        bindAddress: InternetAddress.loopbackIPv4,
        secureRandom: Random(303),
        imageCacheDirectory: sourceCache.path,
      );
      final LanSharingRuntime runtimeB = LanSharingRuntime(
        trustService: deviceB,
        useServiceDiscovery: false,
        bindAddress: InternetAddress.loopbackIPv4,
        secureRandom: Random(404),
        imageCacheDirectory: serverCache.path,
      );
      await runtimeA.doInitBean();
      await runtimeB.doInitBean();

      final LanDiscoveredPeer peerB = _peerFor(deviceB, runtimeB.serverPort!);
      await deviceA.handlePeerDiscovered(peerB);
      final Future<LanPairingAcceptance> pairing = deviceA
          .trustDiscoveredDevice(
            deviceId: deviceB.localDeviceId,
            permissions: const {LanSharePermission.imageCache},
          );
      await _waitUntil(() => deviceB.incomingPairingRequests.isNotEmpty);
      await deviceB.acceptIncomingPairing(
        deviceId: deviceA.localDeviceId,
        permissions: const {LanSharePermission.imageCache},
      );
      await pairing;
      expect(
        deviceA.connectionFor(deviceB.localDeviceId).state,
        LanPeerConnectionState.connected,
      );

      const String imagePageHref = 'https://e-hentai.org/s/hash/123-1';
      const String imageUrl =
          'https://example.test/image.jpg?fileindex=42&keystamp=old';
      final GalleryImage image = GalleryImage(
        url: imageUrl,
        width: 800,
        height: 1200,
      );
      final List<int> bytes = List<int>.generate(64, (index) => index % 251);
      final String cacheKey = normalizedImageCacheKey(imageUrl);
      await File(path.join(sourceCache.path, cacheKey)).writeAsBytes(bytes);
      await runtimeA.recordImagePage(imagePageHref, image);

      final int uploaded = await runtimeA.pushIndexedImageCacheToServer();
      expect(uploaded, 1);
      final File target = File(path.join(serverCache.path, cacheKey));
      expect(await target.readAsBytes(), bytes);
      final LanSharedImage? fetched = await deviceA.requestImageCache(
        imagePageHref,
      );
      expect(fetched, isNotNull);
      expect(fetched!.bytes, bytes);
      expect(fetched.image['url'], imageUrl);

      await runtimeA.stop();
      await runtimeB.stop();
      deviceA.onClose();
      deviceB.onClose();
      await sourceCache.delete(recursive: true);
      await serverCache.delete(recursive: true);
    },
  );

  test(
    'active broadcast auto-accepts an incoming pairing on the host',
    () async {
      advancedSetting.lanActiveBroadcast.value = true;
      try {
        final Directory phoneCache = await Directory.systemTemp.createTemp(
          'jh-lan-auto-pair-',
        );
        final LanDeviceTrustService deviceA = LanDeviceTrustService(
          repository: _MemoryTrustRepository(),
          secureRandom: Random(191),
          registerWithGet: false,
        );
        final LanDeviceTrustService deviceB = LanDeviceTrustService(
          repository: _MemoryTrustRepository(),
          secureRandom: Random(292),
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
          imageCacheDirectory: phoneCache.path,
        );
        await runtimeA.doInitBean();
        await runtimeB.doInitBean();

        final LanDiscoveredPeer peerB = _peerFor(
          deviceB,
          runtimeB.serverPort!,
        );
        // A initiates the pairing; B (active broadcast on) auto-accepts, so
        // no manual acceptIncomingPairing call is needed on B.
        await deviceA.handlePeerDiscovered(peerB);
        await _waitUntil(
          () =>
              deviceA.deviceById(deviceB.localDeviceId) != null &&
              deviceB.deviceById(deviceA.localDeviceId) != null,
        );
        expect(deviceA.deviceById(deviceB.localDeviceId), isNotNull);
        expect(deviceB.deviceById(deviceA.localDeviceId), isNotNull);

        await runtimeA.stop();
        await runtimeB.stop();
        deviceA.onClose();
        deviceB.onClose();
        await phoneCache.delete(recursive: true);
      } finally {
        advancedSetting.lanActiveBroadcast.value = false;
      }
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
    await Future<void>.delayed(Duration.zero);
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
