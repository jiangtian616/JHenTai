import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/rendering.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';import 'package:jhentai/src/config/ui_config.dart';
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
                                    onTap: () => _showTagEditDialog(context, state.tags[index]),
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
  void _showTagEditDialog(BuildContext context, WatchedTag tag) {
    bool useDialog = GetPlatform.isDesktop ||
        PlatformDispatcher.instance.views.first.physicalSize.width / PlatformDispatcher.instance.views.first.devicePixelRatio >= 600;

    Widget dialog = _TagEditDialog(tag: tag, tagSetBackgroundColor: state.currentTagSetBackgroundColor);
    if (useDialog) {
      showDialog(context: context, builder: (_) => dialog);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => dialog,
      );
    }
  }
}

class _Tag extends StatelessWidget {
  final WatchedTag tag;
  final Color? tagSetBackgroundColor;
  final void Function(Offset position)? onLongPress;
  final void Function(Offset position)? onSecondaryTap;
  final GestureTapCallback? onTap;

  const _Tag({
    Key? key,
    required this.tag,
    this.tagSetBackgroundColor,
    this.onLongPress,
    this.onSecondaryTap,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color defaultColor = tag.hidden || tag.weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: onLongPress == null ? null : (details) => onLongPress!(details.globalPosition),
        onSecondaryTapDown: onSecondaryTap == null ? null : (details) => onSecondaryTap!(details.globalPosition),
        child: ListTile(
          dense: true,
          leading: Icon(
            tag.watched ? Icons.favorite : tag.hidden ? Icons.not_interested : Icons.question_mark,
            color: tag.backgroundColor ?? tagSetBackgroundColor ?? defaultColor,
          ),
          title: Text(tag.tagData.translatedNamespace == null
              ? '${tag.tagData.namespace}:${tag.tagData.key}'
              : '${tag.tagData.translatedNamespace}:${tag.tagData.tagName}'),
          subtitle: tag.tagData.translatedNamespace == null ? null : Text('${tag.tagData.namespace}:${tag.tagData.key}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text('${tag.weight}', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

enum TagSetStatus { watched, hidden, nope }

/// Detail editor for a single tag: status / weight / color / delete, all in one panel.
/// Rendered as a centered dialog on desktop and a bottom sheet on mobile.
class _TagEditDialog extends StatefulWidget {
  final WatchedTag tag;
  final Color? tagSetBackgroundColor;

  const _TagEditDialog({Key? key, required this.tag, this.tagSetBackgroundColor}) : super(key: key);

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  static const List<Color> presetColors = [
    Color(0xFF3377FF),
    Color(0xFFDF4646),
    Color(0xFFFCB417),
    Color(0xFFDDE500),
    Color(0xFF17B91B),
    Color(0xFF68C9DE),
    Color(0xFF9755F5),
    Color(0xFF9E9E9E),
  ];

  late TagSetsLogic logic;
  late WatchedTag tag;
  late int weight;

  @override
  void initState() {
    super.initState();
    logic = Get.find<TagSetsLogic>();
    tag = widget.tag;
    weight = tag.weight;
  }

  TagSetStatus get status => tag.watched ? TagSetStatus.watched : tag.hidden ? TagSetStatus.hidden : TagSetStatus.nope;

  @override
  Widget build(BuildContext context) {
    Color defaultColor = tag.hidden || weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor;
    Color currentColor = tag.backgroundColor ?? widget.tagSetBackgroundColor ?? defaultColor;

    return SizedBox(
      width: 400,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.tagData.translatedNamespace == null
                            ? '${tag.tagData.namespace}:${tag.tagData.key}'
                            : '${tag.tagData.translatedNamespace}:${tag.tagData.tagName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (tag.tagData.translatedNamespace != null)
                        Text(
                          '${tag.tagData.namespace}:${tag.tagData.key}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: backRoute),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusSection(context),
            const SizedBox(height: 12),
            _buildWeightSection(context),
            const SizedBox(height: 12),
            _buildColorSection(context, currentColor),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(Icons.delete_outline, size: 18, color: UIConfig.alertColor(context)),
              label: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
              onPressed: () => _delete(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('status'.tr, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 4),
        SegmentedButton<TagSetStatus>(
          segments: [
            ButtonSegment(value: TagSetStatus.watched, label: Text('watched'.tr), icon: const Icon(Icons.favorite, size: 16)),
            ButtonSegment(value: TagSetStatus.hidden, label: Text('hidden'.tr), icon: const Icon(Icons.not_interested, size: 16)),
            ButtonSegment(value: TagSetStatus.nope, label: Text('nope'.tr), icon: const Icon(Icons.question_mark, size: 16)),
          ],
          selected: {status},
          onSelectionChanged: (Set<TagSetStatus> selection) => _updateStatus(selection.first),
        ),
      ],
    );
  }

  Widget _buildWeightSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('weight'.tr, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: () => _updateWeight(weight - 1)),
            Expanded(
              child: Center(child: Text('$weight', style: const TextStyle(fontSize: 16))),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _updateWeight(weight + 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSection(BuildContext context, Color currentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('color'.tr, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _colorChip(context, currentColor, widget.tagSetBackgroundColor ?? (tag.hidden || weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor), null),
              ...presetColors.map((color) => _colorChip(context, currentColor, color, color)),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.colorize, size: 16),
            label: Text('custom'.tr),
            onPressed: () async {
              dynamic result = await showDialog(
                context: context,
                builder: (context) => _ColorSettingDialog(initialColor: currentColor),
              );
              if (result is Color) {
                _updateColor(result);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _colorChip(BuildContext context, Color currentColor, Color color, Color? value) {
    bool selected = tag.backgroundColor == value && (value != null || tag.backgroundColor == null);
    return GestureDetector(
      onTap: () => _updateColor(value),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? Icon(Icons.check, size: 18, color: ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Colors.black : Colors.white) : null,
      ),
    );
  }

  int _tagIndex() => logic.state.tags.indexWhere((t) => t.tagId == tag.tagId);

  void _refreshTag() {
    int index = _tagIndex();
    if (index != -1) {
      setState(() => tag = logic.state.tags[index]);
    }
  }

  void _updateStatus(TagSetStatus newStatus) {
    logic.handleUpdateTagStatus(_tagIndex(), newStatus);
    _refreshTag();
  }

  void _updateWeight(int newWeight) {
    int clamped = newWeight.clamp(-99, 99);
    if (clamped == weight) {
      return;
    }
    setState(() => weight = clamped);
    logic.handleUpdateTagWeight(_tagIndex(), clamped.toString());
    _refreshTag();
  }

  void _updateColor(Color? newColor) {
    logic.handleUpdateTagColor(_tagIndex(), newColor);
    _refreshTag();
  }

  void _delete() {
    backRoute();
    logic.deleteTag(_tagIndex());
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
