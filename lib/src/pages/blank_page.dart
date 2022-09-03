import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BlankPage extends StatelessWidget {
  const BlankPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Get.theme.colorScheme.background,
      child: Center(
        child: Text(
          'J',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 120, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
