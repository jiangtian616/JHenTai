import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/route_util.dart';

enum EHGroupNameDialogType { update, insert }

class EHGroupNameDialog extends StatefulWidget {
  final EHGroupNameDialogType type;
  final String? currentGroup;
  final List<String> candidates;

  const EHGroupNameDialog({Key? key, required this.type, this.currentGroup, required this.candidates}) : super(key: key);

  @override
  State<EHGroupNameDialog> createState() => _EHGroupNameDialogState();
}

class _EHGroupNameDialogState extends State<EHGroupNameDialog> {
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    textEditingController.value = TextEditingValue(text: widget.currentGroup ?? 'default'.tr);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text(widget.type == EHGroupNameDialogType.update ? 'changeGroup'.tr : 'chooseGroup'.tr)),
      contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.candidates.isNotEmpty) SizedBox(height: 50, width: 230, child: _buildChips()),
          SizedBox(height: 50, width: 230, child: _buildTextField()),
        ],
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(onPressed: () => backRoute(result: textEditingController.value.text), child: Text('OK'.tr)),
      ],
    );
  }

  Widget _buildChips() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.candidates.length,
      itemBuilder: (_, int index) => GestureDetector(
        onTap: () => setState(() {
          textEditingController.value = TextEditingValue(text: widget.candidates[index]);
        }),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 22,
              color: Get.isDarkMode ? Colors.grey.shade600 : Colors.grey.shade200,
              child: Center(
                child: Text(widget.candidates[index], style: const TextStyle(fontSize: 11, height: 1)),
              ).marginSymmetric(horizontal: 8),
            ),
          ).marginOnly(right: 6),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      decoration: InputDecoration(isDense: true, alignLabelWithHint: true, labelText: 'groupName'.tr, labelStyle: const TextStyle(fontSize: 12)),
      controller: textEditingController,
    );
  }
}
