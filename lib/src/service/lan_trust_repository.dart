import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

abstract interface class LanSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// File-backed credential storage for builds that cannot use an OS keychain.
///
/// Values are authenticated and encrypted with AES-256-GCM. The installation
/// key is intentionally stored separately from the encrypted vault so secrets
/// are never present as plain text. This protects against accidental exposure
/// and copied vault files, but it cannot protect against an attacker who can
/// read both files as the current OS user.
class EncryptedFileLanSecretStore implements LanSecretStore {
  static const int _schemaVersion = 1;
  static const int _keyLength = 32;
  static const int _nonceLength = 12;

  final Directory directory;
  final Random _secureRandom;
  final Cipher _cipher;
  final Lock _lock = Lock();

  EncryptedFileLanSecretStore({
    required this.directory,
    Random? secureRandom,
    Cipher? cipher,
  }) : _secureRandom = secureRandom ?? Random.secure(),
       _cipher = cipher ?? AesGcm.with256bits();

  File get _keyFile => File(join(directory.path, '.credential-key'));

  File get _vaultFile => File(join(directory.path, 'credentials.v1.enc'));

  @override
  Future<String?> read(String key) =>
      _lock.synchronized(() async => (await _readValues())[key]);

  @override
  Future<void> write(String key, String value) => _lock.synchronized(() async {
    final Map<String, String> values = await _readValues();
    values[key] = value;
    await _writeValues(values);
  });

  @override
  Future<void> delete(String key) => _lock.synchronized(() async {
    final Map<String, String> values = await _readValues();
    if (values.remove(key) != null) {
      await _writeValues(values);
    }
  });

  Future<Map<String, String>> _readValues() async {
    await directory.create(recursive: true);
    if (!await _vaultFile.exists()) {
      return {};
    }
    final dynamic envelope = jsonDecode(await _vaultFile.readAsString());
    if (envelope is! Map || envelope['version'] != _schemaVersion) {
      throw const FormatException('Unsupported LAN credential vault');
    }
    final List<int> nonce = _decodeBytes(envelope['nonce'], _nonceLength);
    final List<int> cipherText = _decodeBytes(envelope['cipherText']);
    final List<int> mac = _decodeBytes(envelope['mac'], 16);
    final List<int> clearText = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(await _loadOrCreateKey()),
    );
    final dynamic decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map) {
      throw const FormatException('Invalid LAN credential vault');
    }
    return decoded.map<String, String>((key, value) {
      if (key is! String || value is! String) {
        throw const FormatException('Invalid LAN credential entry');
      }
      return MapEntry(key, value);
    });
  }

  Future<void> _writeValues(Map<String, String> values) async {
    await directory.create(recursive: true);
    final List<int> nonce = List<int>.generate(
      _nonceLength,
      (_) => _secureRandom.nextInt(256),
    );
    final SecretBox encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(values)),
      secretKey: SecretKey(await _loadOrCreateKey()),
      nonce: nonce,
    );
    final String envelope = jsonEncode({
      'version': _schemaVersion,
      'nonce': base64UrlEncode(encrypted.nonce),
      'cipherText': base64UrlEncode(encrypted.cipherText),
      'mac': base64UrlEncode(encrypted.mac.bytes),
    });
    final File temporary = File('${_vaultFile.path}.tmp');
    await temporary.writeAsString(envelope, flush: true);
    await _restrictToCurrentUser(temporary);
    if (await _vaultFile.exists() && Platform.isWindows) {
      await _vaultFile.delete();
    }
    await temporary.rename(_vaultFile.path);
  }

  Future<List<int>> _loadOrCreateKey() async {
    await directory.create(recursive: true);
    if (await _keyFile.exists()) {
      final List<int> existing = await _keyFile.readAsBytes();
      if (existing.length != _keyLength) {
        throw const FormatException('Invalid LAN credential key');
      }
      return existing;
    }
    final List<int> generated = List<int>.generate(
      _keyLength,
      (_) => _secureRandom.nextInt(256),
    );
    final File temporary = File('${_keyFile.path}.tmp');
    await temporary.writeAsBytes(generated, flush: true);
    await _restrictToCurrentUser(temporary);
    if (await _keyFile.exists()) {
      await temporary.delete();
      return _keyFile.readAsBytes();
    }
    await temporary.rename(_keyFile.path);
    return generated;
  }

  List<int> _decodeBytes(dynamic value, [int? expectedLength]) {
    if (value is! String) {
      throw const FormatException('Invalid LAN credential vault');
    }
    final List<int> bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(value));
    } on FormatException {
      throw const FormatException('Invalid LAN credential vault');
    }
    if (expectedLength != null && bytes.length != expectedLength) {
      throw const FormatException('Invalid LAN credential vault');
    }
    return bytes;
  }

  Future<void> _restrictToCurrentUser(File file) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    final ProcessResult result = await Process.run('chmod', ['600', file.path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Unable to restrict LAN credential permissions',
        file.path,
      );
    }
  }
}

class LanDeviceCredentials {
  final String remoteAccessToken;
  final String inboundAccessToken;

  const LanDeviceCredentials({
    required this.remoteAccessToken,
    required this.inboundAccessToken,
  });
}

abstract interface class LanTrustRepository {
  Future<void> init();

  Future<String> ensureLocalDeviceId(String Function() generator);

  Future<String?> readLocalDeviceName();

  Future<void> saveLocalDeviceName(String name);

  Future<String?> readLocalIdentitySeed();

  Future<void> saveLocalIdentitySeed(String seed);

  Future<List<TrustedLanDevice>> loadDevices();

  Future<void> saveDevice(
    TrustedLanDevice device, {
    required String remoteAccessToken,
    required String inboundAccessToken,
  });

  Future<void> updateDevice(TrustedLanDevice device);

  Future<LanDeviceCredentials?> credentialsFor(String deviceId);

  Future<void> revokeDevice(String deviceId);
}

class FileLanTrustRepository implements LanTrustRepository {
  static const int schemaVersion = 1;
  static const String _remoteTokenPrefix = 'lan.remote.';
  static const String _inboundTokenPrefix = 'lan.inbound.';
  static const String _localIdentitySeedKey = 'lan.identity.ed25519.seed';

  final Directory directory;
  final LanSecretStore secretStore;

  FileLanTrustRepository({required this.directory, required this.secretStore});

  File get _metadataFile => File(join(directory.path, 'trusted_devices.json'));

  Map<String, dynamic> _metadata = {
    'schemaVersion': schemaVersion,
    'devices': <Map<String, dynamic>>[],
  };

  @override
  Future<void> init() async {
    await directory.create(recursive: true);
    if (!await _metadataFile.exists()) {
      await _persist();
      return;
    }

    try {
      final dynamic decoded = jsonDecode(await _metadataFile.readAsString());
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        throw const FormatException('Unsupported LAN trust metadata');
      }
      final List<TrustedLanDevice> validDevices =
          (decoded['devices'] as List? ?? const [])
              .whereType<Map>()
              .map((entry) {
                try {
                  return TrustedLanDevice.fromJson(
                    Map<String, dynamic>.from(entry),
                  );
                } on Object {
                  return null;
                }
              })
              .whereType<TrustedLanDevice>()
              .toList();
      _metadata = {
        'schemaVersion': schemaVersion,
        if (decoded['localDeviceId'] is String)
          'localDeviceId': decoded['localDeviceId'],
        if (decoded['localDeviceName'] is String)
          'localDeviceName': decoded['localDeviceName'],
        'devices': validDevices.map((device) => device.toJson()).toList(),
      };
    } on Object {
      final File corrupt = File(
        '${_metadataFile.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      await _metadataFile.rename(corrupt.path);
      _metadata = {
        'schemaVersion': schemaVersion,
        'devices': <Map<String, dynamic>>[],
      };
      await _persist();
    }
  }

  @override
  Future<String> ensureLocalDeviceId(String Function() generator) async {
    final String? existing = _metadata['localDeviceId'] as String?;
    if (existing != null &&
        TrustedLanDevice.deviceIdPattern.hasMatch(existing)) {
      return existing;
    }
    final String generated = generator();
    if (!TrustedLanDevice.deviceIdPattern.hasMatch(generated)) {
      throw ArgumentError.value(generated, 'generator', 'Invalid device id');
    }
    _metadata['localDeviceId'] = generated;
    await _persist();
    return generated;
  }

  @override
  Future<String?> readLocalDeviceName() =>
      Future.value(_metadata['localDeviceName'] as String?);

  @override
  Future<void> saveLocalDeviceName(String name) async {
    final String trimmed = name.trim();
    _metadata['localDeviceName'] = trimmed;
    await _persist();
  }

  @override
  Future<String?> readLocalIdentitySeed() =>
      secretStore.read(_localIdentitySeedKey);

  @override
  Future<void> saveLocalIdentitySeed(String seed) async {
    final List<int> bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(seed));
    } on FormatException {
      throw const FormatException('Invalid LAN identity seed');
    }
    if (bytes.length != 32) {
      throw const FormatException('Invalid LAN identity seed');
    }
    await secretStore.write(_localIdentitySeedKey, seed);
  }

  @override
  Future<List<TrustedLanDevice>> loadDevices() async =>
      _deviceList().map(TrustedLanDevice.fromJson).toList();

  @override
  Future<void> saveDevice(
    TrustedLanDevice device, {
    required String remoteAccessToken,
    required String inboundAccessToken,
  }) async {
    _validateAccessToken(remoteAccessToken);
    _validateAccessToken(inboundAccessToken);

    final String remoteKey = '$_remoteTokenPrefix${device.deviceId}';
    final String inboundKey = '$_inboundTokenPrefix${device.deviceId}';
    final String? oldRemote = await secretStore.read(remoteKey);
    final String? oldInbound = await secretStore.read(inboundKey);
    await secretStore.write(remoteKey, remoteAccessToken);
    await secretStore.write(inboundKey, inboundAccessToken);
    try {
      await updateDevice(device);
    } on Object {
      await _restoreSecret(remoteKey, oldRemote);
      await _restoreSecret(inboundKey, oldInbound);
      rethrow;
    }
  }

  @override
  Future<void> updateDevice(TrustedLanDevice device) async {
    final List<Map<String, dynamic>> devices = _deviceList();
    devices.removeWhere((entry) => entry['deviceId'] == device.deviceId);
    devices.add(device.toJson());
    devices.sort(
      (a, b) =>
          (a['displayName'] as String).compareTo(b['displayName'] as String),
    );
    final Map<String, dynamic> updated = Map<String, dynamic>.from(_metadata)
      ..['devices'] = devices;
    await _persist(updated);
    _metadata = updated;
  }

  @override
  Future<LanDeviceCredentials?> credentialsFor(String deviceId) async {
    final String? remote = await secretStore.read(
      '$_remoteTokenPrefix$deviceId',
    );
    final String? inbound = await secretStore.read(
      '$_inboundTokenPrefix$deviceId',
    );
    if (remote == null || inbound == null) {
      return null;
    }
    return LanDeviceCredentials(
      remoteAccessToken: remote,
      inboundAccessToken: inbound,
    );
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    final List<Map<String, dynamic>> devices = _deviceList();
    devices.removeWhere((entry) => entry['deviceId'] == deviceId);
    final Map<String, dynamic> updated = Map<String, dynamic>.from(_metadata)
      ..['devices'] = devices;
    await _persist(updated);
    _metadata = updated;
    await Future.wait([
      secretStore.delete('$_remoteTokenPrefix$deviceId'),
      secretStore.delete('$_inboundTokenPrefix$deviceId'),
    ]);
  }

  List<Map<String, dynamic>> _deviceList() =>
      (_metadata['devices'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();

  Future<void> _persist([Map<String, dynamic>? value]) async {
    await directory.create(recursive: true);
    final File temporary = File('${_metadataFile.path}.tmp');
    await temporary.writeAsString(jsonEncode(value ?? _metadata), flush: true);
    if (await _metadataFile.exists()) {
      if (Platform.isWindows) {
        await _metadataFile.delete();
      }
    }
    await temporary.rename(_metadataFile.path);
  }

  Future<void> _restoreSecret(String key, String? value) =>
      value == null ? secretStore.delete(key) : secretStore.write(key, value);

  void _validateAccessToken(String token) {
    if (token.length < 43 ||
        token.length > 256 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(token)) {
      throw const FormatException('Invalid LAN access token');
    }
  }
}
