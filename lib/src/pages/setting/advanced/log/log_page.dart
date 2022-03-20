import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    return SafeArea(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: BoxConstraints(
              minHeight: context.height
            ),
            color: Get.theme.backgroundColor,
            child: SelectableText(
              (log as io.File).readAsStringSync(),
              style: TextStyle(
                fontSize: 12,
                color: Get.theme.appBarTheme.foregroundColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
