import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';

class JumpPageDialog extends StatefulWidget {
  final int totalPageNo;
  final int currentNo;

  const JumpPageDialog({Key? key, required this.totalPageNo, required this.currentNo}) : super(key: key);

  @override
  State<JumpPageDialog> createState() => _JumpPageDialogState();
}

class _JumpPageDialogState extends State<JumpPageDialog> {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('jumpPageTo'.tr),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
      content: TextField(
        controller: controller,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: '${'range'.tr}: 1 - ${widget.totalPageNo}, ${'current'.tr}: ${widget.currentNo}',
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
