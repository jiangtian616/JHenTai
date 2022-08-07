import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';

class JumpPageDialog extends StatelessWidget {
  final TextEditingController controller = TextEditingController();

  final int totalPageNo;
  final int currentNo;

  JumpPageDialog({Key? key, required this.totalPageNo, required this.currentNo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('jumpPageTo'.tr),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
      content: TextField(
        controller: controller,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: '${'range'.tr}: 1 - $totalPageNo, ${'current'.tr}: $currentNo',
        ),
        onSubmitted: (_) => backRoute(result: controller.text.isEmpty ? null : int.parse(controller.text) - 1),
      ),
      actions: [
        TextButton(
          child: Text('OK'.tr),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              backRoute(result: int.parse(controller.text) - 1);
            }
          },
        ),
      ],
    );
  }
}
