import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/size_util.dart';
import 'package:path/path.dart';

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
        ).paddingOnly(top: 8),
      ),
    );
  }
}
