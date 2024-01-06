import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/screen_size_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../utils/toast_util.dart';

class LogPage extends StatefulWidget {
  const LogPage({Key? key}) : super(key: key);

  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late final File log;
  late final String logText;

  @override
  void initState() {
    super.initState();

    log = Get.arguments;
    logText = log.readAsStringSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(basename(log.path)),
        centerTitle: true,
        elevation: 1,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        actions: [
          if (!GetPlatform.isDesktop) IconButton(onPressed: _shareLog, icon: const Icon(Icons.share)),
          IconButton(onPressed: _copyLog, icon: const Icon(Icons.copy)),
        ],
      ),
      body: SelectableText(
        logText,
        scrollPhysics: const ClampingScrollPhysics(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: Platform.isAndroid ? 'monospace' : 'PingFang HK',
        ),
      ).marginSymmetric(horizontal: 4),
    );
  }

  void _shareLog() {
    Share.shareFiles(
      [log.path],
      text: basename(log.path),
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
    );
  }

  Future<void> _copyLog() async {
    if (isEmptyOrNull(logText)) {
      return;
    }
    await FlutterClipboard.copy(logText);
    toast('hasCopiedToClipboard'.tr);
  }
}
