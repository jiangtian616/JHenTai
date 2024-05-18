import 'package:integral_isolates/integral_isolates.dart';

import '../utils/log.dart';

class IsolateService {
  static late final StatefulIsolate _isolate;

  static Future<void> init() async {
    _isolate = StatefulIsolate();
    await _isolate.init();
    Log.debug('init IsolateService success');
  }

  static Future<R> run<Q, R>(IsolateCallback<Q, R> callback, Q message, {String? debugLabel}) {
    return _isolate.isolate(callback, message, debugLabel: debugLabel);
  }
}
