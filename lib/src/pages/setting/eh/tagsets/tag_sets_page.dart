import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_logic.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_state.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

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
                        onLongPress: () => logic.showBottomSheet(index, context),
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
  final VoidCallback? onLongPress;
  final ValueChanged<String> onWeightUpdated;
  final ValueChanged<TagSetStatus> onStatusUpdated;

  const _Tag({
    Key? key,
    required this.tagSet,
    this.onLongPress,
    required this.onWeightUpdated,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListTile(
        dense: true,
        onTap: Get.focusScope?.unfocus,
        onLongPress: onLongPress,
        leading: _TagHeader(watched: tagSet.watched, hidden: tagSet.hidden, onStatusUpdated: onStatusUpdated),
        title: Text(tagSet.tagData.translatedNamespace == null
            ? '${tagSet.tagData.namespace}:${tagSet.tagData.key}'
            : '${tagSet.tagData.translatedNamespace}:${tagSet.tagData.tagName}'),
        subtitle: tagSet.tagData.translatedNamespace == null ? null : Text('${tagSet.tagData.namespace}:${tagSet.tagData.key}'),
        trailing: _TagFooter(weight: tagSet.weight, onWeightUpdated: onWeightUpdated),
      ),
    );
  }
}

class _TagHeader extends StatelessWidget {
  final bool watched;
  final bool hidden;
  final ValueChanged<TagSetStatus> onStatusUpdated;

  const _TagHeader({
    Key? key,
    required this.watched,
    required this.hidden,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TagSetStatus>(
      icon: Icon(_computeIcon(), color: UIConfig.tagSetsPageIconColor),
      initialValue: _computeStatus(),
      onSelected: onStatusUpdated,
      elevation: 4,
      itemBuilder: (_) => [
        PopupMenuItem<TagSetStatus>(
          value: TagSetStatus.watched,
          child: Row(
            children: [
              Icon(Icons.favorite, color: UIConfig.tagSetsPageIconColor),
              const SizedBox(width: 8),
              Text('watched'.tr),
            ],
          ),
        ),
        PopupMenuItem<TagSetStatus>(
          value: TagSetStatus.hidden,
          child: Row(
            children: [
              Icon(Icons.not_interested, color: UIConfig.tagSetsPageIconColor),
              const SizedBox(width: 8),
              Text('hidden'.tr),
            ],
          ),
        ),
        PopupMenuItem<TagSetStatus>(
          value: TagSetStatus.nope,
          child: Row(
            children: [
              Icon(Icons.question_mark, color: UIConfig.tagSetsPageIconColor),
              const SizedBox(width: 8),
              Text('nope'.tr),
            ],
          ),
        ),
      ],
      onCanceled: Get.focusScope?.unfocus,
    );
  }

  IconData _computeIcon() {
    if (watched) {
      return Icons.favorite;
    }

    if (hidden) {
      return Icons.not_interested;
    }

    return Icons.question_mark;
  }

  TagSetStatus _computeStatus() {
    if (watched) {
      return TagSetStatus.watched;
    }

    if (hidden) {
      return TagSetStatus.hidden;
    }

    return TagSetStatus.nope;
  }
}

class _TagFooter extends StatelessWidget {
  final int weight;
  final ValueChanged<String> onWeightUpdated;

  const _TagFooter({Key? key, required this.weight, required this.onWeightUpdated}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: TextEditingController(text: weight.toString()),
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(isDense: true),
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
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
