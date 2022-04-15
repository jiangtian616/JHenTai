import 'dart:io' as io;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:logger/logger.dart';
import 'package:logger/src/outputs/file_output.dart';
import 'package:path/path.dart' as path;
import 'package:sentry_flutter/sentry_flutter.dart';

class Log {
  static Logger? _log;
  static Logger? _logFile;

  static late final logPath;

  static Future<void> init() async {
    if (AdvancedSetting.enableLogging.value == false) {
      return;
    }

    logPath = path.join(PathSetting.getVisibleDir().path, 'logs');
    io.File logFile = io.File(path.join(logPath, '${DateFormat('yyyy-MM-dd HH:mm:mm').format(DateTime.now())}.log'));
    await logFile.create(recursive: true);

    LogPrinter devPrinter = PrettyPrinter(stackTraceBeginIndex: 1);
    LogPrinter prodPrinterWithBox = PrettyPrinter(stackTraceBeginIndex: 1, colors: false, printTime: true);
    LogPrinter prodPrinterWithoutBox = PrettyPrinter(stackTraceBeginIndex: 1, colors: false, noBoxingByDefault: true);

    _log = Logger(printer: devPrinter);
    _logFile = Logger(
      printer: HybridPrinter(prodPrinterWithBox, verbose: prodPrinterWithoutBox, info: prodPrinterWithoutBox),
      filter: ProductionFilter(),
      output: FileOutput(file: logFile),
    );

    PrettyPrinter.levelEmojis[Level.verbose] = '✔ ';
    verbose('init LogUtil success', false);
  }

  static void verbose(Object? msg, [bool withStack = true]) {
    _log?.v(msg, null, withStack ? null : StackTrace.empty);
    _logFile?.v(msg, null, withStack ? null : StackTrace.empty);
  }

  static void info(Object? msg, [bool withStack = true]) {
    _log?.i(msg, null, withStack ? null : StackTrace.empty);
    _logFile?.i(msg, null, withStack ? null : StackTrace.empty);
  }

  static void warning(Object? msg, [bool withStack = true]) {
    _log?.w(msg, null, withStack ? null : StackTrace.empty);
    _logFile?.w(msg, null, withStack ? null : StackTrace.empty);
  }

  static void error(Object? msg, [Object? error, StackTrace? stackTrace]) {
    _log?.e(msg, error, stackTrace);
    _logFile?.e(msg, error, stackTrace);
  }

  static String getSizeInKB() {
    io.Directory logDirectory = io.Directory(logPath);
    if (!logDirectory.existsSync()) {
      return '0KB';
    }

    int totalBytes = logDirectory
        .listSync()
        .fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());

    return (totalBytes / 1024).toStringAsFixed(2) + 'KB';
  }

  static void clear() {
    io.Directory logDirectory = io.Directory('${PathSetting.getVisibleDir().uri.toFilePath()}logs/');
    if (logDirectory.existsSync()) {
      logDirectory.delete(recursive: true);
    }
  }
}

T callWithParamsUploadIfErrorOccurs<T>(T Function() func, {dynamic params, T? defaultValue}) {
  try {
    return func.call();
  } on Exception catch (e) {
    Log.error('operationFailed'.tr, e);

    Iterable<DiagnosticsNode> infos;
    if (params is List) {
      infos = (params).map((e) => ErrorDescription(e.toString()));
    } else {
      infos = [ErrorDescription(params.toString())];
    }

    FirebaseCrashlytics.instance.recordError(e, null, information: infos);
    Sentry.captureException(e, hint: params.toString());
    if (defaultValue == null) {
      rethrow;
    }
    return defaultValue;
  }
}
