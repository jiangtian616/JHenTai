import 'dart:io' as io;

import 'package:intl/intl.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:logger/logger.dart';
import 'package:logger/src/outputs/file_output.dart';
import 'package:path/path.dart' as path;

class Log {
  static final Logger _log = Logger(printer: PrettyPrinter(stackTraceBeginIndex: 1));
  static Logger? _logFile;

  static late final logPath;

  static Future<void> init() async {
    if (AdvancedSetting.enableLogging.value == false) {
      return;
    }

    logPath = path.join(PathSetting.getVisiblePath().path, 'logs');

    io.File logFile = io.File(path.join(logPath, '${DateFormat('yyyy-MM-dd HH:mm:mm').format(DateTime.now())}.log'));
    await logFile.create(recursive: true);

    _logFile = Logger(
      printer: SimplePrinter(printTime: true, colors: false),
      filter: ProductionFilter(),
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

  static void error(Object? msg, [Object? errorMsg]) {
    _log.e(msg, errorMsg);
    _logFile?.e(msg, errorMsg);
  }

  static String getSizeInKB() {
    io.Directory logDirectory = io.Directory('${PathSetting.getVisiblePath().uri.toFilePath()}logs/');
    if (!logDirectory.existsSync()) {
      return '0KB';
    }
    int totalBytes = logDirectory
        .listSync()
        .fold<int>(0, (previousValue, element) => previousValue += (element as io.File).lengthSync());

    return (totalBytes / 1024).toStringAsFixed(2) + 'KB';
  }

  static void clear() {
    io. Directory logDirectory = io.Directory('${PathSetting.getVisiblePath().uri.toFilePath()}logs/');
    if (logDirectory.existsSync()) {
      logDirectory.delete(recursive: true);
    }
  }
}
