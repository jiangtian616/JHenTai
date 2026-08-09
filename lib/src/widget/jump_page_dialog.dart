import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

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
      content: EHAppleTextField(
        controller: controller,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        // Keep the text and label readable on the dark glass surface in dark
        // mode (GlassTextField's default gray label disappears against it).
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        placeholderStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: '${'range'.tr}: 1 - ${widget.totalPageNo}, ${'current'.tr}: ${widget.currentNo}',
        ),
        onSubmitted: (_) => backRoute(result: controller.text.isEmpty ? null : int.parse(controller.text) - 1),
      ),
      actions: [
        EHAppleTextButton(
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
