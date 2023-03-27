import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

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
    super.dispose();
    textEditingController.dispose();
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
          _buildTextField().marginOnly(left: 4),
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
          itemBuilder: (context, index) => _chipBuilder(context, index).marginOnly(right: 4),
        ),
      ),
    );
  }

  Widget _chipBuilder(_, int index) {
    return GroupChip(
      text: widget.candidates[index],
      selected: textEditingController.value.text == widget.candidates[index],
      onTap: () {
        setState(() => textEditingController.text = widget.candidates[index]);
      },
    );
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

class GroupChip extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const GroupChip({Key? key, required this.text, required this.selected, this.onTap}) : super(key: key);

  @override
  State<GroupChip> createState() => _GroupChipState();
}

class _GroupChipState extends State<GroupChip> with AnimationMixin {
  bool _selected = false;

  late Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();

    _selected = widget.selected;
    if (_selected) {
      controller.forward(from: 1);
    }
  }

  @override
  void didUpdateWidget(covariant GroupChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _selected = widget.selected;
      if (_selected) {
        controller.play(duration: const Duration(milliseconds: 200));
      } else {
        controller.playReverse(duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          height: 26,
          decoration: BoxDecoration(
            color: _selected ? UIConfig.groupSelectorSelectedChipColor(context) : UIConfig.groupSelectorChipColor(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                heightFactor: animation.value,
                widthFactor: animation.value,
                child: Transform.scale(scale: animation.value, child: Icon(Icons.check, size: 12, color: UIConfig.groupSelectorTextColor(context))),
              ).marginOnly(right: animation.value),
              Text(
                widget.text,
                style: TextStyle(fontSize: UIConfig.groupSelectorChipTextSize, height: 1, color: UIConfig.groupSelectorTextColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
