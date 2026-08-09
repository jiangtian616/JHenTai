import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:path/path.dart';

abstract interface class LanSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class PlatformLanSecretStore implements LanSecretStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'jhentai_lan_trust'),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
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
