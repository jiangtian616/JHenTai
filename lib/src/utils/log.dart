import 'dart:io';

import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:logger/logger.dart';
import 'package:logger/src/outputs/file_output.dart';

class Log {
  static final Logger _log = Logger(printer: PrettyPrinter(stackTraceBeginIndex: 1));
  static Logger? _logFile;

  static Future<void> init() async {
    if (AdvancedSetting.enableLogging.value == false) {
      return;
    }

    File logFile = File('${PathSetting.getVisiblePath().uri.toFilePath()}logs/${DateTime.now().toString()}');
    await logFile.create(recursive: true);

    _logFile = Logger(
      printer: SimplePrinter(printTime: true, colors: false),
      output: FileOutput(file: logFile),
    );
  }

  static void info(Object? msg, [bool withStack = true]) {
    _log.i(msg, null, withStack ? null : StackTrace.empty);
    _logFile?.i(msg, null, withStack ? null : StackTrace.empty);
  }

  static void warning(Object? msg, [bool withStack = true]) {
    _log.w(msg, null, withStack ? null : StackTrace.empty);
    _logFile?.w(msg, null, withStack ? null : StackTrace.empty);
  }

  static void error(Object? msg, [Object? errorMsg, bool withStack = true]) {
    _log.e(msg, errorMsg, withStack ? null : StackTrace.empty);
    _logFile?.e(msg, errorMsg, withStack ? null : StackTrace.empty);
  }

  static String getSizeInKB() {
    Directory logDirectory = Directory('${PathSetting.getVisiblePath().uri.toFilePath()}logs/');
    if (!logDirectory.existsSync()) {
      return '0KB';
    }
    int totalBytes = logDirectory
        .listSync()
        .fold<int>(0, (previousValue, element) => previousValue += (element as File).lengthSync());

    return (totalBytes / 1024).toStringAsFixed(2) + 'KB';
  }

  static void clear() {
    Directory logDirectory = Directory('${PathSetting.getVisiblePath().uri.toFilePath()}logs/');
    if (logDirectory.existsSync()) {
      logDirectory.delete(recursive: true);
    }
  }
}
