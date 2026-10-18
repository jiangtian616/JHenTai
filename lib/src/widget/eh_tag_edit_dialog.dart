import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../utils/search_util.dart';

enum TagSetStatus { watched, hidden, nope }

typedef OnTagEdited = void Function(WatchedTag oldTag, WatchedTag newTag);
typedef OnTagDeleted = void Function(WatchedTag tag);

/// Detail editor for a single tag: status / weight / color / delete, all in one
/// panel. Changes are staged locally and committed via [onConfirm].
/// Rendered as a centered dialog on desktop and a bottom sheet on mobile.
class EHTagEditDialog extends StatefulWidget {
  final WatchedTag tag;
  final Color? tagSetBackgroundColor;
  final OnTagEdited? onConfirm;
  final OnTagDeleted? onDelete;
  final bool showSearchButton;
  final bool isDialog;

  const EHTagEditDialog({
    Key? key,
    required this.tag,
    this.tagSetBackgroundColor,
    this.onConfirm,
    this.onDelete,
    this.showSearchButton = false,
    required this.isDialog,
  }) : super(key: key);

  @override
  State<EHTagEditDialog> createState() => _EHTagEditDialogState();
}

class _EHTagEditDialogState extends State<EHTagEditDialog> {
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

  late WatchedTag tag;
  late TagSetStatus status;
  late int weight;
  late Color? color;

  @override
  void initState() {
    super.initState();
    tag = widget.tag;
    status = tag.watched
        ? TagSetStatus.watched
        : tag.hidden
            ? TagSetStatus.hidden
            : TagSetStatus.nope;
    weight = tag.weight;
    color = tag.backgroundColor;
  }

  bool get _hasChanges {
    return status != _originalStatus || weight != widget.tag.weight || color != widget.tag.backgroundColor;
  }

  TagSetStatus get _originalStatus => widget.tag.watched
      ? TagSetStatus.watched
      : widget.tag.hidden
          ? TagSetStatus.hidden
          : TagSetStatus.nope;

  @override
  Widget build(BuildContext context) {
    Color defaultColor = status == TagSetStatus.hidden || weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor;
    Color currentColor = color ?? widget.tagSetBackgroundColor ?? defaultColor;

    // Dialog renders with no top inset; mobile's bottom sheet gets its
    // spacing from the drag handle area.
    return SizedBox(
      width: 400,
      child: Padding(
        padding: widget.isDialog ? const EdgeInsets.fromLTRB(24, 20, 24, 24) : const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.tagData.translatedNamespace == null ? '${tag.tagData.namespace}:${tag.tagData.key}' : '${tag.tagData.translatedNamespace}:${tag.tagData.tagName}',
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
                if (widget.showSearchButton)
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: 'search'.tr,
                    onPressed: () {
                      backRoute();
                      newSearch(keyword: '${tag.tagData.namespace}:${tag.tagData.key}');
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusSection(context),
            const SizedBox(height: 12),
            _buildWeightSection(context),
            const SizedBox(height: 12),
            _buildColorSection(context, currentColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: UIConfig.alertColor(context)),
                    label: Text('delete'.tr, style: TextStyle(color: UIConfig.alertColor(context))),
                    onPressed: _delete,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('OK'.tr),
                    onPressed: _hasChanges ? _confirm : null,
                  ),
                ),
              ],
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
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: TagSetStatus.watched, label: Text('watched'.tr), icon: const Icon(Icons.favorite, size: 16)),
            ButtonSegment(value: TagSetStatus.hidden, label: Text('hidden'.tr), icon: const Icon(Icons.not_interested, size: 16)),
            ButtonSegment(value: TagSetStatus.nope, label: Text('nope'.tr), icon: const Icon(Icons.question_mark, size: 16)),
          ],
          selected: {status},
          onSelectionChanged: (Set<TagSetStatus> selection) => setState(() => status = selection.first),
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
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showWeightInputDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('$weight', style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _updateWeight(weight + 1)),
          ],
        ),
      ],
    );
  }

  void _showWeightInputDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _WeightInputDialog(initialWeight: weight)).then((result) {
      if (result is int) {
        _updateWeight(result);
      }
    });
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
              _colorChip(
                  context,
                  widget.tagSetBackgroundColor ??
                      (status == TagSetStatus.hidden || weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor),
                  null),
              ...presetColors.map((preset) => _colorChip(context, preset, preset)),
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
                builder: (context) => EHTagColorSettingDialog(initialColor: currentColor),
              );
              if (result is Color) {
                setState(() => color = result);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _colorChip(BuildContext context, Color chipColor, Color? value) {
    bool selected = color == value && (value != null || color == null);
    return GestureDetector(
      onTap: () => setState(() => color = value),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: chipColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected ? Icon(Icons.check, size: 18, color: ThemeData.estimateBrightnessForColor(chipColor) == Brightness.light ? Colors.black : Colors.white) : null,
      ),
    );
  }

  void _updateWeight(int newWeight) {
    int clamped = newWeight.clamp(-99, 99);
    if (clamped == weight) {
      return;
    }
    setState(() => weight = clamped);
  }

  void _delete() {
    backRoute();
    widget.onDelete?.call(widget.tag);
  }

  /// Changes are staged locally; only report them on confirm.
  void _confirm() {
    WatchedTag newTag = widget.tag.copyWith(
      weight: weight,
      watched: status == TagSetStatus.watched,
      hidden: status == TagSetStatus.hidden,
    );
    // copyWith can't clear backgroundColor to null, so assign it explicitly.
    newTag.backgroundColor = color;
    backRoute();
    widget.onConfirm?.call(widget.tag, newTag);
  }
}

class _WeightInputDialog extends StatefulWidget {
  final int initialWeight;

  const _WeightInputDialog({Key? key, required this.initialWeight}) : super(key: key);

  @override
  State<_WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends State<_WeightInputDialog> {
  late final TextEditingController controller;
  String? errorText;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: '${widget.initialWeight}');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool _isValid() {
    int? parsed = int.tryParse(controller.text);
    return parsed != null && parsed >= -99 && parsed <= 99;
  }

  void _submit() {
    if (_isValid()) {
      Navigator.of(context).pop(int.parse(controller.text));
    } else {
      setState(() => errorText = 'invalid'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('weight'.tr),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}'))],
        decoration: InputDecoration(
          errorText: errorText,
          hintText: '-99 ~ 99',
        ),
        onChanged: (value) {
          int? parsed = int.tryParse(value);
          setState(() => errorText = parsed == null || parsed < -99 || parsed > 99 ? 'invalid'.tr : null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(child: Text('cancel'.tr), onPressed: () => Navigator.of(context).pop()),
        TextButton(child: Text('OK'.tr), onPressed: _submit),
      ],
    );
  }
}

class EHTagColorSettingDialog extends StatefulWidget {
  final Color initialColor;

  const EHTagColorSettingDialog({Key? key, required this.initialColor}) : super(key: key);

  @override
  State<EHTagColorSettingDialog> createState() => _EHTagColorSettingDialogState();
}

class _EHTagColorSettingDialogState extends State<EHTagColorSettingDialog> {
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
