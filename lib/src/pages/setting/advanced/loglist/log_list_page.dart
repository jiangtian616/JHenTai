import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:path/path.dart';

import '../../../../routes/routes.dart';
import '../../../../utils/route_util.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  _LogListPageState createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  List<io.FileSystemEntity> logs = [];

  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    io.Directory logDir = io.Directory(Log.logDirPath);
    if (logDir.existsSync()) {
      logs = logDir.listSync();
      logs.sort((a, b) => b.path.compareTo(a.path));
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('logList'.tr)),
      body: EHWheelSpeedController(
        controller: scrollController,
        child: ListView(
          controller: scrollController,
          children: logs
              .map(
                (log) => ListTile(title: Text(basename(log.path)), onTap: () => toRoute(Routes.log, arguments: log)),
              )
              .toList(),
        ).withListTileTheme(context),
      ),
    );
  }
}
