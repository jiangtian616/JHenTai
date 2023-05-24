import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:logger/logger.dart';
import 'package:logger/src/outputs/file_output.dart';
import 'package:path/path.dart' as path;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../exception/upload_exception.dart';

class Log {
  static Logger? _consoleLogger;
  static Logger? _verboseFileLogger;
  static Logger? _warningFileLogger;
  static Logger? _downloadFileLogger;
  static late File _verboseLogFile;
  static late File _waringLogFile;
  static late File _downloadLogFile;

  static final String logDirPath = path.join(PathSetting.getVisibleDir().path, 'logs');

  static Future<void> init() async {
    if (AdvancedSetting.enableLogging.value == false) {
      return;
    }

    if (!Directory(logDirPath).existsSync()) {
      Directory(logDirPath).createSync();
    }

    LogPrinter devPrinter = PrettyPrinter(stackTraceBeginIndex: 1, methodCount: 3);
    LogPrinter prodPrinterWithBox = PrettyPrinter(stackTraceBeginIndex: 1, methodCount: 3, colors: false, printTime: true);
    LogPrinter prodPrinterWithoutBox = PrettyPrinter(stackTraceBeginIndex: 1, methodCount: 3, colors: false, noBoxingByDefault: true);

    _consoleLogger = Logger(printer: devPrinter);

    _verboseLogFile = File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.log'));
    _verboseFileLogger = Logger(
      printer: HybridPrinter(prodPrinterWithBox, verbose: prodPrinterWithoutBox, debug: prodPrinterWithoutBox, info: prodPrinterWithoutBox),
      filter: EHLogFilter(),
      output: FileOutput(file: File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.log'))),
    );
    PrettyPrinter.levelEmojis[Level.verbose] = '✔ ';

    if (AdvancedSetting.enableVerboseLogging.isTrue) {
      _waringLogFile = File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}_error.log'));
      _warningFileLogger = Logger(
        level: Level.warning,
        printer: prodPrinterWithBox,
        filter: ProductionFilter(),
        output: FileOutput(file: _waringLogFile),
      );

      _downloadLogFile = File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}_download.log'));
      _downloadFileLogger = Logger(
        printer: prodPrinterWithoutBox,
        filter: ProductionFilter(),
        output: FileOutput(file: _downloadLogFile),
      );
    }

    debug('init LogUtil success', false);
  }

  /// For actions that print params
  static void verbose(Object? msg, [bool withStack = false]) {
    _consoleLogger?.v(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.v(msg, null, withStack ? null : StackTrace.empty);
  }

  /// For actions that is invisible to user
  static void debug(Object? msg, [bool withStack = false]) {
    _consoleLogger?.d(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.d(msg, null, withStack ? null : StackTrace.empty);
  }

  /// For actions that is visible to user
  static void info(Object? msg, [bool withStack = false]) {
    _consoleLogger?.i(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.i(msg, null, withStack ? null : StackTrace.empty);
  }

  static void warning(Object? msg, [bool withStack = false]) {
    _consoleLogger?.w(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.w(msg, null, withStack ? null : StackTrace.empty);
    _warningFileLogger?.w(msg, null, withStack ? null : StackTrace.empty);
  }

  static void error(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _consoleLogger?.e(msg, error, stackTrace);
    _verboseFileLogger?.e(msg, error, stackTrace);
    _warningFileLogger?.e(msg, error, stackTrace);
  }

  static void download(Object? msg) {
    _consoleLogger?.v(msg, null, StackTrace.empty);
    _downloadFileLogger?.v(msg, null, StackTrace.empty);
  }

  static Future<void> upload(
    dynamic throwable, {
    dynamic stackTrace,
    Map<String, dynamic>? extraInfos,
  }) async {
    if (_shouldDismissUpload(throwable)) {
      return;
    }

    extraInfos = _extractExtraInfos(throwable, stackTrace, extraInfos);

    /// Wait for full log
    Future.delayed(const Duration(seconds: 3)).then(
      (_) => Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (UserSetting.hasLoggedIn()) {
            if (scope.user != null) {
              scope.setUser(scope.user!.copyWith(id: UserSetting.userName.value, username: UserSetting.userName.value));
            } else {
              scope.setUser(SentryUser(id: UserSetting.userName.value, username: UserSetting.userName.value));
            }
          }

          extraInfos?.forEach((key, value) {
            String cleanedValue = _cleanPrivacy(value.toString());
            if (cleanedValue.length < 1000) {
              scope.setExtra(key, cleanedValue);
            } else {
              scope.addAttachment(SentryAttachment.fromIntList(cleanedValue.codeUnits, '$key.log'));
            }
          });

          if (_shouldAttachLogFile(stackTrace)) {
            Uint8List verboseAttachment = _verboseLogFile.readAsBytesSync();
            if (verboseAttachment.isNotEmpty) {
              scope.addAttachment(SentryAttachment.fromUint8List(verboseAttachment, path.basename(_verboseLogFile.path)));
            }
          }
        },
      ),
    );
  }

  static String getSize() {
    Directory logDirectory = Directory(logDirPath);
    if (!logDirectory.existsSync()) {
      return '0KB';
    }

    int totalBytes = -1;
    try {
      totalBytes = logDirectory.listSync().fold<int>(0, (previousValue, element) => previousValue += (element as File).lengthSync());
    } on Exception catch (e) {
      Log.upload(e, extraInfos: {'files': logDirectory.listSync()});
    }

    if (totalBytes < 1024) {
      return '${totalBytes}B';
    }
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(2)}KB';
    }
    return '${(totalBytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }

  static void clear() {
    _verboseFileLogger?.close();
    _warningFileLogger?.close();
    _downloadFileLogger?.close();

    _verboseFileLogger = null;
    _warningFileLogger = null;
    _downloadFileLogger = null;

    /// need to wait for log file close
    Future.delayed(
      const Duration(milliseconds: 500),
      () {
        if (Directory(logDirPath).existsSync()) {
          Directory(logDirPath).deleteSync(recursive: true);
        }
      },
    );
  }

  static bool _shouldDismissUpload(throwable) {
    if (throwable is StateError && throwable.message.contains('Failed to load https')) {
      return true;
    }
    if (throwable is StateError && throwable.message.contains('User cancel request')) {
      return true;
    }
    // if (throwable is DioError && throwable.message.contains('Http status error')) {
    //   return true;
    // }
    if (throwable is HttpException && throwable.message.contains('Connection closed while receiving data')) {
      return true;
    }
    if (throwable is StateError && throwable.message.contains('Reading from a closed socket')) {
      return true;
    }
    if (throwable is SocketException && throwable.message.contains('Reading from a closed socket')) {
      return true;
    }
    if (throwable is DioError && throwable.message.contains('HandshakeException')) {
      return true;
    }
    if (throwable is DioError && throwable.message.contains('Connection closed while receiving data')) {
      return true;
    }
    if (throwable is TimeoutException && (throwable.message?.contains('Executor is closing') ?? false)) {
      return true;
    }
    return false;
  }

  static bool _shouldAttachLogFile(dynamic stackTrace) {
    if (stackTrace == null) {
      return true;
    }

    /// todo:
    if (stackTrace.toString().contains('Scrollable.recommendDeferredLoadingForContext')) {
      return false;
    }

    return true;
  }

  static Map<String, dynamic> _extractExtraInfos(dynamic throwable, dynamic stackTrace, Map<String, dynamic>? extraInfos) {
    extraInfos ??= {};

    if (throwable is JsonUnsupportedObjectError) {
      extraInfos['object'] = throwable.unsupportedObject;
      extraInfos['cause'] = throwable.cause;
      extraInfos['partialResult'] = throwable.partialResult;
    }

    return extraInfos;
  }

  static String _cleanPrivacy(String raw) {
    String pattern = r'(password|secret|passwd|api_key|apikey|auth) = ("|\w)+';
    return raw.replaceAll(RegExp(pattern), '');
  }
}

class EHLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (AdvancedSetting.enableVerboseLogging.isTrue) {
      return event.level.index >= level!.index;
    }
    return event.level.index >= level!.index && event.level != Level.verbose;
  }
}

T callWithParamsUploadIfErrorOccurs<T>(T Function() func, {dynamic params, T? defaultValue}) {
  try {
    return func.call();
  } on Exception catch (e) {
    if (e is DioError || e is EHException) {
      rethrow;
    }

    Log.error('operationFailed'.tr, e);
    Log.upload(e, extraInfos: {'params': params});
    if (defaultValue == null) {
      throw NotUploadException(e);
    }
    return defaultValue;
  } on Error catch (e) {
    Log.error('operationFailed'.tr, e);
    Log.upload(e, extraInfos: {'params': params});
    if (defaultValue == null) {
      throw NotUploadException(e);
    }
    return defaultValue;
  }
}
