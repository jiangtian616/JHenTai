import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_logic.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_state.dart';
import 'package:jhentai/src/utils/search_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../../utils/route_util.dart';
import '../../../../widget/loading_state_indicator.dart';

class TagSetsPage extends StatelessWidget {
  final TagSetsLogic logic = Get.put<TagSetsLogic>(TagSetsLogic());
  final TagSetsState state = Get.find<TagSetsLogic>().state;

  TagSetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: GetBuilder<TagSetsLogic>(
        id: TagSetsLogic.bodyId,
        builder: (_) {
          if (state.loadingState != LoadingState.success) {
            return LoadingStateIndicator(
              loadingState: state.loadingState,
              errorTapCallback: logic.getTagSet,
            );
          }

          return EHWheelSpeedController(
            controller: state.scrollController,
            child: SafeArea(
              child: ListView.builder(
                itemExtent: 64,
                cacheExtent: 3000,
                itemCount: state.tagSets.length,
                controller: state.scrollController,
                itemBuilder: (_, int index) => GetBuilder<TagSetsLogic>(
                  id: '${TagSetsLogic.tagId}::${state.tagSets[index].tagId}',
                  builder: (_) => LoadingStateIndicator(
                    loadingState: state.updateTagState,
                    idleWidget: FadeIn(
                      child: _Tag(
                        tagSet: state.tagSets[index],
                        onTap: () => logic.showBottomSheet(index, context),
                        onLongPress: () => newSearch('${state.tagSets[index].tagData.namespace}:${state.tagSets[index].tagData.key}', true),
                        onColorUpdated: (v) => logic.handleUpdateColor(index, v),
                        onWeightUpdated: (v) => logic.handleUpdateWeight(index, v),
                        onStatusUpdated: (v) => logic.handleUpdateStatus(index, v),
                      ),
                    ),
                    errorWidgetSameWithIdle: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      centerTitle: true,
      title: GetBuilder<TagSetsLogic>(
        id: TagSetsLogic.titleId,
        builder: (_) => Text(state.tagSetNames.isEmpty ? 'myTags'.tr : state.tagSetNames[state.currentTagSetIndex]),
      ),
      actions: [
        GetBuilder<TagSetsLogic>(
          id: TagSetsLogic.titleId,
          builder: (_) => PopupMenuButton<int>(
            initialValue: state.currentTagSetIndex,
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (state.currentTagSetIndex == value) {
                return;
              }
              state.currentTagSetIndex = value;
              logic.getTagSet();
            },
            itemBuilder: (_) => state.tagSetNames
                .mapIndexed(
                  (index, element) => PopupMenuItem<int>(value: index, child: Center(child: Text(element))),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final TagSet tagSet;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Color?> onColorUpdated;
  final ValueChanged<String> onWeightUpdated;
  final ValueChanged<TagSetStatus> onStatusUpdated;

  const _Tag({
    Key? key,
    required this.tagSet,
    this.onTap,
    this.onLongPress,
    required this.onColorUpdated,
    required this.onWeightUpdated,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onSecondaryTap: onTap,
        child: ListTile(
          dense: true,
          onTap: () {
            Get.focusScope?.unfocus;
            onTap?.call();
          },
          onLongPress: onLongPress,
          leading: _buildLeadingIcon(context),
          title: Text(tagSet.tagData.translatedNamespace == null
              ? '${tagSet.tagData.namespace}:${tagSet.tagData.key}'
              : '${tagSet.tagData.translatedNamespace}:${tagSet.tagData.tagName}'),
          subtitle: tagSet.tagData.translatedNamespace == null ? null : Text('${tagSet.tagData.namespace}:${tagSet.tagData.key}'),
          trailing: _buildWeight(),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    return IconButton(
      icon: Icon(
        tagSet.watched
            ? Icons.favorite
            : tagSet.hidden
                ? Icons.not_interested
                : Icons.question_mark,
        color: tagSet.backgroundColor ?? UIConfig.tagSetsPageIconDefaultColor(context),
      ),
      onPressed: () async {
        dynamic result = await showDialog(
          context: context,
          builder: (context) => _ColorSettingDialog(initialColor: tagSet.backgroundColor ?? UIConfig.tagSetsPageIconDefaultColor(context)),
        );

        if (result == null) {
          return;
        }

        if (result == 'default') {
          onColorUpdated(null);
        }

        if (result is Color) {
          onColorUpdated(result);
        }
      },
    );
  }

  Widget _buildWeight() {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: TextEditingController(text: tagSet.weight.toString()),
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(isDense: true),
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
          NumberRangeTextInputFormatter(minValue: -99, maxValue: 99),
        ],
        onSubmitted: onWeightUpdated,
      ),
    );
  }
}

enum TagSetStatus { watched, hidden, nope }

class NumberRangeTextInputFormatter extends TextInputFormatter {
  double? minValue;
  double? maxValue;

  NumberRangeTextInputFormatter({this.minValue, this.maxValue});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || (minValue != null && minValue! < 0 && newValue.text == '-')) {
      return newValue;
    }

    double newNum = double.tryParse(newValue.text) ?? -100;

    if (minValue != null && newNum < minValue!) {
      return oldValue;
    }
    if (maxValue != null && newNum > maxValue!) {
      return oldValue;
    }

    return newValue;
  }
}

class _ColorSettingDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorSettingDialog({Key? key, required this.initialColor}) : super(key: key);

  @override
  State<_ColorSettingDialog> createState() => _ColorSettingDialogState();
}

class _ColorSettingDialogState extends State<_ColorSettingDialog> {
  late Color selectedColor;

  @override
  void initState() {
    selectedColor = widget.initialColor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ColorPicker(
            color: selectedColor,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: true,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
            pickerTypeLabels: <ColorPickerType, String>{
              ColorPickerType.both: 'preset'.tr,
              ColorPickerType.wheel: 'custom'.tr,
            },
            enableTonalPalette: true,
            showColorCode: true,
            colorCodeHasColor: true,
            colorCodeTextStyle: const TextStyle(fontSize: 18),
            width: 36,
            height: 36,
            columnSpacing: 16,
            onColorChanged: (Color color) {
              selectedColor = color;
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(child: Text('cancel'.tr), onPressed: backRoute),
            TextButton(
              child: Text('reset'.tr),
              onPressed: () {
                backRoute(result: 'default');
              },
            ),
            TextButton(
              child: Text('OK'.tr),
              onPressed: () {
                backRoute(result: selectedColor);
              },
            ),
          ],
        ),
      ],
    );
  }
}
