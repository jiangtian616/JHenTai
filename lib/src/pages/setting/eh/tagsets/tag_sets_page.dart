import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_logic.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_state.dart';

import '../../../../widget/loading_state_indicator.dart';

class TagSetsPage extends StatelessWidget {
  final TagSetsLogic logic = Get.put<TagSetsLogic>(TagSetsLogic());
  final TagSetsState state = Get.find<TagSetsLogic>().state;

  TagSetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 1,
        title: GetBuilder<TagSetsLogic>(
          id: titleId,
          builder: (logic) {
            return Text(
              state.tagSetNames.isEmpty ? 'myTags'.tr : state.tagSetNames[state.currentTagSetIndex],
            );
          },
        ),
        actions: [
          GetBuilder<TagSetsLogic>(
            id: 'titleId',
            builder: (logic) {
              return PopupMenuButton<int>(
                initialValue: state.currentTagSetIndex,
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (state.currentTagSetIndex == value) {
                    return;
                  }
                  state.currentTagSetIndex = value;
                  logic.getTagSet();
                },
                itemBuilder: (BuildContext context) => state.tagSetNames
                    .mapIndexed(
                      (index, element) => PopupMenuItem<int>(
                        value: index,
                        child: Center(child: Text(state.tagSetNames[index])),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: GetBuilder<TagSetsLogic>(
        id: bodyId,
        builder: (logic) {
          if (state.loadingState != LoadingState.idle) {
            return LoadingStateIndicator(
              loadingState: state.loadingState,
              errorTapCallback: logic.getTagSet,
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemCount: state.tagSets.length,
            itemBuilder: (context, index) {
              TagSet tagSet = state.tagSets[index];
              return FadeIn(
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: state.tagSets[index].color,
                    child: GetBuilder<TagSetsLogic>(
                      id: '$updateWeightStateId-${tagSet.tagId}',
                      builder: (logic) {
                        return LoadingStateIndicator(
                          loadingState: state.updateTagState,
                          idleWidget: TextField(
                            controller: TextEditingController(text: state.tagSets[index].weight.toString()),
                            style: Theme.of(context)
                                .textTheme
                                .subtitle1
                                ?.copyWith(color: _tagWeightTextColor(tagSet.color)),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'\d|-')),
                              NumberRangeTextInputFormatter(minValue: -99, maxValue: 99),
                            ],
                            onSubmitted: (value) => logic.handleUpdateWeight(index, value),
                          ),
                        );
                      },
                    ),
                  ),
                  title: GetBuilder<TagSetsLogic>(
                    id: '$deleteStateId-$index',
                    builder: (logic) {
                      return LoadingStateIndicator(
                        loadingState: state.deleteTagState,
                        idleWidget: Text(
                          '${tagSet.tagData.namespace} : ${tagSet.tagData.key}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        errorWidgetSameWithIdle: true,
                      );
                    },
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GetBuilder<TagSetsLogic>(
                          id: '$updateWatchedStateId-${tagSet.tagId}',
                          builder: (logic) {
                            return LoadingStateIndicator(
                              width: 45,
                              loadingState: state.updateTagState,
                              idleWidget: IconButton(
                                onPressed: () => logic.handleTapWatchButton(index),
                                icon: Icon(
                                  Icons.visibility,
                                  color: state.tagSets[index].watched ? Colors.blue : null,
                                ),
                              ),
                              errorWidgetSameWithIdle: true,
                            );
                          },
                        ),
                        GetBuilder<TagSetsLogic>(
                          id: '$updateHiddenStateId-${tagSet.tagId}',
                          builder: (logic) {
                            return LoadingStateIndicator(
                              width: 45,
                              loadingState: state.updateTagState,
                              idleWidget: IconButton(
                                onPressed: () => logic.handleTapHiddenButton(index),
                                icon: Icon(
                                  Icons.visibility_off,
                                  color: state.tagSets[index].hidden ? Colors.red : null,
                                ),
                              ),
                              errorWidgetSameWithIdle: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  onTap: () => logic.showDeleteBottomSheet(index),
                ),
              );
            },
          );
        },
      ).paddingSymmetric(vertical: 16),
    );
  }

  Color _tagWeightTextColor(Color? color) {
    if (color == null) {
      return Colors.white;
    }
    switch (ThemeData.estimateBrightnessForColor(color)) {
      case Brightness.dark:
        return Get.theme.primaryColorLight;
      case Brightness.light:
        return Get.theme.primaryColor;
    }
  }
}

class NumberRangeTextInputFormatter extends TextInputFormatter {
  int? minValue;
  int? maxValue;

  NumberRangeTextInputFormatter({this.minValue, this.maxValue});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || (minValue != null && minValue! < 0 && newValue.text == '-')) {
      return newValue;
    }

    int newNum = int.tryParse(newValue.text) ?? -100;

    if (minValue != null && newNum < minValue!) {
      return oldValue;
    }
    if (maxValue != null && newNum > maxValue!) {
      return oldValue;
    }

    return newValue;
  }
}
