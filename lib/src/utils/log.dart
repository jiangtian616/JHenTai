import 'dart:io' as io;

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:logger/logger.dart';
import 'package:logger/src/outputs/file_output.dart';
import 'package:path/path.dart' as path;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../exception/upload_exception.dart';

class Log {
  static Logger? _logger;
  static Logger? _verboseFileLogger;
  static Logger? _warningFileLogger;

  static final String logDirPath = path.join(PathSetting.getVisibleDir().path, 'logs');

  static Future<void> init() async {
    if (AdvancedSetting.enableLogging.value == false) {
      return;
    }

    LogPrinter devPrinter = PrettyPrinter(stackTraceBeginIndex: 1);
    LogPrinter prodPrinterWithBox = PrettyPrinter(stackTraceBeginIndex: 1, colors: false, printTime: true);
    LogPrinter prodPrinterWithoutBox = PrettyPrinter(stackTraceBeginIndex: 1, colors: false, noBoxingByDefault: true);
    _logger = Logger(printer: devPrinter);

    io.File verboseLogFile =
        io.File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH:mm:mm').format(DateTime.now())}.log'));
    await verboseLogFile.create(recursive: true);
    _verboseFileLogger = Logger(
      printer: HybridPrinter(prodPrinterWithBox, verbose: prodPrinterWithoutBox, info: prodPrinterWithoutBox),
      filter: ProductionFilter(),
      output: FileOutput(file: verboseLogFile),
    );

    io.File waringLogFile =
        io.File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH:mm:mm').format(DateTime.now())}_error.log'));
    await waringLogFile.create(recursive: true);
    _warningFileLogger = Logger(
      level: Level.warning,
      printer: prodPrinterWithBox,
      filter: ProductionFilter(),
      output: FileOutput(file: waringLogFile),
    );

    PrettyPrinter.levelEmojis[Level.verbose] = '✔ ';
    verbose('init LogUtil success', false);
  }

  static void verbose(Object? msg, [bool withStack = true]) {
    _logger?.v(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.v(msg, null, withStack ? null : StackTrace.empty);
  }

  static void info(Object? msg, [bool withStack = true]) {
    _logger?.i(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.i(msg, null, withStack ? null : StackTrace.empty);
  }

  static void warning(Object? msg, [bool withStack = true]) {
    _logger?.w(msg, null, withStack ? null : StackTrace.empty);
    _verboseFileLogger?.w(msg, null, withStack ? null : StackTrace.empty);
    _warningFileLogger?.w(msg, null, withStack ? null : StackTrace.empty);
  }

  static void error(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _logger?.e(msg, error, stackTrace);
    _verboseFileLogger?.e(msg, error, stackTrace);
    _warningFileLogger?.e(msg, error, stackTrace);
  }

  static Future<void> upload(dynamic throwable, {dynamic stackTrace, dynamic params}) async {
    if (_shouldDismissUpload(throwable)) {
      return;
    }

    String paramsString = _cleanPrivacy(params.toString());

    if (paramsString.length <= 1000) {
      Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setContexts('params', paramsString),
      );
    } else {
      Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        withScope: (scope) => scope.addAttachment(SentryAttachment.fromIntList(paramsString.codeUnits, 'params.txt')),
      );
    }
  }

  static String getSize() {
    io.Directory logDirectory = io.Directory(logDirPath);
    if (!logDirectory.existsSync()) {
      return '0KB';
    }

    int totalBytes = logDirectory
        .listSync()
        .fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());

    if (totalBytes < 1024) {
      return '${totalBytes}B';
    }
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(2)}KB';
    }
    return '${(totalBytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }

  static void clear() {
    io.Directory logDirectory = io.Directory('${PathSetting.getVisibleDir().uri.toFilePath()}logs/');
    if (logDirectory.existsSync()) {
      logDirectory.delete(recursive: true);
    }
  }

  static bool _shouldDismissUpload(throwable) {
    if (throwable is StateError && throwable.message.contains('Failed to load https')) {
      return true;
    }

    return false;
  }

  static String _cleanPrivacy(String raw) {
    String pattern = r'(password|secret|passwd|api_key|apikey|auth) = ("|\w)+';
    return raw.replaceAll(RegExp(pattern), '');
  }
}

T callWithParamsUploadIfErrorOccurs<T>(T Function() func, {dynamic params, T? defaultValue}) {
  try {
    return func.call();
  } on Exception catch (e) {
    Log.error('operationFailed'.tr, e);
    Log.upload(e, params: params);
    if (defaultValue == null) {
      throw UploadException(e);
    }
    return defaultValue;
  }
}
