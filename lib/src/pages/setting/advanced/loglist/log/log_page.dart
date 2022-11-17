import 'dart:io' as io;

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
  late final io.FileSystemEntity log;

  @override
  void initState() {
    log = Get.arguments;
    super.initState();
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
          if (!GetPlatform.isDesktop) IconButton(onPressed: () => _shareLog(log as io.File), icon: const Icon(Icons.share)),
          IconButton(onPressed: () => _copyLog(log as io.File), icon: const Icon(Icons.copy)),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: SelectableText(
            (log as io.File).readAsStringSync(),
            scrollPhysics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: io.Platform.isAndroid ? 'monospace' : 'PingFang HK',
            ),
          ),
        ).paddingOnly(top: 8, left: 4, right: 4),
      ),
    );
  }

  void _shareLog(io.File file) {
    Share.shareFiles(
      [file.path],
      text: basename(file.path),
      sharePositionOrigin: Rect.fromLTWH(0, 0, fullScreenWidth, screenHeight * 2 / 3),
    );
  }

  Future<void> _copyLog(io.File file) async {
    String content = file.readAsStringSync();
    if (isEmptyOrNull(content)) {
      return;
    }
    await FlutterClipboard.copy(file.readAsStringSync());
    toast('hasCopiedToClipboard'.tr);
  }
}
