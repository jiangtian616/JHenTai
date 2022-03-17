import 'package:simple_logger/simple_logger.dart';

class Log {
  static final _logger = SimpleLogger()
    ..setLevel(
      Level.INFO,
      includeCallerInfo: true,
      callerInfoFrameLevelOffset: 1,
    );

  static final _loggerWithoutCaller = SimpleLogger()
    ..setLevel(
      Level.INFO,
    );

  static void info(Object? msg, [bool withCaller = true]) {
    withCaller ? _logger.info(msg) : _loggerWithoutCaller.info(msg);
  }

  static void warning(Object? msg, [bool withCaller = true]) {
    withCaller ? _logger.warning(msg) : _loggerWithoutCaller.warning(msg);
  }

  static void shout(Object? msg, [Object? error, bool withCaller = true]) {
    withCaller ? _logger.shout(msg) : _loggerWithoutCaller.shout(msg);
    if (error != null) {
      withCaller ? _logger.shout(msg) : _loggerWithoutCaller.shout(msg);
    }
  }
}
