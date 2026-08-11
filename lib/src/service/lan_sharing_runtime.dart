import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:cryptography/cryptography.dart';
import 'package:extended_image/extended_image.dart'
    show extendedImageDiskCacheDirectory, ExtendedNetworkImageProvider;
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';
import '../model/gallery_thumbnail.dart';
import '../network/eh_request.dart';
import '../setting/advanced_setting.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/image_cache_util.dart';
import 'gallery_download_service.dart';
import 'jh_service.dart';
import 'lan_compute_protocol.dart';
import 'lan_compute_runtime.dart';
import 'lan_device_trust_service.dart';
import 'lan_protocol_v2.dart';
import 'lan_unified_state_service.dart';
import 'log.dart';
import 'path_service.dart';
import '../database/database.dart';
import 'engine/engine_contract.dart';

LanSharingRuntime lanSharingRuntime = LanSharingRuntime();

/// Tracks requests that are waiting for a response from an authenticated LAN
/// session. The scheduler is injectable so timeout cleanup can be tested
/// without waiting for wall-clock time.
class LanPendingRequestRegistry<T> {
  final LanTimerScheduler _timerScheduler;
  final Duration _timeout;
  final Map<String, Completer<T>> _pending = {};
  final Map<String, LanScheduledTask> _timers = {};

  LanPendingRequestRegistry({
    required LanTimerScheduler timerScheduler,
    required Duration timeout,
  }) : _timerScheduler = timerScheduler,
       _timeout = timeout;

  int get length => _pending.length;

  Future<T> register(
    String id, {
    required T timeoutValue,
    void Function()? onTimeout,
  }) {
    if (_pending.containsKey(id)) {
      throw StateError('Duplicate LAN request id: $id');
    }
    final Completer<T> completer = Completer<T>();
    _pending[id] = completer;
    _timers[id] = _timerScheduler.schedule(_timeout, () {
      final Completer<T>? current = _pending.remove(id);
      _timers.remove(id);
      onTimeout?.call();
      if (current != null && !current.isCompleted) {
        current.complete(timeoutValue);
      }
    });
    return completer.future;
  }

  bool complete(String id, T value) {
    final Completer<T>? completer = _pending.remove(id);
    if (completer == null) {
      return false;
    }
    _timers.remove(id)?.cancel();
    if (!completer.isCompleted) {
      completer.complete(value);
    }
    return true;
  }

  void completeAll(T value) {
    for (final LanScheduledTask timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final Completer<T> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }
    _pending.clear();
  }
}

class _LanComputeScheduledTaskAdapter implements LanComputeScheduledTask {
  final LanScheduledTask _delegate;

  const _LanComputeScheduledTaskAdapter(this._delegate);

  @override
  void cancel() => _delegate.cancel();
}

class _LanComputeTimerSchedulerAdapter implements LanComputeTimerScheduler {
  final LanTimerScheduler _delegate;

  const _LanComputeTimerSchedulerAdapter(this._delegate);

  @override
  LanComputeScheduledTask schedule(Duration delay, void Function() callback) =>
      _LanComputeScheduledTaskAdapter(_delegate.schedule(delay, callback));
}

class LanSharingRuntime
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean, LanPeerPairer, LanPeerConnector {
  static const String serviceType = '_jhentai-lan._tcp';
  static const int protocolVersion = LanProtocolV2.version;
  static const int _maxRequestBytes = 64 * 1024;

  final LanDeviceTrustService trustService;
  final bool useServiceDiscovery;
  final InternetAddress bindAddress;
  final Random _secureRandom;
  final LanTimerScheduler _timerScheduler;
  final List<LanComputeExecutor> _computeExecutors;
  final String _computeExecutorId;
  final String? _imageCacheDirectoryOverride;
  final bool _persistImagePageManifest;
  final Future<LanSharedImage?> Function(String imagePageHref)?
  _imageCacheResolverOverride;

  /// Test hook that replaces the downloaded-gallery lookup.
  final Future<LanSharedImage?> Function(String galleryUrl, int pageIndex)?
  _downloadResolverOverride;

  /// Test hook that replaces the host's downloaded-gallery catalog.
  final List<LanSharedGallerySummary> Function()? _galleryListOverride;
  static const Duration pendingRequestTimeout = Duration(seconds: 3);
  final Map<String, GalleryImage> _imagePageManifest = {};
  Future<void> _manifestWrite = Future<void>.value();
  final LanTaskQueue _imageTasks = LanTaskQueue(maxConcurrent: 2);
  Future<void> _secureSendChain = Future<void>.value();

  HttpServer? _server;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  bool _started = false;

  LanSharingRuntime({
    LanDeviceTrustService? trustService,
    this.useServiceDiscovery = true,
    InternetAddress? bindAddress,
    Random? secureRandom,
    LanTimerScheduler? timerScheduler,
    Iterable<LanComputeExecutor> computeExecutors =
        const <LanComputeExecutor>[],
    String computeExecutorId = 'lan-compute-runtime',
    Future<LanSharedImage?> Function(String imagePageHref)? imageCacheResolver,
    Future<LanSharedImage?> Function(String galleryUrl, int pageIndex)?
    downloadResolver,
    List<LanSharedGallerySummary> Function()? galleryListOverride,
    String? imageCacheDirectory,
  }) : trustService = trustService ?? lanDeviceTrustService,
       bindAddress = bindAddress ?? InternetAddress.anyIPv4,
       _secureRandom = secureRandom ?? Random.secure(),
       _timerScheduler = timerScheduler ?? const RealLanTimerScheduler(),
       _computeExecutors = List<LanComputeExecutor>.unmodifiable(
         computeExecutors,
       ),
       _computeExecutorId = computeExecutorId,
       _imageCacheDirectoryOverride = imageCacheDirectory,
       _persistImagePageManifest = trustService == null,
       _imageCacheResolverOverride = imageCacheResolver,
       _downloadResolverOverride = downloadResolver,
       _galleryListOverride = galleryListOverride;

  bool get isRunning => _started;

  bool get isServerRunning => _server != null;

  int? get serverPort => _server?.port;

  @override
  List<JHLifeCircleBean> get initDependencies => [trustService, log];

  @override
  Future<void> doInitBean() async {
    trustService.attachConnector(this);
    trustService.attachPairer(this);
    if (_imageCacheResolverOverride == null && _persistImagePageManifest) {
      await _loadImagePageManifest();
    }
    if (trustService.isEnabled) {
      await start();
    }
  }

  Future<GalleryImage?> fetchCachedImage(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
    String? sourceDeviceId,
  }) async {
    if (!_started || !trustService.isEnabled) {
      return null;
    }
    final LanSharedImage? shared = await trustService.requestImageCache(
      imagePageHref,
      galleryUrl: galleryUrl,
      pageIndex: pageIndex,
      sourceDeviceId: sourceDeviceId,
    );
    if (shared == null || shared.bytes.isEmpty) {
      return null;
    }
    final GalleryImage image = GalleryImage.fromJson(shared.image);
    if (advancedSetting.lanServerMode.value) {
      // Server mode: the host holds the image, so keep THIS device's persistent
      // cache minimal — materialize the LAN bytes to a transient temp file and
      // let the reader load from it instead of bloating the disk cache.
      final String fileName =
          'lan_${normalizedImageCacheKey(effectiveEHImageUrl(image.url))}';
      final File tempFile = File(path.join(pathService.tempDir.path, fileName));
      await tempFile.writeAsBytes(shared.bytes, flush: true);
      return image.copyWith(path: tempFile.path);
    }
    final String cacheKey = normalizedImageCacheKey(
      effectiveEHImageUrl(image.url),
    );
    final String? cacheDirectory =
        _imageCacheDirectoryOverride ?? extendedImageDiskCacheDirectory;
    if (cacheDirectory == null) {
      return null;
    }
    final File target = File(path.join(cacheDirectory, cacheKey));
    if (!await target.exists()) {
      await target.parent.create(recursive: true);
      final File temporary = File(
        '${target.path}.lan-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        await temporary.writeAsBytes(shared.bytes, flush: true);
        await temporary.rename(target.path);
      } finally {
        if (await temporary.exists()) {
          await temporary.delete();
        }
      }
    }
    await recordImagePage(imagePageHref, image);
    return image;
  }

  Future<void> recordImagePage(String imagePageHref, GalleryImage image) async {
    if (_imageCacheResolverOverride != null || !_persistImagePageManifest) {
      return;
    }
    _imagePageManifest[_canonicalImagePageKey(imagePageHref)] = image;
    _manifestWrite = _manifestWrite
        .then((_) => _saveImagePageManifest())
        .catchError((Object error) {
          log.warning('Save LAN image cache manifest failed: $error');
        });
    await _manifestWrite;
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> setEnabled(bool value) async {
    if (value) {
      await trustService.setEnabled(true);
      try {
        await start();
      } on Object {
        await trustService.setEnabled(false);
        rethrow;
      }
    } else {
      try {
        await stop();
      } finally {
        await trustService.setEnabled(false);
      }
    }
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    if (!trustService.isEnabled) {
      throw StateError('LAN sharing is disabled');
    }
    // Pairing and authenticated peer sessions are bidirectional. Every device
    // therefore needs a small inbound transport endpoint, including mobile
    // clients. `lanServerMode` only controls the desktop content/compute role;
    // it must not disable the transport required to approve a phone pairing.
    _server = await HttpServer.bind(bindAddress, 0, shared: false);
    _server!.listen(
      (request) => unawaited(_handleRequest(request)),
      onError: (Object error, StackTrace stack) {
        log.warning('LAN peer endpoint failed: $error');
        log.trace(stack);
      },
    );
    try {
      if (useServiceDiscovery) {
        await _startServiceDiscovery();
      }
      _started = true;
    } on Object {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _started = false;
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    final BonsoirDiscovery? discovery = _discovery;
    _discovery = null;
    if (discovery != null && !discovery.isStopped) {
      await discovery.stop();
    }
    final BonsoirBroadcast? broadcast = _broadcast;
    _broadcast = null;
    if (broadcast != null && !broadcast.isStopped) {
      await broadcast.stop();
    }
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _startServiceDiscovery() async {
    if (_server != null) {
      final BonsoirService service = BonsoirService(
        name: trustService.localDeviceId,
        type: serviceType,
        port: _server!.port,
        attributes: {
          'v': '$protocolVersion',
          'id': trustService.localDeviceId,
          'name': trustService.localDisplayName,
          'pk': trustService.localIdentityPublicKey,
          'fp': trustService.localIdentityFingerprint,
          'caps': LanComputeRuntime.sessionCapabilities.join(','),
        },
      );
      final BonsoirBroadcast broadcast = BonsoirBroadcast(
        service: service,
        printLogs: false,
      );
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;
    }

    final BonsoirDiscovery discovery = BonsoirDiscovery(
      type: serviceType,
      printLogs: false,
    );
    await discovery.initialize();
    _discoverySubscription = discovery.eventStream!.listen(
      (event) => unawaited(_handleDiscoveryEventSafely(discovery, event)),
      onError: (Object error, StackTrace stack) {
        log.warning('LAN mDNS discovery failed: $error');
        log.trace(stack);
      },
    );
    await discovery.start();
    _discovery = discovery;
  }

  LanComputePlatform get _computePlatform => switch (Platform.operatingSystem) {
    'ios' => LanComputePlatform.ios,
    'android' => LanComputePlatform.android,
    'macos' => LanComputePlatform.macos,
    'windows' => LanComputePlatform.windows,
    'linux' => LanComputePlatform.linux,
    _ => LanComputePlatform.unknown,
  };

  Future<void> _handleDiscoveryEventSafely(
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
  ) async {
    try {
      await _handleDiscoveryEvent(discovery, event);
    } on Object catch (error, stack) {
      log.warning('LAN discovery event failed: $error');
      log.trace(stack);
    }
  }

  Future<void> _handleDiscoveryEvent(
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
  ) async {
    if (event case BonsoirDiscoveryServiceFoundEvent()) {
      await event.service.resolve(discovery.serviceResolver);
      return;
    }
    if (event case BonsoirDiscoveryServiceLostEvent()) {
      final String? deviceId = event.service.attributes['id'];
      if (deviceId != null) {
        trustService.ignoreDiscoveredDevice(deviceId);
      }
      return;
    }
    final BonsoirService? service = switch (event) {
      BonsoirDiscoveryServiceResolvedEvent() => event.service,
      BonsoirDiscoveryServiceUpdatedEvent() => event.service,
      _ => null,
    };
    if (service == null ||
        service.attributes['id'] == trustService.localDeviceId) {
      return;
    }
    final LanDiscoveredPeer? peer = _peerFromService(service);
    if (peer != null) {
      await trustService.handlePeerDiscovered(peer);
    }
  }

  LanDiscoveredPeer? _peerFromService(BonsoirService service) {
    final String? deviceId = service.attributes['id'];
    final String? publicKey = service.attributes['pk'];
    final String? fingerprint = service.attributes['fp'];
    final int? version = int.tryParse(service.attributes['v'] ?? '');
    final String? host = _selectHost(service.hostAddresses);
    if (deviceId == null ||
        publicKey == null ||
        fingerprint == null ||
        version == null ||
        host == null ||
        service.port < 1) {
      return null;
    }
    return LanDiscoveredPeer(
      deviceId: deviceId,
      displayName: service.attributes['name'] ?? service.name,
      host: host,
      port: service.port,
      identityPublicKey: publicKey,
      identityFingerprint: fingerprint,
      protocolVersion: version,
    );
  }

  String? _selectHost(List<String> addresses) {
    final List<InternetAddress> parsed =
        addresses
            .map((address) {
              try {
                return InternetAddress(address);
              } on ArgumentError {
                return null;
              }
            })
            .whereType<InternetAddress>()
            .where((address) => !address.isLoopback)
            .toList();
    for (final InternetAddress address in parsed) {
      if (address.type == InternetAddressType.IPv4 &&
          _isLocalNetworkAddress(address)) {
        return address.address;
      }
    }
    for (final InternetAddress address in parsed) {
      if (_isLocalNetworkAddress(address)) {
        return address.address;
      }
    }
    return null;
  }

  @override
  Future<LanPairingExchange> requestPairing({
    required LanDiscoveredPeer peer,
    required String localDeviceId,
    required String localIdentityPublicKey,
    required String localIdentityFingerprint,
  }) async {
    final String localToken = _randomBase64Url(32);
    final String nonce = _randomBase64Url(24);
    final Map<String, dynamic> payload = {
      'deviceId': localDeviceId,
      'displayName': trustService.localDisplayName,
      'identityPublicKey': localIdentityPublicKey,
      'identityFingerprint': localIdentityFingerprint,
      'port': _server?.port ?? 0,
      'protocolVersion': protocolVersion,
      'accessTokenForRemote': localToken,
      'nonce': nonce,
    };
    final String canonical = jsonEncode(payload);
    final List<int> signature = await trustService.signChallenge(
      utf8.encode(canonical),
    );
    final Map<String, dynamic> requestBody = {
      ...payload,
      'signature': _encodeBytes(signature),
    };
    final Map<String, dynamic> response = await _postJson(
      peer,
      '/v1/pair',
      requestBody,
      timeout: const Duration(minutes: 2, seconds: 10),
    );
    if (response['requestNonce'] != nonce ||
        response['deviceId'] != peer.deviceId ||
        response['identityPublicKey'] != peer.identityPublicKey ||
        response['identityFingerprint'] != peer.identityFingerprint) {
      throw const FormatException('LAN pairing identity changed');
    }
    final Map<String, dynamic> signedResponse = {
      'deviceId': response['deviceId'],
      'displayName': response['displayName'],
      'identityPublicKey': response['identityPublicKey'],
      'identityFingerprint': response['identityFingerprint'],
      'accessTokenForRemote': response['accessTokenForRemote'],
      'requestNonce': response['requestNonce'],
    };
    final bool valid = await _verifySignature(
      publicKey: peer.identityPublicKey,
      message: utf8.encode(jsonEncode(signedResponse)),
      signature: _decodeBytes(response['signature'] as String? ?? ''),
    );
    if (!valid) {
      throw const FormatException('Invalid LAN pairing response signature');
    }
    return LanPairingExchange(
      remoteAccessToken: response['accessTokenForRemote'] as String,
      localInboundAccessToken: localToken,
    );
  }

  @override
  Future<LanPeerSession> connect({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) async {
    if (peer.protocolVersion != LanProtocolV2.version) {
      throw const FormatException('LAN_PROTOCOL_UPGRADE_REQUIRED');
    }
    return _connectV2(
      peer: peer,
      accessToken: accessToken,
      expectedIdentityPublicKey: expectedIdentityPublicKey,
      expectedIdentityFingerprint: expectedIdentityFingerprint,
    );
  }

  Future<LanPeerSession> _connectLegacy({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) async {
    if (peer.identityPublicKey != expectedIdentityPublicKey ||
        peer.identityFingerprint != expectedIdentityFingerprint) {
      throw const FormatException('LAN peer identity changed');
    }
    final Uri uri = Uri(
      scheme: 'ws',
      host: peer.host,
      port: peer.port,
      path: '/v1/session',
    );
    final WebSocket socket = await WebSocket.connect(
      uri.toString(),
    ).timeout(const Duration(seconds: 10));
    socket.pingInterval = const Duration(seconds: 20);
    final StreamIterator<dynamic> iterator = StreamIterator(socket);
    try {
      final X25519 x25519 = X25519();
      final SimpleKeyPair clientEphemeral = await x25519.newKeyPair();
      final SimplePublicKey clientEphemeralPublic =
          await clientEphemeral.extractPublicKey();
      final List<int> clientNonce = _randomBytes(32);
      final Map<String, dynamic> clientHello = {
        'type': 'hello',
        'versions': [LanProtocolV2.version, LanProtocolV2.legacyVersion],
        'deviceId': trustService.localDeviceId,
        'identityFingerprint': trustService.localIdentityFingerprint,
        'ephemeralPublicKey': LanProtocolV2.encodeBytes(
          clientEphemeralPublic.bytes,
        ),
        'nonce': LanProtocolV2.encodeBytes(clientNonce),
        'capabilities': LanComputeRuntime.sessionCapabilities,
      };
      final List<int> clientSignature = await trustService.signChallenge(
        utf8.encode(LanProtocolV2.canonicalJson(clientHello)),
      );
      socket.add(
        jsonEncode({
          ...clientHello,
          'signature': LanProtocolV2.encodeBytes(clientSignature),
        }),
      );
      final Map<String, dynamic> serverHelloWithSignature =
          await _nextSocketJson(iterator);
      if (serverHelloWithSignature['type'] != 'hello_ack' ||
          serverHelloWithSignature['version'] != LanProtocolV2.version ||
          serverHelloWithSignature['deviceId'] != peer.deviceId ||
          serverHelloWithSignature['identityFingerprint'] !=
              peer.identityFingerprint) {
        throw const FormatException('Invalid LAN v2 session hello');
      }
      final Map<String, dynamic> serverHello = Map<String, dynamic>.from(
        serverHelloWithSignature,
      )..remove('signature');
      final bool validServerSignature = await trustService.verifyPeerChallenge(
        deviceId: peer.deviceId,
        challenge: utf8.encode(LanProtocolV2.canonicalJson(serverHello)),
        signature: LanProtocolV2.decodeBytes(
          serverHelloWithSignature['signature'] as String? ?? '',
        ),
      );
      if (!validServerSignature) {
        throw const FormatException('Invalid LAN v2 server identity proof');
      }
      final List<int> serverNonce = LanProtocolV2.decodeBytes(
        serverHello['nonce'] as String? ?? '',
      );
      final SimplePublicKey serverEphemeralPublic = SimplePublicKey(
        LanProtocolV2.decodeBytes(
          serverHello['ephemeralPublicKey'] as String? ?? '',
        ),
        type: KeyPairType.x25519,
      );
      final LanSecureSession secureSession = await LanSecureSession.derive(
        localEphemeralKeyPair: clientEphemeral,
        remoteEphemeralPublicKey: serverEphemeralPublic,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        transcript: utf8.encode(
          LanProtocolV2.canonicalJson({
            'client': clientHello,
            'server': serverHello,
          }),
        ),
        isClient: true,
      );
      clientEphemeral.destroy();
      socket.add(
        jsonEncode(
          await secureSession.encrypt({
            'type': 'auth',
            'deviceId': trustService.localDeviceId,
            'accessToken': accessToken,
          }),
        ),
      );
      final Map<String, dynamic> authAck = await secureSession.decrypt(
        await _nextSocketJson(iterator),
      );
      if (authAck['type'] != 'auth_ack') {
        throw const FormatException('LAN v2 authentication was not accepted');
      }
      return _WebSocketLanPeerSession(
        socket,
        iterator,
        onBytesReceived: trustService.recordTrafficReceived,
        secureSession: secureSession,
        supportsImageCache: true,
        capabilities:
            (authAck['capabilities'] as List? ?? const [])
                .whereType<String>()
                .toSet(),
        timerScheduler: _timerScheduler,
      );
    } on Object {
      await iterator.cancel();
      await socket.close();
      rethrow;
    }
  }

  Future<LanPeerSession> _connectV2({
    required LanDiscoveredPeer peer,
    required String accessToken,
    required String expectedIdentityPublicKey,
    required String expectedIdentityFingerprint,
  }) async {
    final Uri uri = Uri(
      scheme: 'ws',
      host: peer.host,
      port: peer.port,
      path: '/v1/session',
    );
    final WebSocket socket = await WebSocket.connect(
      uri.toString(),
    ).timeout(const Duration(seconds: 10));
    socket.pingInterval = const Duration(seconds: 20);
    final StreamIterator<dynamic> iterator = StreamIterator(socket);
    final SimpleKeyPair ephemeral = await X25519().newKeyPair();
    try {
      final SimplePublicKey ephemeralPublic =
          await ephemeral.extractPublicKey();
      final Map<String, dynamic> clientHello = <String, dynamic>{
        'type': 'hello',
        'versions': [LanProtocolV2.version, LanProtocolV2.legacyVersion],
        'deviceId': trustService.localDeviceId,
        'identityFingerprint': trustService.localIdentityFingerprint,
        'ephemeralPublicKey': _encodeBytes(ephemeralPublic.bytes),
        'nonce': _randomBase64Url(32),
        'capabilities': LanComputeRuntime.sessionCapabilities,
      };
      final List<int> clientSignature = await trustService.signChallenge(
        utf8.encode(LanProtocolV2.canonicalJson(clientHello)),
      );
      socket.add(
        jsonEncode(<String, dynamic>{
          ...clientHello,
          'signature': _encodeBytes(clientSignature),
        }),
      );
      final Map<String, dynamic> serverHelloWithSignature =
          await _nextSocketJson(iterator);
      if (serverHelloWithSignature['type'] != 'hello_ack' ||
          serverHelloWithSignature['version'] != LanProtocolV2.version ||
          serverHelloWithSignature['deviceId'] != peer.deviceId ||
          serverHelloWithSignature['identityFingerprint'] !=
              expectedIdentityFingerprint) {
        throw const FormatException(
          'LAN v2 server identity or version mismatch',
        );
      }
      final Map<String, dynamic> serverHello = Map<String, dynamic>.from(
        serverHelloWithSignature,
      )..remove('signature');
      if (!await trustService.verifyPeerChallenge(
        deviceId: peer.deviceId,
        challenge: utf8.encode(LanProtocolV2.canonicalJson(serverHello)),
        signature: _decodeBytes(
          serverHelloWithSignature['signature'] as String? ?? '',
        ),
      )) {
        throw const FormatException('LAN v2 server hello signature invalid');
      }
      final List<int> clientNonce = _decodeBytes(
        clientHello['nonce'] as String,
      );
      final List<int> serverNonce = _decodeBytes(
        serverHello['nonce'] as String? ?? '',
      );
      final List<int> transcript = _v2Transcript(clientHello, serverHello);
      final LanSecureSession secureSession = await LanSecureSession.derive(
        localEphemeralKeyPair: ephemeral,
        remoteEphemeralPublicKey: SimplePublicKey(
          _decodeBytes(serverHello['ephemeralPublicKey'] as String? ?? ''),
          type: KeyPairType.x25519,
        ),
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        transcript: transcript,
        isClient: true,
      );
      socket.add(
        jsonEncode(
          await secureSession.encrypt({
            'type': 'auth',
            'deviceId': trustService.localDeviceId,
            'accessToken': accessToken,
          }),
        ),
      );
      final Map<String, dynamic> ack = await secureSession.decrypt(
        await _nextSocketJson(iterator),
      );
      if (ack['type'] != 'auth_ack') {
        throw const FormatException('LAN v2 authentication failed');
      }
      return _WebSocketLanPeerSession(
        socket,
        iterator,
        onBytesReceived: trustService.recordTrafficReceived,
        supportsImageCache: true,
        capabilities:
            (ack['capabilities'] as List? ?? const [])
                .whereType<String>()
                .toSet(),
        timerScheduler: _timerScheduler,
        secureSession: secureSession,
      );
    } on Object {
      ephemeral.destroy();
      await iterator.cancel();
      await socket.close();
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final InternetAddress? remote = request.connectionInfo?.remoteAddress;
      if (remote == null || !_isLocalNetworkAddress(remote)) {
        await _sendJson(request.response, HttpStatus.forbidden, {
          'error': 'local_network_only',
        });
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/status') {
        await _sendJson(request.response, HttpStatus.ok, _localIdentityJson());
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/pair') {
        await _handlePairRequest(request);
        return;
      }
      if (request.uri.path == '/v1/session' &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        await _handleSessionRequest(request);
        return;
      }
      await _sendJson(request.response, HttpStatus.notFound, {
        'error': 'not_found',
      });
    } on Object catch (error, stack) {
      log.warning('LAN request failed: $error');
      log.trace(stack);
      try {
        await _sendJson(request.response, HttpStatus.badRequest, {
          'error': 'invalid_request',
        });
      } on Object {
        await request.response.close();
      }
    }
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    if (!trustService.isEnabled) {
      await _sendJson(request.response, HttpStatus.serviceUnavailable, {
        'error': 'lan_disabled',
      });
      return;
    }
    final Map<String, dynamic> body = await _readJson(request);
    final Map<String, dynamic> signedPayload = {
      'deviceId': body['deviceId'],
      'displayName': body['displayName'],
      'identityPublicKey': body['identityPublicKey'],
      'identityFingerprint': body['identityFingerprint'],
      'port': body['port'],
      'protocolVersion': body['protocolVersion'],
      'accessTokenForRemote': body['accessTokenForRemote'],
      'nonce': body['nonce'],
    };
    final String publicKey = body['identityPublicKey'] as String? ?? '';
    final String fingerprint = body['identityFingerprint'] as String? ?? '';
    if (TrustedLanDevice.fingerprintForPublicKey(publicKey) != fingerprint ||
        !await _verifySignature(
          publicKey: publicKey,
          message: utf8.encode(jsonEncode(signedPayload)),
          signature: _decodeBytes(body['signature'] as String? ?? ''),
        )) {
      throw const FormatException('Invalid LAN pairing signature');
    }
    final LanDiscoveredPeer peer = LanDiscoveredPeer(
      deviceId: body['deviceId'] as String? ?? '',
      displayName: body['displayName'] as String? ?? '',
      host: request.connectionInfo!.remoteAddress.address,
      port: body['port'] as int? ?? 0,
      identityPublicKey: publicKey,
      identityFingerprint: fingerprint,
      protocolVersion: body['protocolVersion'] as int? ?? 0,
    );
    final LanPairingAcceptance? acceptance = await trustService
        .requestIncomingPairingApproval(
          peer: peer,
          remoteAccessToken: body['accessTokenForRemote'] as String? ?? '',
        );
    if (acceptance == null) {
      await _sendJson(request.response, HttpStatus.forbidden, {
        'error': 'pairing_declined',
      });
      return;
    }
    final Map<String, dynamic> response = {
      'deviceId': trustService.localDeviceId,
      'displayName': trustService.localDisplayName,
      'identityPublicKey': trustService.localIdentityPublicKey,
      'identityFingerprint': trustService.localIdentityFingerprint,
      'accessTokenForRemote': acceptance.accessTokenForRemote,
      'requestNonce': body['nonce'],
    };
    final List<int> signature = await trustService.signChallenge(
      utf8.encode(jsonEncode(response)),
    );
    await _sendJson(request.response, HttpStatus.ok, {
      ...response,
      'signature': _encodeBytes(signature),
    });
  }

  Future<void> _handleSessionRequest(HttpRequest request) async {
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 20);
    final StreamIterator<dynamic> iterator = StreamIterator(socket);
    try {
      final Map<String, dynamic> auth = await _nextSocketJson(iterator);
      if (auth['type'] == 'hello' &&
          (auth['versions'] as List? ?? const []).whereType<num>().any(
            (num version) => version.toInt() == LanProtocolV2.version,
          )) {
        await _handleV2Session(socket, iterator, auth);
        return;
      }
      throw const FormatException('LAN_PROTOCOL_UPGRADE_REQUIRED');
    } on Object catch (error) {
      await socket.close(WebSocketStatus.protocolError, error.toString());
    } finally {
      await iterator.cancel();
    }
  }

  Future<void> _handleV2Session(
    WebSocket socket,
    StreamIterator<dynamic> iterator,
    Map<String, dynamic> clientHello,
  ) async {
    final String deviceId = clientHello['deviceId'] as String? ?? '';
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    final Map<String, dynamic> unsignedClient = Map<String, dynamic>.from(
      clientHello,
    )..remove('signature');
    final String presentedFingerprint =
        clientHello['identityFingerprint'] as String? ?? '';
    final LanProtocolNegotiation? negotiation =
        LanProtocolNegotiation.negotiate(
          offered: (clientHello['versions'] as List? ?? const [])
              .whereType<num>()
              .map((num value) => value.toInt()),
          supported: const [LanProtocolV2.version],
        );
    final bool identityValid =
        device != null &&
        device.identityFingerprint == presentedFingerprint &&
        negotiation != null &&
        await trustService.verifyPeerChallenge(
          deviceId: deviceId,
          challenge: utf8.encode(LanProtocolV2.canonicalJson(unsignedClient)),
          signature: _decodeBytes(clientHello['signature'] as String? ?? ''),
        );
    if (!identityValid) {
      await socket.close(WebSocketStatus.policyViolation, 'auth_failed');
      return;
    }
    final SimpleKeyPair ephemeral = await X25519().newKeyPair();
    LanComputeHostRuntime? computeRuntime;
    try {
      final SimplePublicKey ephemeralPublic =
          await ephemeral.extractPublicKey();
      final List<int> clientNonce = _decodeBytes(
        clientHello['nonce'] as String? ?? '',
      );
      final List<int> serverNonce = _randomBytes(32);
      final Map<String, dynamic> serverHello = <String, dynamic>{
        'type': 'hello_ack',
        'version': negotiation!.version,
        'deviceId': trustService.localDeviceId,
        'identityFingerprint': trustService.localIdentityFingerprint,
        'ephemeralPublicKey': _encodeBytes(ephemeralPublic.bytes),
        'nonce': _encodeBytes(serverNonce),
        'cipherSuite': LanProtocolV2.cipherSuite,
        'capabilities': LanProtocolV2.negotiateCapabilities(
          (clientHello['capabilities'] as List? ?? const [])
              .whereType<String>(),
          LanComputeRuntime.sessionCapabilities,
        ),
      };
      final List<int> serverSignature = await trustService.signChallenge(
        utf8.encode(LanProtocolV2.canonicalJson(serverHello)),
      );
      socket.add(
        jsonEncode(<String, dynamic>{
          ...serverHello,
          'signature': _encodeBytes(serverSignature),
        }),
      );
      final List<int> transcript = _v2Transcript(unsignedClient, serverHello);
      final LanSecureSession secureSession = await LanSecureSession.derive(
        localEphemeralKeyPair: ephemeral,
        remoteEphemeralPublicKey: SimplePublicKey(
          _decodeBytes(clientHello['ephemeralPublicKey'] as String? ?? ''),
          type: KeyPairType.x25519,
        ),
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        transcript: transcript,
        isClient: false,
      );
      final Map<String, dynamic> auth = await secureSession.decrypt(
        await _nextSocketJson(iterator),
      );
      final bool accepted = await trustService.authenticateInbound(
        deviceId: deviceId,
        identityFingerprint: presentedFingerprint,
        presentedToken: auth['accessToken'] as String? ?? '',
        challenge: utf8.encode(LanProtocolV2.canonicalJson(unsignedClient)),
        challengeSignature: _decodeBytes(
          clientHello['signature'] as String? ?? '',
        ),
      );
      if (!accepted || auth['type'] != 'auth' || auth['deviceId'] != deviceId) {
        secureSession.close();
        await socket.close(WebSocketStatus.policyViolation, 'auth_failed');
        return;
      }
      final _LanV2SocketChannel channel = _LanV2SocketChannel(
        socket: socket,
        iterator: iterator,
        secureSession: secureSession,
      );
      await channel.send(<String, dynamic>{
        'type': 'auth_ack',
        'capabilities': serverHello['capabilities'],
      });
      if ((serverHello['capabilities'] as List? ?? const [])
          .whereType<String>()
          .contains(LanComputeRuntime.sessionCapability)) {
        computeRuntime = LanComputeHostRuntime(
          executorIdentity: LanComputeExecutorIdentity(
            deviceId: trustService.localDeviceId,
            executorId: _computeExecutorId,
            platform: _computePlatform,
          ),
          remoteDeviceId: deviceId,
          isAuthorized: (LanComputeCapability capability) {
            final TrustedLanDevice? current = trustService.deviceById(deviceId);
            final LanSharePermission permission = switch (capability) {
              LanComputeCapability.ocr => LanSharePermission.ocrCompute,
              LanComputeCapability.translation =>
                LanSharePermission.translationCompute,
            };
            return current?.permissions.contains(permission) ?? false;
          },
          executors: _computeExecutors,
          timerScheduler: _LanComputeTimerSchedulerAdapter(_timerScheduler),
        );
        await computeRuntime.advertise(
          (LanComputeMessage message) =>
              channel.send(LanComputeRuntime.envelope(message)),
        );
      }
      while (true) {
        final Map<String, dynamic>? message = await channel.receive();
        if (message == null) {
          break;
        }
        if (message['type'] == LanComputeRuntime.envelopeType) {
          if (computeRuntime == null) {
            await channel.send(
              LanComputeRuntime.envelope(
                LanComputeRuntime.unsupportedFor(message),
              ),
            );
          } else {
            await computeRuntime.handleEnvelope(
              message,
              (LanComputeMessage response) =>
                  channel.send(LanComputeRuntime.envelope(response)),
            );
          }
          continue;
        }
        if (message['type'] != 'request') {
          continue;
        }
        final String requestId = message['id'] as String? ?? '';
        final String operation = message['op'] as String? ?? '';
        if (requestId.isEmpty) {
          throw const FormatException('LAN v2 request id is missing');
        }
        if (operation == 'list_galleries') {
          await _handleV2ListGalleries(channel, deviceId, requestId, message);
        } else if (operation == 'gallery_manifest') {
          await _handleV2GalleryManifest(channel, deviceId, requestId, message);
        } else if (operation == 'cache_image') {
          unawaited(
            _imageTasks.run(
              () => _handleV2Image(channel, deviceId, requestId, message),
            ),
          );
        } else if (operation == 'login_state') {
          await _handleV2LoginState(channel, deviceId, requestId);
        } else if (operation == 'application_history') {
          await _handleV2ApplicationHistory(channel, deviceId, requestId);
        }
      }
      secureSession.close();
    } finally {
      await computeRuntime?.close();
      ephemeral.destroy();
    }
  }

  /// Replies to a peer's `list_galleries` request with this device's downloaded
  /// galleries, but only when the peer holds the `downloads` permission.
  Future<void> _handleListGalleries(
    WebSocket socket,
    String deviceId,
    String requestId,
  ) async {
    final List<LanSharedGallerySummary> summaries = [];
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    if (device != null &&
        device.permissions.contains(LanSharePermission.downloads)) {
      summaries.addAll(
        _galleryListOverride?.call() ?? _localGallerySummaries(),
      );
    }
    socket.add(
      jsonEncode({
        'type': 'list_galleries_result',
        'id': requestId,
        'galleries':
            summaries
                .map((LanSharedGallerySummary summary) => summary.toJson())
                .toList(),
      }),
    );
  }

  Future<void> _handleV2ListGalleries(
    _LanV2SocketChannel channel,
    String deviceId,
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    if (device == null ||
        !device.permissions.contains(LanSharePermission.downloads)) {
      await channel.send(<String, dynamic>{
        'type': 'response',
        'id': requestId,
        'op': 'list_galleries',
        'ok': true,
        'data': const <String, dynamic>{
          'revision': '',
          'nextCursor': null,
          'galleries': <dynamic>[],
        },
      });
      return;
    }
    final List<LanSharedGallerySummary> summaries =
        _galleryListOverride?.call() ?? _localGallerySummaries();
    final String revision = summaries
        .map(
          (LanSharedGallerySummary gallery) =>
              '${gallery.gid}:${gallery.pageCount}',
        )
        .join('|');
    final Map<String, dynamic> params = Map<String, dynamic>.from(
      request['params'] as Map? ?? const <String, dynamic>{},
    );
    if (params['knownRevision'] == revision) {
      await channel.send(<String, dynamic>{
        'type': 'response',
        'id': requestId,
        'op': 'list_galleries',
        'ok': true,
        'data':
            LanSharedGalleryPage(
              revision: revision,
              nextCursor: null,
              galleries: const [],
              incremental: true,
            ).toJson(),
      });
      return;
    }
    final int cursor = max(0, (params['cursor'] as num?)?.toInt() ?? 0);
    final int limit = ((params['limit'] as num?)?.toInt() ?? 50).clamp(1, 100);
    final int end = min(cursor + limit, summaries.length);
    final LanSharedGalleryPage page = LanSharedGalleryPage(
      revision: revision,
      nextCursor: end < summaries.length ? '$end' : null,
      galleries: summaries.sublist(cursor.clamp(0, summaries.length), end),
    );
    await channel.send(<String, dynamic>{
      'type': 'response',
      'id': requestId,
      'op': 'list_galleries',
      'ok': true,
      'data': page.toJson(),
    });
  }

  Future<void> _handleV2GalleryManifest(
    _LanV2SocketChannel channel,
    String deviceId,
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    final String galleryUrl =
        (request['params'] as Map?)?['galleryUrl'] as String? ?? '';
    if (device == null ||
        !device.permissions.contains(LanSharePermission.downloads) ||
        galleryUrl.isEmpty) {
      await channel.send(<String, dynamic>{
        'type': 'response',
        'id': requestId,
        'op': 'gallery_manifest',
        'ok': false,
      });
      return;
    }
    final LanGalleryManifest? manifest = await _buildGalleryManifest(
      galleryUrl,
    );
    await channel.send(<String, dynamic>{
      'type': 'response',
      'id': requestId,
      'op': 'gallery_manifest',
      'ok': manifest != null,
      if (manifest != null) 'data': manifest.toJson(),
    });
  }

  Future<void> _handleV2LoginState(
    _LanV2SocketChannel channel,
    String deviceId,
    String requestId,
  ) async {
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    if (device == null ||
        !device.permissions.contains(LanSharePermission.loginState)) {
      await channel.send(<String, dynamic>{
        'type': 'response',
        'id': requestId,
        'op': 'login_state',
        'ok': false,
        'error': 'permission_denied',
      });
      return;
    }
    final LanLoginStateSnapshot? snapshot = await lanUnifiedStateService
        .exportLoginState(sourceDeviceId: trustService.localDeviceId);
    await channel.send(<String, dynamic>{
      'type': 'response',
      'id': requestId,
      'op': 'login_state',
      'ok': snapshot != null,
      if (snapshot != null)
        'data':
            LanUnifiedStatePayload(
              capability: 'loginStateV1',
              sourceDeviceId: trustService.localDeviceId,
              generatedAt: DateTime.now().toUtc(),
              loginState: snapshot,
            ).toJson(),
      if (snapshot == null) 'error': 'source_not_logged_in',
    });
  }

  Future<void> _handleV2ApplicationHistory(
    _LanV2SocketChannel channel,
    String deviceId,
    String requestId,
  ) async {
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    if (device == null ||
        !device.permissions.contains(LanSharePermission.applicationHistory)) {
      await channel.send(<String, dynamic>{
        'type': 'response',
        'id': requestId,
        'op': 'application_history',
        'ok': false,
        'error': 'permission_denied',
      });
      return;
    }
    final LanUnifiedStatePayload payload = await lanUnifiedStateService
        .exportHistory(sourceDeviceId: trustService.localDeviceId);
    await channel.send(<String, dynamic>{
      'type': 'response',
      'id': requestId,
      'op': 'application_history',
      'ok': true,
      'data': payload.toJson(),
    });
  }

  Future<void> _handleV2Image(
    _LanV2SocketChannel channel,
    String deviceId,
    String requestId,
    Map<String, dynamic> request,
  ) async {
    final TrustedLanDevice? device = trustService.deviceById(deviceId);
    if (device == null) {
      await channel.send(<String, dynamic>{
        'type': 'image_miss',
        'id': requestId,
      });
      return;
    }
    final bool allowCache = device.permissions.contains(
      LanSharePermission.imageCache,
    );
    final bool allowDownloads = device.permissions.contains(
      LanSharePermission.downloads,
    );
    if (!allowCache && !allowDownloads) {
      await channel.send(<String, dynamic>{
        'type': 'image_miss',
        'id': requestId,
      });
      return;
    }
    final Map<String, dynamic> params = Map<String, dynamic>.from(
      request['params'] as Map? ?? const <String, dynamic>{},
    );
    final String href = params['href'] as String? ?? '';
    final String galleryUrl = params['galleryUrl'] as String? ?? '';
    final int? pageIndex = (params['pageIndex'] as num?)?.toInt();
    LanSharedImage? shared;
    if (allowCache) {
      shared =
          await (_imageCacheResolverOverride?.call(href) ??
              _resolveLocalImageCache(href));
    }
    if ((shared == null || shared.bytes.isEmpty) &&
        allowDownloads &&
        galleryUrl.isNotEmpty &&
        pageIndex != null) {
      shared =
          await (_downloadResolverOverride?.call(galleryUrl, pageIndex) ??
              _resolveLocalDownload(galleryUrl, pageIndex));
    }
    if (shared == null || shared.bytes.isEmpty) {
      await channel.send(<String, dynamic>{
        'type': 'image_miss',
        'id': requestId,
      });
      return;
    }
    await channel.send(<String, dynamic>{
      'type': 'image_begin',
      'id': requestId,
      'image': shared.image,
      'byteLength': shared.bytes.length,
    });
    for (
      int offset = 0, chunkIndex = 0;
      offset < shared.bytes.length;
      offset += LanProtocolV2.maxImageChunkBytes, chunkIndex++
    ) {
      final int end = min(
        offset + LanProtocolV2.maxImageChunkBytes,
        shared.bytes.length,
      );
      await channel.send(<String, dynamic>{
        'type': 'image_chunk',
        'id': requestId,
        'index': chunkIndex,
        'final': end == shared.bytes.length,
        'data': _encodeBytes(shared.bytes.sublist(offset, end)),
      });
    }
    trustService.recordTrafficSent(shared.bytes.length);
  }

  Future<LanGalleryManifest?> _buildGalleryManifest(String galleryUrl) async {
    final GalleryDownloadedData? gallery = _findDownloadedGallery(galleryUrl);
    if (gallery == null) {
      return null;
    }
    final GalleryDownloadInfo? info =
        galleryDownloadService.galleryDownloadInfos[gallery.gid];
    if (info == null) {
      return null;
    }
    final List<LanGalleryManifestPage> pages = [];
    for (int index = 0; index < info.imageHrefs.length; index++) {
      final GalleryThumbnail? thumbnail = info.imageHrefs[index];
      if (thumbnail != null) {
        pages.add(
          LanGalleryManifestPage(pageIndex: index, thumbnail: thumbnail),
        );
      }
    }
    return LanGalleryManifest(
      galleryUrl: gallery.galleryUrl,
      pageCount: gallery.pageCount,
      thumbnailsCountPerPage: info.thumbnailsCountPerPage,
      pages: pages,
    );
  }

  /// Builds gallery summaries from this device's downloaded-gallery catalog.
  List<LanSharedGallerySummary> _localGallerySummaries() => [
    for (final GalleryDownloadedData gallery in galleryDownloadService.gallerys)
      LanSharedGallerySummary(
        deviceId: trustService.localDeviceId,
        deviceName: trustService.localDisplayName,
        gid: gallery.gid,
        token: gallery.token,
        title: gallery.title,
        galleryUrl: gallery.galleryUrl,
        pageCount: gallery.pageCount,
        category: gallery.category,
        publishTime: gallery.publishTime,
        coverUrl: _coverUrlFor(gallery.gid),
      ),
  ];

  /// The URL of a downloaded gallery's first image, used as a cover hint.
  String? _coverUrlFor(int gid) {
    final GalleryDownloadInfo? info =
        galleryDownloadService.galleryDownloadInfos[gid];
    if (info == null) {
      return null;
    }
    for (final GalleryImage? image in info.images) {
      if (image != null && image.downloadStatus == DownloadStatus.downloaded) {
        return image.url;
      }
    }
    return null;
  }

  Future<LanSharedImage?> _resolveLocalImageCache(String href) async {
    GalleryImage? image = _imagePageManifest[_canonicalImagePageKey(href)];
    if (image == null) {
      if (!await ehRequest.hasCachedImagePage(href)) {
        return null;
      }
      image = await ehRequest.requestImagePage<GalleryImage>(
        href,
        parser: EHSpiderParser.imagePage2GalleryImage,
      );
      await recordImagePage(href, image);
    }
    final String? cacheDirectory =
        _imageCacheDirectoryOverride ?? extendedImageDiskCacheDirectory;
    if (cacheDirectory == null) {
      return null;
    }
    final String effectiveUrl = effectiveEHImageUrl(image.url);
    final File? file = await findCompatibleImageCacheFile(
      directory: cacheDirectory,
      url: effectiveUrl,
    );
    if (file != null) {
      log.debug('LAN image cache hit: ${_canonicalImagePageKey(href)}');
      return LanSharedImage(
        image: image.toJson(),
        bytes: await file.readAsBytes(),
      );
    }
    // Server mode: this device is the storage for browsing peers. Download the
    // missing image and cache it HERE, so the peer keeps no cache of its own
    // and later requests for the same page hit without the network.
    if (advancedSetting.lanServerMode.value) {
      final List<int>? bytes = await _downloadImageBytes(effectiveUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final String cacheKey = normalizedImageCacheKey(effectiveUrl);
        final File target = File(path.join(cacheDirectory, cacheKey));
        try {
          await target.parent.create(recursive: true);
          await target.writeAsBytes(bytes, flush: true);
          log.debug('LAN server mode cached: ${_canonicalImagePageKey(href)}');
          return LanSharedImage(image: image.toJson(), bytes: bytes);
        } on Object catch (error, stack) {
          log.warning('LAN server mode cache write failed: $error');
          log.trace(stack);
        }
      }
    }
    log.debug('LAN image cache miss: ${_canonicalImagePageKey(href)}');
    return null;
  }

  /// Fetches an image's bytes over the network (used by server mode to pull a
  /// missing image into this device's cache).
  Future<List<int>?> _downloadImageBytes(String url) async {
    try {
      final ExtendedNetworkImageProvider provider =
          ExtendedNetworkImageProvider(
            url,
            cache: false,
            retries: 1,
            printError: false,
          );
      return await provider.getNetworkImageData();
    } on Object catch (error, stack) {
      log.warning('LAN server mode image download failed: $error');
      log.trace(stack);
      return null;
    }
  }

  /// Serves a page from the host's downloaded gallery: locates the gallery by
  /// its URL, reads the downloaded file for [pageIndex], and returns it with
  /// the host's private download path stripped.
  Future<LanSharedImage?> _resolveLocalDownload(
    String galleryUrl,
    int pageIndex,
  ) async {
    final GalleryDownloadedData? gallery = _findDownloadedGallery(galleryUrl);
    if (gallery == null) {
      return null;
    }
    final GalleryDownloadInfo? info =
        galleryDownloadService.galleryDownloadInfos[gallery.gid];
    if (info == null || pageIndex < 0 || pageIndex >= info.images.length) {
      return null;
    }
    final GalleryImage? image = info.images[pageIndex];
    if (image == null ||
        image.downloadStatus != DownloadStatus.downloaded ||
        image.path == null ||
        image.path!.isEmpty) {
      return null;
    }
    final File file = File(
      GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
        image.path!,
      ),
    );
    if (!await file.exists()) {
      log.debug('LAN download miss: $galleryUrl #$pageIndex');
      return null;
    }
    log.debug('LAN download hit: $galleryUrl #$pageIndex');
    return LanSharedImage(
      // The peer must treat the image as a plain online image, not inherit the
      // host's on-disk path.
      image:
          image
              .copyWith(path: null, downloadStatus: DownloadStatus.none)
              .toJson(),
      bytes: await file.readAsBytes(),
    );
  }

  GalleryDownloadedData? _findDownloadedGallery(String galleryUrl) {
    final String normalized = _normalizeGalleryUrl(galleryUrl);
    for (final GalleryDownloadedData gallery
        in galleryDownloadService.gallerys) {
      if (_normalizeGalleryUrl(gallery.galleryUrl) == normalized ||
          (gallery.oldVersionGalleryUrl != null &&
              _normalizeGalleryUrl(gallery.oldVersionGalleryUrl!) ==
                  normalized)) {
        return gallery;
      }
    }
    return null;
  }

  String _normalizeGalleryUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  String _canonicalImagePageKey(String href) {
    final Uri uri = Uri.parse(href);
    return uri.path;
  }

  File get _imagePageManifestFile =>
      File(path.join(pathService.jhLanDir.path, 'image-cache-manifest.json'));

  Future<void> _loadImagePageManifest() async {
    final File file = _imagePageManifestFile;
    if (!await file.exists()) {
      return;
    }
    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
          if (entry.key is String && entry.value is Map) {
            _imagePageManifest[entry.key as String] = GalleryImage.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
    } on Object catch (error) {
      log.warning('Load LAN image cache manifest failed: $error');
    }
  }

  Future<void> _saveImagePageManifest() async {
    final File file = _imagePageManifestFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(
        _imagePageManifest.map((key, value) => MapEntry(key, value.toJson())),
      ),
      flush: true,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    LanDiscoveredPeer peer,
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    final HttpClient client =
        HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final Uri uri = Uri(
        scheme: 'http',
        host: peer.host,
        port: peer.port,
        path: path,
      );
      final HttpClientRequest request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      final dynamic decoded = await _readClientJson(response);
      if (response.statusCode != HttpStatus.ok || decoded is! Map) {
        throw HttpException(
          'LAN request failed with ${response.statusCode}',
          uri: uri,
        );
      }
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    if (request.contentLength > _maxRequestBytes) {
      throw const HttpException('LAN request is too large');
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await for (final List<int> chunk in request) {
      bytes.add(chunk);
      if (bytes.length > _maxRequestBytes) {
        throw const HttpException('LAN request is too large');
      }
    }
    final dynamic decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map) {
      throw const FormatException('LAN request must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<dynamic> _readClientJson(HttpClientResponse response) async {
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await for (final List<int> chunk in response) {
      bytes.add(chunk);
      if (bytes.length > _maxRequestBytes) {
        throw const HttpException('LAN response is too large');
      }
    }
    return jsonDecode(utf8.decode(bytes.takeBytes()));
  }

  Future<Map<String, dynamic>> _nextSocketJson(
    StreamIterator<dynamic> iterator,
  ) async {
    final bool hasNext = await iterator.moveNext().timeout(
      const Duration(seconds: 10),
    );
    if (!hasNext || iterator.current is! String) {
      throw const FormatException('Invalid LAN socket message');
    }
    final String message = iterator.current as String;
    if (utf8.encode(message).length > _maxRequestBytes) {
      throw const FormatException('LAN socket message is too large');
    }
    final dynamic decoded = jsonDecode(message);
    if (decoded is! Map) {
      throw const FormatException('Invalid LAN socket message');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Map<String, dynamic> _localIdentityJson() => {
    'deviceId': trustService.localDeviceId,
    'displayName': trustService.localDisplayName,
    'identityPublicKey': trustService.localIdentityPublicKey,
    'identityFingerprint': trustService.localIdentityFingerprint,
    'protocolVersion': protocolVersion,
  };

  Future<bool> _verifySignature({
    required String publicKey,
    required List<int> message,
    required List<int> signature,
  }) async {
    try {
      if (signature.length != 64) {
        return false;
      }
      final SimplePublicKey key = SimplePublicKey(
        _decodeBytes(publicKey),
        type: KeyPairType.ed25519,
      );
      return Ed25519().verify(
        message,
        signature: Signature(signature, publicKey: key),
      );
    } on Object {
      return false;
    }
  }

  List<int> _sessionProofPayload(
    String clientChallenge,
    String serverChallenge,
  ) => utf8.encode(
    jsonEncode({
      'protocol': 'jhentai-lan-session-v1',
      'clientChallenge': clientChallenge,
      'serverChallenge': serverChallenge,
    }),
  );

  bool _isLocalNetworkAddress(InternetAddress address) {
    if (address.isLoopback) {
      return true;
    }
    final Uint8List raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return raw[0] == 10 ||
          (raw[0] == 172 && raw[1] >= 16 && raw[1] <= 31) ||
          (raw[0] == 192 && raw[1] == 168) ||
          (raw[0] == 169 && raw[1] == 254);
    }
    return (raw[0] & 0xfe) == 0xfc ||
        (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80);
  }

  String _randomBase64Url(int byteCount) => _encodeBytes(
    List<int>.generate(
      byteCount,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    ),
  );

  List<int> _randomBytes(int byteCount) => List<int>.generate(
    byteCount,
    (_) => _secureRandom.nextInt(256),
    growable: false,
  );

  String _encodeBytes(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  List<int> _decodeBytes(String value) =>
      base64Url.decode(base64Url.normalize(value));

  List<int> _v2Transcript(
    Map<String, dynamic> clientHello,
    Map<String, dynamic> serverHello,
  ) => utf8.encode(
    LanProtocolV2.canonicalJson(<String, dynamic>{
      'client': clientHello,
      'server': serverHello,
    }),
  );

  bool _constantTimeBytesEqual(List<int> left, List<int> right) {
    int difference = left.length ^ right.length;
    final int length = max(left.length, right.length);
    for (int index = 0; index < length; index++) {
      difference |=
          (index < left.length ? left[index] : 0) ^
          (index < right.length ? right[index] : 0);
    }
    return difference == 0;
  }
}

class _LanV2SocketChannel {
  final WebSocket socket;
  final StreamIterator<dynamic> iterator;
  final LanSecureSession secureSession;
  Future<void> _sendTail = Future<void>.value();

  _LanV2SocketChannel({
    required this.socket,
    required this.iterator,
    required this.secureSession,
  });

  Future<void> send(Map<String, dynamic> payload) {
    final Future<void> next = _sendTail.then((_) async {
      socket.add(jsonEncode(await secureSession.encrypt(payload)));
    });
    _sendTail = next.catchError((Object _) {});
    return next;
  }

  Future<Map<String, dynamic>?> receive() async {
    if (!await iterator.moveNext()) {
      return null;
    }
    if (iterator.current is! String) {
      throw const FormatException('LAN v2 record must be JSON text');
    }
    final dynamic decoded = jsonDecode(iterator.current as String);
    if (decoded is! Map) {
      throw const FormatException('LAN v2 record must be an object');
    }
    return secureSession.decrypt(Map<String, dynamic>.from(decoded));
  }
}

class _WebSocketLanPeerSession
    implements
        LanPeerSession,
        LanGalleryManifestSession,
        LanUnifiedStateSession,
        LanComputeSession {
  final WebSocket _socket;
  final StreamIterator<dynamic> _iterator;
  final bool _supportsImageCache;
  final Set<String> _capabilities;
  final void Function(int bytes) _onBytesReceived;
  final Completer<void> _closed = Completer<void>();
  final LanPendingRequestRegistry<LanSharedImage?> _pending;
  final LanPendingRequestRegistry<List<LanSharedGallerySummary>>
  _pendingListGalleries;
  final LanPendingRequestRegistry<LanSharedGalleryPage> _pendingGalleryPages;
  final LanPendingRequestRegistry<LanGalleryManifest?> _pendingManifests;
  final LanPendingRequestRegistry<LanUnifiedStatePayload?> _pendingUnifiedState;
  final LanSecureSession? _secureSession;
  late final LanComputeClientRuntime _computeRuntime;
  int _nextRequestId = 0;
  String? _pendingBinaryRequestId;
  Map<String, dynamic>? _pendingBinaryImage;
  final Map<String, _LanImageAssembly> _pendingSecureImages = {};
  Future<void> _secureSendTail = Future<void>.value();

  _WebSocketLanPeerSession(
    this._socket,
    this._iterator, {
    required void Function(int bytes) onBytesReceived,
    required bool supportsImageCache,
    required Set<String> capabilities,
    required LanTimerScheduler timerScheduler,
    LanSecureSession? secureSession,
  }) : _supportsImageCache = supportsImageCache,
       _capabilities = Set.unmodifiable(capabilities),
       _onBytesReceived = onBytesReceived,
       _secureSession = secureSession,
       _pending = LanPendingRequestRegistry<LanSharedImage?>(
         timerScheduler: timerScheduler,
         timeout: LanSharingRuntime.pendingRequestTimeout,
       ),
       _pendingListGalleries =
           LanPendingRequestRegistry<List<LanSharedGallerySummary>>(
             timerScheduler: timerScheduler,
             timeout: LanSharingRuntime.pendingRequestTimeout,
           ),
       _pendingGalleryPages = LanPendingRequestRegistry<LanSharedGalleryPage>(
         timerScheduler: timerScheduler,
         timeout: LanSharingRuntime.pendingRequestTimeout,
       ),
       _pendingManifests = LanPendingRequestRegistry<LanGalleryManifest?>(
         timerScheduler: timerScheduler,
         timeout: LanSharingRuntime.pendingRequestTimeout,
       ),
       _pendingUnifiedState =
           LanPendingRequestRegistry<LanUnifiedStatePayload?>(
             timerScheduler: timerScheduler,
             timeout: LanSharingRuntime.pendingRequestTimeout,
           ) {
    _computeRuntime = LanComputeClientRuntime(
      peerSupportsCompute: _capabilities.contains(
        LanComputeRuntime.sessionCapability,
      ),
      send:
          (LanComputeMessage message) =>
              _sendSecure(LanComputeRuntime.envelope(message)),
      timerScheduler: _LanComputeTimerSchedulerAdapter(timerScheduler),
    );
    unawaited(_drain());
  }

  @override
  Future<void> get closed => _closed.future;

  Future<void> _drain() async {
    try {
      while (await _iterator.moveNext()) {
        final dynamic message = _iterator.current;
        if (_secureSession != null) {
          if (message is! String) {
            throw const FormatException('LAN v2 response must be JSON text');
          }
          final dynamic decoded = jsonDecode(message);
          if (decoded is! Map) {
            throw const FormatException('LAN v2 response record is invalid');
          }
          await _handleSecureMessage(
            await _secureSession.decrypt(Map<String, dynamic>.from(decoded)),
          );
          continue;
        }
        if (message is List<int>) {
          final String? id = _pendingBinaryRequestId;
          final Map<String, dynamic>? image = _pendingBinaryImage;
          _pendingBinaryRequestId = null;
          _pendingBinaryImage = null;
          if (id != null && image != null) {
            final bool completed = _pending.complete(
              id,
              LanSharedImage(image: image, bytes: message),
            );
            if (completed) {
              _onBytesReceived(message.length);
            }
          }
          continue;
        }
        if (message is! String) {
          continue;
        }
        final dynamic decoded = jsonDecode(message);
        if (decoded is! Map) {
          continue;
        }
        final String id = decoded['id'] as String? ?? '';
        if (decoded['type'] == 'cache_image_miss') {
          _pending.complete(id, null);
        } else if (decoded['type'] == 'cache_image_hit' &&
            decoded['image'] is Map) {
          _pendingBinaryRequestId = id;
          _pendingBinaryImage = Map<String, dynamic>.from(
            decoded['image'] as Map,
          );
        } else if (decoded['type'] == 'list_galleries_result' &&
            decoded['galleries'] is List) {
          _pendingListGalleries.complete(
            id,
            (decoded['galleries'] as List)
                .whereType<Map>()
                .map(
                  (dynamic gallery) => LanSharedGallerySummary.fromJson(
                    Map<String, dynamic>.from(gallery as Map),
                  ),
                )
                .toList(),
          );
        }
      }
    } finally {
      await _iterator.cancel();
      _pending.completeAll(null);
      _pendingListGalleries.completeAll(const <LanSharedGallerySummary>[]);
      _pendingGalleryPages.completeAll(
        const LanSharedGalleryPage(
          revision: '',
          nextCursor: null,
          galleries: <LanSharedGallerySummary>[],
        ),
      );
      _pendingManifests.completeAll(null);
      _pendingUnifiedState.completeAll(null);
      await _computeRuntime.close();
      _secureSession?.close();
      if (!_closed.isCompleted) {
        _closed.complete();
      }
    }
  }

  @override
  Future<LanSharedImage?> requestImageCache(
    String imagePageHref, {
    String? galleryUrl,
    int? pageIndex,
  }) {
    if (!_supportsImageCache) {
      return Future<LanSharedImage?>.value();
    }
    final String id = '${++_nextRequestId}';
    final Future<LanSharedImage?> future = _pending.register(
      id,
      timeoutValue: null,
      onTimeout: () {
        if (_pendingBinaryRequestId == id) {
          _pendingBinaryRequestId = null;
          _pendingBinaryImage = null;
        }
      },
    );
    if (_secureSession != null) {
      unawaited(
        _sendSecure(<String, dynamic>{
          'type': 'request',
          'id': id,
          'op': 'cache_image',
          'params': <String, dynamic>{
            'href': imagePageHref,
            if (galleryUrl != null) 'galleryUrl': galleryUrl,
            if (pageIndex != null) 'pageIndex': pageIndex,
          },
        }),
      );
    } else {
      _socket.add(
        jsonEncode({
          'type': 'cache_image',
          'id': id,
          'href': imagePageHref,
          if (galleryUrl != null) 'galleryUrl': galleryUrl,
          if (pageIndex != null) 'pageIndex': pageIndex,
        }),
      );
    }
    return future;
  }

  @override
  Future<List<LanSharedGallerySummary>> listDownloadedGalleries() {
    if (_secureSession != null) {
      return listDownloadedGalleriesPage().then(
        (LanSharedGalleryPage page) => page.galleries,
      );
    }
    final String id = 'g${++_nextRequestId}';
    final Future<List<LanSharedGallerySummary>> future = _pendingListGalleries
        .register(id, timeoutValue: const <LanSharedGallerySummary>[]);
    _socket.add(jsonEncode({'type': 'list_galleries', 'id': id}));
    return future;
  }

  @override
  Future<LanSharedGalleryPage> listDownloadedGalleriesPage({
    String? cursor,
    int limit = 50,
    String? knownRevision,
  }) {
    if (_secureSession == null) {
      return listDownloadedGalleries().then(
        (List<LanSharedGallerySummary> galleries) => LanSharedGalleryPage(
          revision: '',
          nextCursor: null,
          galleries: galleries,
        ),
      );
    }
    final String id = 'g${++_nextRequestId}';
    final Future<LanSharedGalleryPage> future = _pendingGalleryPages.register(
      id,
      timeoutValue: const LanSharedGalleryPage(
        revision: '',
        nextCursor: null,
        galleries: <LanSharedGallerySummary>[],
      ),
    );
    unawaited(
      _sendSecure(<String, dynamic>{
        'type': 'request',
        'id': id,
        'op': 'list_galleries',
        'params': <String, dynamic>{
          if (cursor != null) 'cursor': int.tryParse(cursor) ?? 0,
          'limit': limit,
          if (knownRevision != null) 'knownRevision': knownRevision,
        },
      }),
    );
    return future;
  }

  @override
  Future<LanGalleryManifest?> fetchGalleryManifest(String galleryUrl) {
    if (_secureSession == null) {
      return Future<LanGalleryManifest?>.value();
    }
    final String id = 'm${++_nextRequestId}';
    final Future<LanGalleryManifest?> future = _pendingManifests.register(
      id,
      timeoutValue: null,
    );
    unawaited(
      _sendSecure(<String, dynamic>{
        'type': 'request',
        'id': id,
        'op': 'gallery_manifest',
        'params': <String, dynamic>{'galleryUrl': galleryUrl},
      }),
    );
    return future;
  }

  @override
  Future<LanLoginStateSnapshot?> requestLoginState() async {
    if (_secureSession == null || !_capabilities.contains('loginStateV1')) {
      return null;
    }
    final String id = 'l${++_nextRequestId}';
    final Future<LanUnifiedStatePayload?> future = _pendingUnifiedState
        .register(id, timeoutValue: null);
    unawaited(
      _sendSecure(<String, dynamic>{
        'type': 'request',
        'id': id,
        'op': 'login_state',
        'params': const <String, dynamic>{},
      }),
    );
    return (await future)?.loginState;
  }

  @override
  Future<LanUnifiedStatePayload?> requestApplicationHistory() {
    if (_secureSession == null ||
        !_capabilities.contains('applicationHistoryV1')) {
      return Future<LanUnifiedStatePayload?>.value();
    }
    final String id = 'h${++_nextRequestId}';
    final Future<LanUnifiedStatePayload?> future = _pendingUnifiedState
        .register(id, timeoutValue: null);
    unawaited(
      _sendSecure(<String, dynamic>{
        'type': 'request',
        'id': id,
        'op': 'application_history',
        'params': const <String, dynamic>{},
      }),
    );
    return future;
  }

  Future<void> _sendSecure(Map<String, dynamic> payload) {
    final Future<void> next = _secureSendTail.then((_) async {
      _socket.add(jsonEncode(await _secureSession!.encrypt(payload)));
    });
    _secureSendTail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _handleSecureMessage(Map<String, dynamic> message) async {
    if (message['type'] == LanComputeRuntime.envelopeType) {
      await _computeRuntime.handleEnvelope(message);
      return;
    }
    final String type = message['type'] as String? ?? '';
    final String id = message['id'] as String? ?? '';
    if (type == 'image_miss') {
      _pendingSecureImages.remove(id);
      _pending.complete(id, null);
      return;
    }
    if (type == 'image_begin') {
      _pendingSecureImages[id] = _LanImageAssembly(
        image: Map<String, dynamic>.from(message['image'] as Map? ?? const {}),
        byteLength: (message['byteLength'] as num?)?.toInt() ?? 0,
      );
      return;
    }
    if (type == 'image_chunk') {
      final _LanImageAssembly? assembly = _pendingSecureImages[id];
      if (assembly == null) {
        throw const FormatException('LAN v2 image chunk has no begin record');
      }
      final int index = (message['index'] as num?)?.toInt() ?? -1;
      if (index != assembly.nextIndex) {
        throw const FormatException('LAN v2 image chunks are out of order');
      }
      assembly.bytes.addAll(_decodeBytes(message['data'] as String? ?? ''));
      assembly.nextIndex++;
      if (message['final'] == true) {
        if (assembly.bytes.length != assembly.byteLength) {
          throw const FormatException('LAN v2 image byte length mismatch');
        }
        _pendingSecureImages.remove(id);
        final bool completed = _pending.complete(
          id,
          LanSharedImage(image: assembly.image, bytes: assembly.bytes),
        );
        if (completed) {
          _onBytesReceived(assembly.bytes.length);
        }
      }
      return;
    }
    if (type != 'response' || message['ok'] != true) {
      return;
    }
    final String op = message['op'] as String? ?? '';
    if (op == 'list_galleries') {
      final LanSharedGalleryPage page = LanSharedGalleryPage.fromJson(
        Map<String, dynamic>.from(message['data'] as Map? ?? const {}),
      );
      _pendingGalleryPages.complete(id, page);
    } else if (op == 'gallery_manifest') {
      _pendingManifests.complete(
        id,
        LanGalleryManifest.fromJson(
          Map<String, dynamic>.from(message['data'] as Map? ?? const {}),
        ),
      );
    } else if (op == 'login_state' || op == 'application_history') {
      _pendingUnifiedState.complete(
        id,
        message['data'] is Map
            ? LanUnifiedStatePayload.fromJson(
              Map<String, dynamic>.from(message['data'] as Map),
            )
            : null,
      );
    }
  }

  @override
  Future<void> close() async {
    await _socket.close(WebSocketStatus.normalClosure);
    if (!_closed.isCompleted) {
      await closed;
    }
  }

  @override
  LanComputeCapabilityDescriptor? computeDescriptor(
    LanComputeCapability capability,
  ) => _computeRuntime.computeDescriptor(capability);

  @override
  EngineTask<LanComputeDataRef> requestCompute({
    required String taskId,
    required LanComputeCapability capability,
    required String modelHash,
    required String configHash,
    String? promptHash,
    required LanComputeDataRef input,
    required int deadlineEpochMs,
    required LanComputeCommitGate commitGate,
  }) => _computeRuntime.requestCompute(
    taskId: taskId,
    capability: capability,
    modelHash: modelHash,
    configHash: configHash,
    promptHash: promptHash,
    input: input,
    deadlineEpochMs: deadlineEpochMs,
    commitGate: commitGate,
  );

  List<int> _decodeBytes(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

class _LanImageAssembly {
  final Map<String, dynamic> image;
  final int byteLength;
  final List<int> bytes = <int>[];
  int nextIndex = 0;

  _LanImageAssembly({required this.image, required this.byteLength});
}
