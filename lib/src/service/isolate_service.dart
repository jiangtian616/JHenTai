import 'dart:async';
import 'dart:convert';

import 'package:integral_isolates/integral_isolates.dart';

import 'jh_service.dart';

IsolateService isolateService = IsolateService();

class IsolateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  StatefulIsolate? _isolate;
  Completer<void>? _initCompleter;

  @override
  Future<void> doInitBean() async {
    // Defer isolate spawning to first use
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> _ensureInitialized() async {
    if (_isolate != null) {
      return;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      final isolate = StatefulIsolate();
      await isolate.init();
      _isolate = isolate;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<String> jsonEncodeAsync(Object object) async {
    return run(jsonEncode, object);
  }

  Future<dynamic> jsonDecodeAsync(String string) async {
    return run(jsonDecode, string);
  }

  Future<R> run<Q, R>(IsolateCallback<Q, R> callback, Q message, {String? debugLabel}) async {
    await _ensureInitialized();
    return _isolate!.isolate(callback, message, debugLabel: debugLabel);
  }
}
