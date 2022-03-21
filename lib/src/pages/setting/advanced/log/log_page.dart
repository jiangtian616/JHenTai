import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
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
        titleTextStyle: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            (log as io.File).readAsStringSync(),

            /// draggable
            minLines: 99,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ),
      ).marginOnly(top: 8),
    );
  }
}
