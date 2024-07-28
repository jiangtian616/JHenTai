import 'dart:convert';

import 'package:integral_isolates/integral_isolates.dart';

import 'jh_service.dart';

IsolateService isolateService = IsolateService();

class IsolateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final StatefulIsolate _isolate;

  @override
  Future<void> doInitBean() async {
    _isolate = StatefulIsolate();
    await _isolate.init();
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
    return _isolate.isolate(callback, message, debugLabel: debugLabel);
  }
}
