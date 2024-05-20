import 'package:animate_do/animate_do.dart';
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
import '../../../../utils/text_input_formatter.dart';
import '../../../../widget/loading_state_indicator.dart';

class TagSetsPage extends StatelessWidget {
  final TagSetsLogic logic = Get.put<TagSetsLogic>(TagSetsLogic());
  final TagSetsState state = Get.find<TagSetsLogic>().state;

  TagSetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: GetBuilder<TagSetsLogic>(
        id: TagSetsLogic.titleId,
        builder: (_) => Text(state.tagSets.isEmpty ? 'myTags'.tr : state.tagSets.firstWhere((t) => t.number == state.currentTagSetNo).name),
      ),
      actions: [
        _buildTagSetColor(context),
        _buildTagSetSwitcher(),
      ],
    );
  }

  GetBuilder<TagSetsLogic> _buildTagSetColor(BuildContext context) {
    return GetBuilder<TagSetsLogic>(
      id: TagSetsLogic.tagSetId,
      builder: (_) => LoadingStateIndicator(
        loadingState: state.loadingState,
        idleWidget: const SizedBox(),
        loadingWidget: const SizedBox(),
        errorWidgetSameWithIdle: true,
        successWidgetBuilder: () => IconButton(
          icon: Icon(
            Icons.circle,
            color: state.currentTagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor,
          ),
          onPressed: () async {
            dynamic result = await showDialog(
              context: context,
              builder: (context) => _ColorSettingDialog(initialColor: state.currentTagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor),
            );

            if (result == null) {
              return;
            }

            if (result == 'default') {
              logic.handleUpdateTagSetColor(null);
            }

            if (result is Color) {
              logic.handleUpdateTagSetColor(result);
            }
          },
        ),
      ),
    );
  }

  GetBuilder<TagSetsLogic> _buildTagSetSwitcher() {
    return GetBuilder<TagSetsLogic>(
      id: TagSetsLogic.titleId,
      builder: (_) => PopupMenuButton<int>(
        initialValue: state.currentTagSetNo,
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (state.currentTagSetNo == value) {
            return;
          }
          state.currentTagSetNo = value;
          logic.getCurrentTagSet();
        },
        itemBuilder: (_) => state.tagSets
            .map(
              (t) => PopupMenuItem<int>(value: t.number, child: Center(child: Text(t.name))),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return GetBuilder<TagSetsLogic>(
      id: TagSetsLogic.bodyId,
      builder: (_) {
        return LoadingStateIndicator(
          loadingState: state.loadingState,
          errorTapCallback: logic.getCurrentTagSet,
          successWidgetBuilder: () => EHWheelSpeedController(
            controller: state.scrollController,
            child: SafeArea(
              child: ListView.builder(
                itemExtent: 64,
                cacheExtent: 3000,
                itemCount: state.tags.length,
                controller: state.scrollController,
                itemBuilder: (_, int index) => GetBuilder<TagSetsLogic>(
                  id: '${TagSetsLogic.tagId}::${state.tags[index].tagId}',
                  builder: (_) => LoadingStateIndicator(
                    loadingState: state.updateTagState,
                    idleWidget: FadeIn(
                      child: _Tag(
                        tag: state.tags[index],
                        tagSetBackgroundColor: state.currentTagSetBackgroundColor,
                        onTap: () => logic.showBottomSheet(index, context),
                        onLongPress: () => newSearch('${state.tags[index].tagData.namespace}:${state.tags[index].tagData.key}', true),
                        onColorUpdated: (v) => logic.handleUpdateTagColor(index, v),
                        onWeightUpdated: (v) => logic.handleUpdateTagWeight(index, v),
                        onStatusUpdated: (v) => logic.handleUpdateTagStatus(index, v),
                      ),
                    ),
                    errorWidgetSameWithIdle: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  final WatchedTag tag;
  final Color? tagSetBackgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Color?> onColorUpdated;
  final ValueChanged<String> onWeightUpdated;
  final ValueChanged<TagSetStatus> onStatusUpdated;

  const _Tag({
    Key? key,
    required this.tag,
    this.tagSetBackgroundColor,
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
            Get.focusScope?.unfocus();
            onTap?.call();
          },
          onLongPress: onLongPress,
          leading: _buildLeadingIcon(context),
          title: Text(tag.tagData.translatedNamespace == null
              ? '${tag.tagData.namespace}:${tag.tagData.key}'
              : '${tag.tagData.translatedNamespace}:${tag.tagData.tagName}'),
          subtitle: tag.tagData.translatedNamespace == null ? null : Text('${tag.tagData.namespace}:${tag.tagData.key}'),
          trailing: _buildWeight(),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    return IconButton(
      icon: Icon(
        tag.watched
            ? Icons.favorite
            : tag.hidden
                ? Icons.not_interested
                : Icons.question_mark,
        color: tag.backgroundColor ?? tagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor,
      ),
      onPressed: () async {
        dynamic result = await showDialog(
          context: context,
          builder: (context) => _ColorSettingDialog(initialColor: tag.backgroundColor ?? tagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor),
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
        controller: TextEditingController(text: tag.weight.toString()),
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(isDense: true),
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
          IntRangeTextInputFormatter(minValue: -99, maxValue: 99),
        ],
        onSubmitted: onWeightUpdated,
      ),
    );
  }
}

enum TagSetStatus { watched, hidden, nope }

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
