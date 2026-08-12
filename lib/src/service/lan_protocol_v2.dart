import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Public LAN v2 wire contract.  The construction deliberately delegates all
/// cryptographic operations to package:cryptography; this file only composes
/// the documented X25519, HKDF-SHA-256 and XChaCha20-Poly1305 APIs.
class LanProtocolV2 {
  static const int version = 2;
  static const int legacyVersion = 1;
  static const int maxRecordPlaintextBytes = 64 * 1024;
  static const int maxImageChunkBytes = 32 * 1024;
  static const String cipherSuite = 'X25519-HKDF-SHA256-XChaCha20-Poly1305';

  static const List<String> capabilities = <String>[
    'secureSessionV2',
    'galleryManifestV1',
    'galleryPaginationV1',
    'imageChunkingV1',
    'coverCacheV1',
    'serverStatusV1',
    'loginStateV1',
    'applicationHistoryV1',
  ];

  static String encodeBytes(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  static List<int> decodeBytes(String value) =>
      base64Url.decode(base64Url.normalize(value));

  static List<String> negotiateCapabilities(
    Iterable<String> offered,
    Iterable<String> supported,
  ) {
    final Set<String> supportedSet = supported.toSet();
    return offered.where(supportedSet.contains).toSet().toList()..sort();
  }

  static int? negotiateVersion(Iterable<int> offered) {
    final List<int> versions =
        offered
            .where(
              (int version) =>
                  version == LanProtocolV2.version || version == legacyVersion,
            )
            .toSet()
            .toList()
          ..sort((int a, int b) => b.compareTo(a));
    return versions.isEmpty ? null : versions.first;
  }

  /// Canonical JSON is used for signatures and AEAD associated data.  Sorting
  /// keys prevents map insertion order from becoming a protocol dependency.
  static String canonicalJson(Object? value) =>
      jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final List<String> keys = value.keys.map((Object? key) => '$key').toList()
        ..sort();
      return <String, Object?>{
        for (final String key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}

class LanProtocolException implements Exception {
  final String message;

  const LanProtocolException(this.message);

  @override
  String toString() => 'LanProtocolException: $message';
}

class LanProtocolNegotiation {
  final int version;
  final Set<String> capabilities;

  const LanProtocolNegotiation({
    required this.version,
    required this.capabilities,
  });

  static LanProtocolNegotiation? negotiate({
    required Iterable<int> offered,
    required Iterable<int> supported,
  }) {
    if (!offered.contains(LanProtocolV2.version) ||
        !supported.contains(LanProtocolV2.version)) {
      return null;
    }
    return const LanProtocolNegotiation(
      version: LanProtocolV2.version,
      capabilities: <String>{},
    );
  }
}

/// A bidirectional v2 record layer. Each direction has an independent key,
/// nonce prefix and strictly increasing 64-bit sequence. A record with any
/// sequence other than the next expected value is rejected before decryption,
/// which rejects duplicates and reordering on the ordered WebSocket stream.
class LanSecureSession {
  static final Xchacha20 _aead = Xchacha20.poly1305Aead();

  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final List<int> _sendNoncePrefix;
  final List<int> _receiveNoncePrefix;
  int _nextSendSequence = 0;
  int _nextReceiveSequence = 0;
  bool _closed = false;

  // Receive-side fragment assembly for records split across the 64KiB record
  // cap. Fragments arrive sequentially and are buffered until the final one.
  final List<int> _fragmentBuffer = <int>[];
  int _expectedFragmentTotal = 0;
  int _expectedFragmentIndex = 0;

  LanSecureSession._({
    required SecretKey sendKey,
    required SecretKey receiveKey,
    required List<int> sendNoncePrefix,
    required List<int> receiveNoncePrefix,
  }) : _sendKey = sendKey,
       _receiveKey = receiveKey,
       _sendNoncePrefix = List<int>.unmodifiable(sendNoncePrefix),
       _receiveNoncePrefix = List<int>.unmodifiable(receiveNoncePrefix);

  static Future<LanSecureSession> derive({
    required SimpleKeyPair localEphemeralKeyPair,
    required SimplePublicKey remoteEphemeralPublicKey,
    required List<int> clientNonce,
    required List<int> serverNonce,
    required List<int> transcript,
    required bool isClient,
  }) async {
    if (clientNonce.length != 32 || serverNonce.length != 32) {
      throw const LanProtocolException('LAN v2 nonces must be 32 bytes');
    }
    final SecretKey sharedSecret = await X25519().sharedSecretKey(
      keyPair: localEphemeralKeyPair,
      remotePublicKey: remoteEphemeralPublicKey,
    );
    final SecretKey derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 96)
        .deriveKey(
          secretKey: sharedSecret,
          nonce: <int>[...clientNonce, ...serverNonce],
          info: <int>[
            ...utf8.encode('JHenTai LAN v2 secure session'),
            ...transcript,
          ],
        );
    final List<int> material = List<int>.from(await derived.extractBytes());
    sharedSecret.destroy();
    final SecretKey clientWriteKey = SecretKeyData(
      material.sublist(0, 32),
      overwriteWhenDestroyed: true,
      debugLabel: 'jhentai-lan-v2-client-write',
    );
    final SecretKey serverWriteKey = SecretKeyData(
      material.sublist(32, 64),
      overwriteWhenDestroyed: true,
      debugLabel: 'jhentai-lan-v2-server-write',
    );
    final List<int> clientNoncePrefix = material.sublist(64, 80);
    final List<int> serverNoncePrefix = material.sublist(80, 96);
    for (int index = 0; index < material.length; index++) {
      material[index] = 0;
    }
    derived.destroy();
    return LanSecureSession._(
      sendKey: isClient ? clientWriteKey : serverWriteKey,
      receiveKey: isClient ? serverWriteKey : clientWriteKey,
      sendNoncePrefix: isClient ? clientNoncePrefix : serverNoncePrefix,
      receiveNoncePrefix: isClient ? serverNoncePrefix : clientNoncePrefix,
    );
  }

  Future<Map<String, dynamic>> encrypt(Map<String, dynamic> payload) async {
    final List<int> clearText = utf8.encode(
      LanProtocolV2.canonicalJson(payload),
    );
    if (clearText.length > LanProtocolV2.maxRecordPlaintextBytes) {
      throw const LanProtocolException('LAN v2 record payload is too large');
    }
    return _encryptFragment(clearText, fragmentIndex: null, fragmentTotal: null);
  }

  /// Encrypts [payload] into one or more records. Payloads that exceed the
  /// single-record cap are split into a sequence of fragment records, each
  /// carrying its `fragIndex`/`fragTotal` in the authenticated record header.
  /// The receiver reassembles them before handing the payload to the caller.
  Future<List<Map<String, dynamic>>> encryptChunked(
    Map<String, dynamic> payload,
  ) async {
    final List<int> clearText = utf8.encode(
      LanProtocolV2.canonicalJson(payload),
    );
    if (clearText.length <= LanProtocolV2.maxRecordPlaintextBytes) {
      return <Map<String, dynamic>>[
        await _encryptFragment(clearText, fragmentIndex: null, fragmentTotal: null),
      ];
    }
    final int total =
        (clearText.length + LanProtocolV2.maxRecordPlaintextBytes - 1) ~/
        LanProtocolV2.maxRecordPlaintextBytes;
    final List<Map<String, dynamic>> records = <Map<String, dynamic>>[];
    for (int index = 0; index < total; index++) {
      final int start = index * LanProtocolV2.maxRecordPlaintextBytes;
      final int end = min(
        start + LanProtocolV2.maxRecordPlaintextBytes,
        clearText.length,
      );
      records.add(
        await _encryptFragment(
          clearText.sublist(start, end),
          fragmentIndex: index,
          fragmentTotal: total,
        ),
      );
    }
    return records;
  }

  Future<Map<String, dynamic>> _encryptFragment(
    List<int> clearText, {
    required int? fragmentIndex,
    required int? fragmentTotal,
  }) async {
    _ensureOpen();
    final int sequence = _nextSendSequence;
    _checkSequenceRange(sequence);
    final Map<String, dynamic> header = <String, dynamic>{
      'v': LanProtocolV2.version,
      'seq': sequence,
      if (fragmentIndex != null) 'fragIndex': fragmentIndex,
      if (fragmentTotal != null) 'fragTotal': fragmentTotal,
    };
    final SecretBox box = await _aead.encrypt(
      clearText,
      secretKey: _sendKey,
      nonce: _nonce(_sendNoncePrefix, sequence),
      aad: utf8.encode(LanProtocolV2.canonicalJson(header)),
    );
    _nextSendSequence++;
    return <String, dynamic>{
      ...header,
      'cipherSuite': LanProtocolV2.cipherSuite,
      'ciphertext': base64UrlEncode(<int>[
        ...box.cipherText,
        ...box.mac.bytes,
      ]).replaceAll('=', ''),
    };
  }

  /// Decrypts one record and returns the assembled application payload.
  ///
  /// Returns `null` for an intermediate fragment of a larger message — the
  /// receiver must keep reading until a non-null payload comes back. Fragments
  /// are validated for ordering and reassembled transparently.
  Future<Map<String, dynamic>?> decrypt(Map<String, dynamic> record) async {
    _ensureOpen();
    if (record['v'] != LanProtocolV2.version ||
        record['cipherSuite'] != LanProtocolV2.cipherSuite) {
      throw const LanProtocolException(
        'LAN v2 record version or cipher suite mismatch',
      );
    }
    final int? sequence = (record['seq'] as num?)?.toInt();
    if (sequence == null || sequence != _nextReceiveSequence) {
      throw LanProtocolException(
        'LAN v2 replay or out-of-order record: expected $_nextReceiveSequence, got $sequence',
      );
    }
    final int? fragIndex = (record['fragIndex'] as num?)?.toInt();
    final int? fragTotal = (record['fragTotal'] as num?)?.toInt();
    if ((fragIndex == null) != (fragTotal == null)) {
      throw const LanProtocolException('LAN v2 fragment markers are invalid');
    }
    final String encoded = record['ciphertext'] as String? ?? '';
    final List<int> concatenated;
    try {
      concatenated = base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const LanProtocolException('LAN v2 ciphertext is not base64');
    }
    if (concatenated.length < 16) {
      throw const LanProtocolException('LAN v2 ciphertext is truncated');
    }
    final int split = concatenated.length - 16;
    final SecretBox box = SecretBox(
      concatenated.sublist(0, split),
      nonce: _nonce(_receiveNoncePrefix, sequence),
      mac: Mac(concatenated.sublist(split)),
    );
    final List<int> clearText;
    try {
      clearText = await _aead.decrypt(
        box,
        secretKey: _receiveKey,
        aad: utf8.encode(
          LanProtocolV2.canonicalJson(<String, dynamic>{
            'v': LanProtocolV2.version,
            'seq': sequence,
            if (fragIndex != null) 'fragIndex': fragIndex,
            if (fragTotal != null) 'fragTotal': fragTotal,
          }),
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const LanProtocolException('LAN v2 record authentication failed');
    }
    _nextReceiveSequence++;

    if (fragIndex == null) {
      final dynamic decoded = jsonDecode(utf8.decode(clearText));
      if (decoded is! Map) {
        throw const LanProtocolException('LAN v2 payload must be an object');
      }
      return Map<String, dynamic>.from(decoded);
    }
    if (fragIndex < 0 ||
        fragIndex >= fragTotal! ||
        (_expectedFragmentTotal != 0 && fragIndex != _expectedFragmentIndex)) {
      throw LanProtocolException(
        'LAN v2 fragment out of order: got $fragIndex/$fragTotal expected '
        '$_expectedFragmentIndex/$_expectedFragmentTotal',
      );
    }
    if (_expectedFragmentTotal == 0 || fragIndex == 0) {
      _fragmentBuffer.clear();
      _expectedFragmentTotal = fragTotal;
      _expectedFragmentIndex = 0;
    }
    if (fragTotal != _expectedFragmentTotal ||
        fragIndex != _expectedFragmentIndex) {
      throw LanProtocolException(
        'LAN v2 fragment out of order: got $fragIndex/$fragTotal expected '
        '$_expectedFragmentIndex/$_expectedFragmentTotal',
      );
    }
    _fragmentBuffer.addAll(clearText);
    _expectedFragmentIndex++;
    if (fragIndex < fragTotal - 1) {
      return null;
    }
    _expectedFragmentTotal = 0;
    final dynamic decoded = jsonDecode(utf8.decode(_fragmentBuffer));
    if (decoded is! Map) {
      throw const LanProtocolException('LAN v2 payload must be an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  int get nextSendSequence => _nextSendSequence;
  int get nextReceiveSequence => _nextReceiveSequence;

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _sendKey.destroy();
    _receiveKey.destroy();
  }

  void _ensureOpen() {
    if (_closed) {
      throw const LanProtocolException('LAN v2 secure session is closed');
    }
  }

  void _checkSequenceRange(int sequence) {
    if (sequence < 0 || sequence > 0x7fffffffffffffff) {
      throw const LanProtocolException(
        'LAN v2 sequence exhausted; rekey required',
      );
    }
  }

  List<int> _nonce(List<int> prefix, int sequence) {
    final ByteData bytes = ByteData(8)..setInt64(0, sequence, Endian.big);
    return <int>[...prefix, ...bytes.buffer.asUint8List()];
  }
}

/// Bounded FIFO work queue for server-side image reads/downloads.
class LanTaskQueue {
  final int maxConcurrent;
  final List<Future<void> Function()> _pending = <Future<void> Function()>[];
  int _active = 0;

  LanTaskQueue({this.maxConcurrent = 2}) : assert(maxConcurrent > 0);

  int get activeCount => _active;
  int get pendingCount => _pending.length;

  Future<T> run<T>(Future<T> Function() task) {
    final Completer<T> completer = Completer<T>();
    _pending.add(() async {
      try {
        completer.complete(await task());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    _pump();
    return completer.future;
  }

  void _pump() {
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final Future<void> Function() task = _pending.removeAt(0);
      _active++;
      task().whenComplete(() {
        _active--;
        _pump();
      });
    }
  }
}
