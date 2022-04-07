import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/home/tab_view/gallerys/gallerys_view_logic.dart';
import 'package:jhentai/src/utils/route_util.dart';

class JumpPageDialog extends StatelessWidget {
  final GallerysViewLogic logic = Get.find();
  final TextEditingController controller = TextEditingController();

  JumpPageDialog({Key? key}) : super(key: key);

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
          labelText:
              '${'range'.tr}: 1 - ${logic.state.pageCount[logic.tabController.index]}, ${'current'.tr}: ${logic.state.nextPageIndexToLoad[logic.tabController.index]}',
        ),
      ),
      actions: [
        TextButton(
          child: Text('OK'.tr),
          onPressed: () {
            back();
            logic.handleJumpPage(int.parse(controller.text) - 1);
          },
        ),
      ],
    );
  }
}
