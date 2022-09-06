import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/ui_config.dart';

class EHGroupNameSelector extends StatefulWidget {
  final String? currentGroup;
  final List<String> candidates;
  final ValueChanged<String>? listener;

  const EHGroupNameSelector({Key? key, this.currentGroup, required this.candidates, this.listener}) : super(key: key);

  @override
  State<EHGroupNameSelector> createState() => _EHGroupNameSelectorState();
}

class _EHGroupNameSelectorState extends State<EHGroupNameSelector> {
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    if (widget.listener != null) {
      textEditingController.addListener(() {
        widget.listener!.call(textEditingController.text);
      });
    }

    if (widget.currentGroup != null) {
      textEditingController.text = widget.currentGroup!;
    }

    super.initState();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: UIConfig.groupSelectorHeight,
      width: UIConfig.groupSelectorWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.candidates.isNotEmpty) _buildChips(),
          _buildTextField(),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: UIConfig.groupSelectorChipsHeight,
      child: Center(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: widget.candidates.length,
          itemBuilder: _chipBuilder,
        ),
      ),
    );
  }

  Widget _chipBuilder(_, int index) {
    return ChoiceChip(
      label: Text(widget.candidates[index]),
      labelStyle: const TextStyle(fontSize: UIConfig.groupSelectorChipTextSize, height: 1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 3),
      selected: textEditingController.value.text == widget.candidates[index],
      onSelected: (bool value) {
        setState(() => textEditingController.value = TextEditingValue(text: widget.candidates[index]));
      },
      side: BorderSide.none,
      backgroundColor: UIConfig.groupSelectorChipColor,
    ).marginOnly(right: 4);
  }

  Widget _buildTextField() {
    return Center(
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          alignLabelWithHint: true,
          labelText: 'groupName'.tr,
          labelStyle: const TextStyle(fontSize: UIConfig.groupSelectorTextFieldLabelTextSize),
        ),
        style: const TextStyle(fontSize: UIConfig.groupSelectorTextFieldTextSize),
        controller: textEditingController,
      ),
    );
  }
}
