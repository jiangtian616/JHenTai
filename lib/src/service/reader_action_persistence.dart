import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/reader_floating_ball_position.dart';
import 'package:jhentai/src/service/local_config_service.dart';

abstract class ReaderActionKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class LocalConfigReaderActionKeyValueStore
    implements ReaderActionKeyValueStore {
  @override
  Future<String?> read(String key) => localConfigService.read(
    configKey: ConfigEnum.readerActionPosition,
    subConfigKey: key,
  );

  @override
  Future<void> write(String key, String value) async {
    await localConfigService.write(
      configKey: ConfigEnum.readerActionPosition,
      subConfigKey: key,
      value: value,
    );
  }
}

class ReaderFloatingBallPositionStore {
  ReaderFloatingBallPositionStore({ReaderActionKeyValueStore? store})
    : _store = store ?? LocalConfigReaderActionKeyValueStore();

  final ReaderActionKeyValueStore _store;

  Future<ReaderFloatingBallPosition?> load(Orientation orientation) async {
    final String? raw = await _store.read(_orientationKey(orientation));
    if (raw == null) return null;
    try {
      return ReaderFloatingBallPosition.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }

  Future<void> save(
    Orientation orientation,
    ReaderFloatingBallPosition position,
  ) => _store.write(
    _orientationKey(orientation),
    jsonEncode(position.clamp().toJson()),
  );

  String _orientationKey(Orientation orientation) =>
      orientation == Orientation.portrait ? 'portrait' : 'landscape';
}
