import 'dart:convert';

import 'package:integral_isolates/integral_isolates.dart';

import 'jh_service.dart';

IsolateService isolateService = IsolateService();

class IsolateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  /// A small pool instead of a single FIFO lane: gallery-list, detail,
  /// thumbnail and image-page HTML parses all funnel through here, and one
  /// slow parse used to block every other parse. Round-robin across a few
  /// isolates keeps parse throughput up without spawning one isolate per call.
  static const int _poolSize = 3;
  late final List<StatefulIsolate> _isolates;
  int _roundRobinIndex = 0;

  @override
  Future<void> doInitBean() async {
    _isolates = List.generate(_poolSize, (_) => StatefulIsolate());
    await Future.wait(_isolates.map((isolate) => isolate.init()));
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<String> jsonEncodeAsync(Object object) async {
    return run(jsonEncode, object);
  }

  Future<dynamic> jsonDecodeAsync(String string) async {
    return run(jsonDecode, string);
  }

  Future<R> run<Q, R>(IsolateCallback<Q, R> callback, Q message, {String? debugLabel}) {
    // Round-robin dispatch; messages for a single callback stay ordered per
    // isolate, which is the same guarantee the previous single-isolate FIFO
    // gave per callback.
    final StatefulIsolate isolate =
        _isolates[_roundRobinIndex++ % _isolates.length];
    return isolate.isolate(callback, message, debugLabel: debugLabel);
  }

  /// Releases all pooled isolates. Called on teardown (tests / app exit).
  Future<void> dispose() async {
    for (final StatefulIsolate isolate in _isolates) {
      await isolate.dispose();
    }
  }
}
