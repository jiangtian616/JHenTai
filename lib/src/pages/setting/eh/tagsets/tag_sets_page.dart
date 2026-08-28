import 'package:flutter/rendering.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_logic.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_state.dart';

import '../../../../utils/route_util.dart';
import '../../../../utils/text_input_formatter.dart';
import '../../../../widget/eh_wheel_speed_controller.dart';
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
        id: TagSetsLogic.searchId,
        builder: (_) => state.searchMode
            ? TextField(
                controller: state.searchController,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'search'.tr,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: logic.updateSearchKeyword,
              )
            : GetBuilder<TagSetsLogic>(
                id: TagSetsLogic.titleId,
                builder: (_) => Text(state.tagSets.isEmpty ? 'myTags'.tr : state.tagSets.firstWhere((t) => t.number == state.currentTagSetNo).name),
              ),
      ),
      actions: [
        GetBuilder<TagSetsLogic>(
          id: TagSetsLogic.searchId,
          builder: (_) => IconButton(
            icon: Icon(state.searchMode ? Icons.close : Icons.search),
            onPressed: state.searchMode ? logic.exitSearchMode : logic.enterSearchMode,
          ),
        ),
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
        idleWidgetBuilder: () => const SizedBox(),
        loadingWidgetBuilder: () => const SizedBox(),
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
          state.searchKeyword = '';
          state.searchController.clear();
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
              child: Column(
                children: [
                  if (state.searchMode && state.searchKeyword.isNotEmpty) _buildAutoCompleteSuggestions(context),
                  if (state.searchMode && state.searchKeyword.isNotEmpty && logic.filteredTags.isEmpty)
                    Expanded(child: Center(child: Text('noData'.tr)))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemExtent: 64,
                        scrollCacheExtent: ScrollCacheExtent.pixels(3000),
                        itemCount: logic.filteredTags.length,
                        controller: state.scrollController,
                        itemBuilder: (_, int displayIndex) {
                          WatchedTag tag = logic.filteredTags[displayIndex];
                          return GetBuilder<TagSetsLogic>(
                            id: '${TagSetsLogic.tagId}::${tag.tagId}',
                            // Look up the tag inside the builder: _updateTag replaces
                            // the object in state.tags, and a stale closure here would
                            // keep rendering the pre-update tag.
                            builder: (_) {
                              int index = state.tags.indexWhere((t) => t.tagId == tag.tagId);
                              if (index == -1) {
                                return const SizedBox();
                              }
                              return LoadingStateIndicator(
                                loadingState: state.updateTagState,
                                idleWidgetBuilder: () => FadeIn(
                                  child: _Tag(
                                    tag: state.tags[index],
                                    tagSetBackgroundColor: state.currentTagSetBackgroundColor,
                                    onLongPress: (position) => logic.showBottomSheet(index, context, position: position),
                                    onSecondaryTap: (position) => logic.showBottomSheet(index, context, position: position),
                                    onColorUpdated: (v) => logic.handleUpdateTagColor(index, v),
                                    onWeightUpdated: (v) => logic.handleUpdateTagWeight(index, v),
                                    onStatusUpdated: (v) => logic.handleUpdateTagStatus(index, v),
                                  ),
                                ),
                                errorWidgetSameWithIdle: true,
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoCompleteSuggestions(BuildContext context) {
    List<WatchedTag> suggestions = logic.autoCompleteSuggestions;
    if (suggestions.isEmpty) {
      return const SizedBox();
    }

    return Material(
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 64.0 * 8),
        child: ListView.builder(
          shrinkWrap: true,
          primary: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: suggestions.length,
          itemBuilder: (_, int index) {
            WatchedTag tag = suggestions[index];
            return InkWell(
              onTap: () => logic.applySuggestion(tag),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.subdirectory_arrow_left, size: 18, color: UIConfig.tagSetsPageIconDefaultColor(context)),
                title: Text(
                  tag.tagData.translatedNamespace == null
                      ? '${tag.tagData.namespace}:${tag.tagData.key}'
                      : '${tag.tagData.translatedNamespace}:${tag.tagData.tagName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: tag.tagData.translatedNamespace == null ? null : Text('${tag.tagData.namespace}:${tag.tagData.key}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final WatchedTag tag;
  final Color? tagSetBackgroundColor;
  final void Function(Offset position)? onLongPress;
  final void Function(Offset position)? onSecondaryTap;
  final ValueChanged<Color?> onColorUpdated;
  final ValueChanged<String> onWeightUpdated;
  final ValueChanged<TagSetStatus> onStatusUpdated;

  const _Tag({
    Key? key,
    required this.tag,
    this.tagSetBackgroundColor,
    this.onLongPress,
    this.onSecondaryTap,
    required this.onColorUpdated,
    required this.onWeightUpdated,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPressStart: onLongPress == null ? null : (details) => onLongPress!(details.globalPosition),
        onSecondaryTapDown: onSecondaryTap == null ? null : (details) => onSecondaryTap!(details.globalPosition),
        child: ListTile(
          dense: true,
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
