import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../exception/upload_exception.dart';
import 'byte_util.dart';

class Log {
  static Logger? _consoleLogger;
  static Logger? _verboseFileLogger;
  static Logger? _warningFileLogger;
  static Logger? _downloadFileLogger;

  static LogPrinter devPrinter = PrettyPrinter(stackTraceBeginIndex: 0, methodCount: 6, levelEmojis: {Level.trace: '✔ '});
  static LogPrinter prodPrinterWithBox =
      PrettyPrinter(stackTraceBeginIndex: 0, methodCount: 6, colors: false, printTime: true, levelEmojis: {Level.trace: '✔ '});
  static LogPrinter prodPrinterWithoutBox =
      PrettyPrinter(stackTraceBeginIndex: 0, methodCount: 6, colors: false, noBoxingByDefault: true, levelEmojis: {Level.trace: '✔ '});

  static late final String logDirPath;

  static Future<void> init() async {
    logDirPath = path.join(pathService.getVisibleDir().path, 'logs');
    if (!await Directory(logDirPath).exists()) {
      await Directory(logDirPath).create();
    }
    _consoleLogger = Logger(printer: devPrinter);
  }

  /// For actions that print params
  static void trace(Object msg, [bool withStack = false]) {
    _consoleLogger?.t(msg, stackTrace: withStack ? null : StackTrace.empty);
    _initVerboseFileLogger().then((_) => _verboseFileLogger?.t(msg, stackTrace: withStack ? null : StackTrace.empty));
  }

  /// For actions that is invisible to user
  static void debug(Object msg, [bool withStack = false]) {
    _consoleLogger?.d(msg, stackTrace: withStack ? null : StackTrace.empty);
    _initVerboseFileLogger().then((_) => _verboseFileLogger?.d(msg, stackTrace: withStack ? null : StackTrace.empty));
  }

  /// For actions that is visible to user
  static void info(Object msg, [bool withStack = false]) {
    _consoleLogger?.i(msg, stackTrace: withStack ? null : StackTrace.empty);
    _initVerboseFileLogger().then((_) => _verboseFileLogger?.i(msg, stackTrace: withStack ? null : StackTrace.empty));
  }

  static void warning(Object msg, [Object? error, bool withStack = false]) {
    _consoleLogger?.w(msg, stackTrace: withStack ? null : StackTrace.empty);
    _initVerboseFileLogger().then((_) => _verboseFileLogger?.w(msg, stackTrace: withStack ? null : StackTrace.empty));

    if (advancedSetting.enableVerboseLogging.isTrue) {
      _initWarningFileLogger().then((_) => _warningFileLogger?.w(msg, stackTrace: withStack ? null : StackTrace.empty));
    }
  }

  static void error(Object msg, [Object? error, StackTrace? stackTrace]) {
    _consoleLogger?.e(msg, error: error, stackTrace: stackTrace);
    _initVerboseFileLogger().then((_) => _verboseFileLogger?.e(msg, error: error, stackTrace: stackTrace));
    if (advancedSetting.enableVerboseLogging.isTrue) {
      _initWarningFileLogger().then((_) => _verboseFileLogger?.e(msg, error: error, stackTrace: stackTrace));
    }
  }

  static void download(Object msg) {
    _consoleLogger?.t(msg, stackTrace: StackTrace.empty);
    if (advancedSetting.enableVerboseLogging.isTrue) {
      _initDownloadFileLogger().then((_) => _verboseFileLogger?.t(msg, stackTrace: StackTrace.empty));
    }
  }

  static Future<void> uploadError(dynamic throwable, {dynamic stackTrace, Map<String, dynamic>? extraInfos}) async {
    /// sentry is removed
  }

  static Future<String> getSize() async {
    return compute(
      (logDirPath) {
        Directory logDirectory = Directory(logDirPath);
        return logDirectory.exists().then<int>((exist) {
          if (!exist) {
            return 0;
          }

          return logDirectory.list().fold<int>(0, (previousValue, element) => previousValue += (element as File).lengthSync());
        }).then<String>((totalBytes) => byte2String(totalBytes.toDouble()));
      },
      logDirPath,
    );
  }

  static Future<void> clear() async {
    await _verboseFileLogger?.close();
    await _warningFileLogger?.close();
    await _downloadFileLogger?.close();

    _verboseFileLogger = null;
    _warningFileLogger = null;
    _downloadFileLogger = null;

    if (await Directory(logDirPath).exists()) {
      await Directory(logDirPath).delete(recursive: true);
    }
  }

  static Future<void> _initVerboseFileLogger() {
    _verboseFileLogger ??= Logger(
      printer: HybridPrinter(prodPrinterWithBox, trace: prodPrinterWithoutBox, debug: prodPrinterWithoutBox, info: prodPrinterWithoutBox),
      filter: EHLogFilter(),
      output: FileOutput(file: File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.log'))),
    );
    return _verboseFileLogger!.init;
  }

  static Future<void> _initWarningFileLogger() {
    _warningFileLogger ??= Logger(
      level: Level.warning,
      printer: prodPrinterWithBox,
      filter: ProductionFilter(),
      output: FileOutput(file: File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}_error.log'))),
    );
    return _warningFileLogger!.init;
  }

  static Future<void> _initDownloadFileLogger() {
    _downloadFileLogger ??= Logger(
      printer: prodPrinterWithoutBox,
      filter: ProductionFilter(),
      output: FileOutput(file: File(path.join(logDirPath, '${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}_download.log'))),
    );
    return _downloadFileLogger!.init;
  }
}

class EHLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (advancedSetting.enableVerboseLogging.isTrue) {
      return event.level.index >= level!.index;
    }
    return event.level.index >= level!.index && event.level != Level.trace;
  }
}

T callWithParamsUploadIfErrorOccurs<T>(T Function() func, {dynamic params, T? defaultValue}) {
  try {
    return func.call();
  } on Exception catch (e) {
    if (e is DioException || e is EHSiteException) {
      rethrow;
    }

    Log.error('operationFailed'.tr, e);
    Log.uploadError(e, extraInfos: {'params': params});
    if (defaultValue == null) {
      throw NotUploadException(e);
    }
    return defaultValue;
  } on Error catch (e) {
    Log.error('operationFailed'.tr, e);
    Log.uploadError(e, extraInfos: {'params': params});
    if (defaultValue == null) {
      throw NotUploadException(e);
    }
    return defaultValue;
  }
}
