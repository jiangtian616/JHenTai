import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BlankPage extends StatelessWidget {
  const BlankPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Get.theme.backgroundColor);
  }
}
