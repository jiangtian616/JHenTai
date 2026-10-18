import 'package:flutter/rendering.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_logic.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page_state.dart';

import '../../../../widget/eh_tag_edit_dialog.dart';
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
          tooltip: 'tagSetDefaultColor'.tr,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.palette_outlined),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: state.currentTagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {
            dynamic result = await showDialog(
              context: context,
              builder: (context) => EHTagColorSettingDialog(initialColor: state.currentTagSetBackgroundColor ?? UIConfig.ehWatchedTagDefaultBackGroundColor),
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
    bool useDialog = !styleSetting.isInMobileLayout;

    Widget dialog = EHTagEditDialog(
      tag: tag,
      tagSetBackgroundColor: state.currentTagSetBackgroundColor,
      showSearchButton: true,
      isDialog: useDialog,
      onConfirm: (_, WatchedTag newTag) {
        int index = logic.state.tags.indexWhere((t) => t.tagId == newTag.tagId);
        if (index != -1) {
          logic.handleUpdateTag(index, newTag);
        }
      },
      onDelete: (WatchedTag deletedTag) {
        int index = logic.state.tags.indexWhere((t) => t.tagId == deletedTag.tagId);
        if (index != -1) {
          logic.deleteTag(index);
        }
      },
    );
    if (useDialog) {
      // showDialog doesn't provide a Material ancestor; the editor content needs one.
      showDialog(context: context, barrierDismissible: true, builder: (_) => Dialog(child: dialog));
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
  final GestureTapCallback? onTap;

  const _Tag({
    Key? key,
    required this.tag,
    this.tagSetBackgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color defaultColor = tag.hidden || tag.weight < 0 ? UIConfig.ehHiddenTagDefaultBackGroundColor : UIConfig.ehWatchedTagDefaultBackGroundColor;
    return Center(
      child: ListTile(
        onTap: onTap,
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
    );
  }
}

