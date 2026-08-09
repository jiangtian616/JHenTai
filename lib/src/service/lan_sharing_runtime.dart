import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:cryptography/cryptography.dart';
import 'package:extended_image/extended_image.dart'
    show extendedImageDiskCacheDirectory;
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/image_cache_util.dart';
import 'jh_service.dart';
import 'lan_device_trust_service.dart';
import 'log.dart';
import 'path_service.dart';

LanSharingRuntime lanSharingRuntime = LanSharingRuntime();

class LanSharingRuntime
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean, LanPeerPairer, LanPeerConnector {
  static const String serviceType = '_jhentai-lan._tcp';
  static const int protocolVersion = 1;
  static const int _maxRequestBytes = 64 * 1024;

  final LanDeviceTrustService trustService;
  final bool useServiceDiscovery;
  final InternetAddress bindAddress;
  final Random _secureRandom;
  final String? _imageCacheDirectoryOverride;
  final bool _persistImagePageManifest;
  final Future<LanSharedImage?> Function(String imagePageHref)?
  _imageCacheResolverOverride;
  final Map<String, GalleryImage> _imagePageManifest = {};
  Future<void> _manifestWrite = Future<void>.value();

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
    Future<LanSharedImage?> Function(String imagePageHref)? imageCacheResolver,
    String? imageCacheDirectory,
  }) : trustService = trustService ?? lanDeviceTrustService,
       bindAddress = bindAddress ?? InternetAddress.anyIPv4,
       _secureRandom = secureRandom ?? Random.secure(),
       _imageCacheDirectoryOverride = imageCacheDirectory,
       _persistImagePageManifest = trustService == null,
       _imageCacheResolverOverride = imageCacheResolver;

  bool get isRunning => _started;

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

  Future<GalleryImage?> fetchCachedImage(String imagePageHref) async {
    if (!_started || !trustService.isEnabled) {
      return null;
    }
    final LanSharedImage? shared = await trustService.requestImageCache(
      imagePageHref,
    );
    if (shared == null || shared.bytes.isEmpty) {
      return null;
    }
    final GalleryImage image = GalleryImage.fromJson(shared.image);
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
    _server = await HttpServer.bind(bindAddress, 0, shared: false);
    _server!.listen(
      (request) => unawaited(_handleRequest(request)),
      onError: (Object error, StackTrace stack) {
        log.warning('LAN server failed: $error');
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
      },
    );
    final BonsoirBroadcast broadcast = BonsoirBroadcast(
      service: service,
      printLogs: false,
    );
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;

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
      final String clientChallenge = _randomBase64Url(32);
      final List<int> clientSignature = await trustService.signChallenge(
        _decodeBytes(clientChallenge),
      );
      socket.add(
        jsonEncode({
          'type': 'auth',
          'deviceId': trustService.localDeviceId,
          'identityFingerprint': trustService.localIdentityFingerprint,
          'accessToken': accessToken,
          'challenge': clientChallenge,
          'signature': _encodeBytes(clientSignature),
        }),
      );
      final Map<String, dynamic> response = await _nextSocketJson(iterator);
      if (response['type'] != 'auth_challenge') {
        throw const FormatException('Invalid LAN session response');
      }
      final String serverChallenge = response['challenge'] as String? ?? '';
      final List<int> proofPayload = _sessionProofPayload(
        clientChallenge,
        serverChallenge,
      );
      final bool valid = await trustService.verifyPeerChallenge(
        deviceId: peer.deviceId,
        challenge: proofPayload,
        signature: _decodeBytes(response['signature'] as String? ?? ''),
      );
      if (!valid) {
        throw const FormatException('Invalid LAN server proof');
      }
      final List<int> ackSignature = await trustService.signChallenge(
        _decodeBytes(serverChallenge),
      );
      socket.add(
        jsonEncode({
          'type': 'auth_ack',
          'signature': _encodeBytes(ackSignature),
        }),
      );
      return _WebSocketLanPeerSession(
        socket,
        iterator,
        onBytesReceived: trustService.recordTrafficReceived,
        supportsImageCache: (response['capabilities'] as List? ?? const [])
            .contains('imageCacheV1'),
      );
    } on Object {
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
      if (auth['type'] != 'auth') {
        throw const FormatException('LAN session auth required');
      }
      final String deviceId = auth['deviceId'] as String? ?? '';
      final String clientChallenge = auth['challenge'] as String? ?? '';
      final bool accepted = await trustService.authenticateInbound(
        deviceId: deviceId,
        identityFingerprint: auth['identityFingerprint'] as String? ?? '',
        presentedToken: auth['accessToken'] as String? ?? '',
        challenge: _decodeBytes(clientChallenge),
        challengeSignature: _decodeBytes(auth['signature'] as String? ?? ''),
      );
      if (!accepted) {
        await socket.close(WebSocketStatus.policyViolation, 'auth_failed');
        return;
      }
      final String serverChallenge = _randomBase64Url(32);
      final List<int> serverSignature = await trustService.signChallenge(
        _sessionProofPayload(clientChallenge, serverChallenge),
      );
      socket.add(
        jsonEncode({
          'type': 'auth_challenge',
          'challenge': serverChallenge,
          'signature': _encodeBytes(serverSignature),
          'capabilities': const ['imageCacheV1'],
        }),
      );
      final Map<String, dynamic> ack = await _nextSocketJson(iterator);
      if (ack['type'] != 'auth_ack' ||
          !await trustService.verifyPeerChallenge(
            deviceId: deviceId,
            challenge: _decodeBytes(serverChallenge),
            signature: _decodeBytes(ack['signature'] as String? ?? ''),
          )) {
        await socket.close(WebSocketStatus.policyViolation, 'proof_failed');
        return;
      }
      while (await iterator.moveNext()) {
        final dynamic message = iterator.current;
        if (message is! String || message.length > _maxRequestBytes) {
          continue;
        }
        final dynamic decoded = jsonDecode(message);
        if (decoded is! Map || decoded['type'] != 'cache_image') {
          continue;
        }
        final String requestId = decoded['id'] as String? ?? '';
        final TrustedLanDevice? device = trustService.deviceById(deviceId);
        if (requestId.isEmpty ||
            device == null ||
            !device.permissions.contains(LanSharePermission.imageCache)) {
          socket.add(jsonEncode({'type': 'cache_image_miss', 'id': requestId}));
          continue;
        }
        final String href = decoded['href'] as String? ?? '';
        final LanSharedImage? shared =
            await (_imageCacheResolverOverride?.call(href) ??
                _resolveLocalImageCache(href));
        if (shared == null || shared.bytes.isEmpty) {
          socket.add(jsonEncode({'type': 'cache_image_miss', 'id': requestId}));
          continue;
        }
        socket.add(
          jsonEncode({
            'type': 'cache_image_hit',
            'id': requestId,
            'image': shared.image,
            'byteLength': shared.bytes.length,
          }),
        );
        socket.add(shared.bytes);
        trustService.recordTrafficSent(shared.bytes.length);
      }
    } on Object catch (error) {
      await socket.close(WebSocketStatus.protocolError, error.toString());
    } finally {
      await iterator.cancel();
    }
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
    final String cacheKey = normalizedImageCacheKey(
      effectiveEHImageUrl(image.url),
    );
    final String? cacheDirectory =
        _imageCacheDirectoryOverride ?? extendedImageDiskCacheDirectory;
    if (cacheDirectory == null) {
      return null;
    }
    final File file = File(path.join(cacheDirectory, cacheKey));
    if (!await file.exists()) {
      return null;
    }
    return LanSharedImage(
      image: image.toJson(),
      bytes: await file.readAsBytes(),
    );
  }

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

  String _encodeBytes(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  List<int> _decodeBytes(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

class _WebSocketLanPeerSession implements LanPeerSession {
  final WebSocket _socket;
  final StreamIterator<dynamic> _iterator;
  final bool _supportsImageCache;
  final void Function(int bytes) _onBytesReceived;
  final Completer<void> _closed = Completer<void>();
  final Map<String, Completer<LanSharedImage?>> _pending = {};
  int _nextRequestId = 0;
  String? _pendingBinaryRequestId;
  Map<String, dynamic>? _pendingBinaryImage;

  _WebSocketLanPeerSession(
    this._socket,
    this._iterator, {
    required void Function(int bytes) onBytesReceived,
    required bool supportsImageCache,
  }) : _supportsImageCache = supportsImageCache,
       _onBytesReceived = onBytesReceived {
    unawaited(_drain());
  }

  @override
  Future<void> get closed => _closed.future;

  Future<void> _drain() async {
    try {
      while (await _iterator.moveNext()) {
        final dynamic message = _iterator.current;
        if (message is List<int>) {
          final String? id = _pendingBinaryRequestId;
          final Map<String, dynamic>? image = _pendingBinaryImage;
          _pendingBinaryRequestId = null;
          _pendingBinaryImage = null;
          if (id != null && image != null) {
            _onBytesReceived(message.length);
            _pending
                .remove(id)
                ?.complete(LanSharedImage(image: image, bytes: message));
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
          _pending.remove(id)?.complete(null);
        } else if (decoded['type'] == 'cache_image_hit' &&
            decoded['image'] is Map) {
          _pendingBinaryRequestId = id;
          _pendingBinaryImage = Map<String, dynamic>.from(
            decoded['image'] as Map,
          );
        }
      }
    } finally {
      await _iterator.cancel();
      for (final Completer<LanSharedImage?> pending in _pending.values) {
        if (!pending.isCompleted) {
          pending.complete(null);
        }
      }
      _pending.clear();
      if (!_closed.isCompleted) {
        _closed.complete();
      }
    }
  }

  @override
  Future<LanSharedImage?> requestImageCache(String imagePageHref) {
    if (!_supportsImageCache) {
      return Future<LanSharedImage?>.value();
    }
    final String id = '${++_nextRequestId}';
    final Completer<LanSharedImage?> completer = Completer<LanSharedImage?>();
    _pending[id] = completer;
    _socket.add(
      jsonEncode({'type': 'cache_image', 'id': id, 'href': imagePageHref}),
    );
    return completer.future;
  }

  @override
  Future<void> close() async {
    await _socket.close(WebSocketStatus.normalClosure);
    if (!_closed.isCompleted) {
      await closed;
    }
  }
}
