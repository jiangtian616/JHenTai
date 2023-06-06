import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../config/ui_config.dart';
import '../../../../setting/my_tags_setting.dart';
import '../../../../setting/style_setting.dart';
import '../../../../utils/toast_util.dart';
import 'local_tag_sets_page_logic.dart';
import 'local_tag_sets_page_state.dart';

class LocalTagSetsPage extends StatelessWidget {
  final LocalTagSetsLogic logic = Get.put<LocalTagSetsLogic>(LocalTagSetsLogic());
  final LocalTagSetsState state = Get.find<LocalTagSetsLogic>().state;

  LocalTagSetsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('localTags'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () => toast('localTagsHint2'.tr, isShort: false),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildBody() {
    return GetBuilder<LocalTagSetsLogic>(
      id: logic.bodyId,
      builder: (_) => EHWheelSpeedController(
        controller: state.scrollController,
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: MyTagsSetting.localTagSets.length,
            controller: state.scrollController,
            itemBuilder: (_, int index) => ListTile(
              dense: true,
              title: Text(MyTagsSetting.localTagSets[index].translatedNamespace == null
                  ? '${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'
                  : '${MyTagsSetting.localTagSets[index].translatedNamespace}:${MyTagsSetting.localTagSets[index].tagName}'),
              subtitle: MyTagsSetting.localTagSets[index].translatedNamespace == null ? null : Text('${MyTagsSetting.localTagSets[index].namespace}:${MyTagsSetting.localTagSets[index].key}'),
              onTap: () => logic.handleDeleteLocalTag(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        showDialog(
          context: context,
          useRootNavigator: false,
          builder: (_) => _buildDialog(context),
        ).then((_) => logic.updateSafely([logic.bodyId]));
      },
    );
  }

  Dialog _buildDialog(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(title: Text('addLocalTags'.tr)),
        body: Column(
          children: [
            GetBuilder<LocalTagSetsLogic>(
              id: logic.searchFieldId,
              builder: (_) => TextField(
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 15),
                onChanged: (text) {
                  state.keyword = text;
                  logic.waitAndSearchTags();
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'search'.tr,
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(child: const Icon(Icons.search), onTap: logic.waitAndSearchTags),
                  ),
                  prefixIconConstraints: BoxConstraints(
                    minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
                    minWidth: 52,
                  ),
                  suffixIcon: GetBuilder<LocalTagSetsLogic>(
                    id: logic.searchLoadingStateId,
                    builder: (_) => state.searchLoadingState == LoadingState.loading ? const CupertinoActivityIndicator() : const SizedBox(),
                  ),
                  suffixIconConstraints: BoxConstraints(
                    minHeight: StyleSetting.isInDesktopLayout ? UIConfig.desktopSearchBarHeight : UIConfig.mobileV2SearchBarHeight,
                    minWidth: 40,
                  ),
                ),
              ),
            ),
            GetBuilder<LocalTagSetsLogic>(
              id: logic.searchLoadingStateId,
              builder: (_) => state.searchLoadingState == LoadingState.noData ? Text('noData'.tr) : const SizedBox(),
            ),
            Expanded(
              child: GetBuilder<LocalTagSetsLogic>(
                id: logic.tagsId,
                builder: (_) => ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: state.tags.length,
                  itemBuilder: (_, int index) => GetBuilder<LocalTagSetsLogic>(
                    id: '${logic.tagsId}::${state.tags[index].namespace}::${state.tags[index].key}',
                    builder: (_) => ListTile(
                      title: RichText(
                        text: highlightKeyword(
                          context,
                          state.tags[index].translatedNamespace == null
                              ? '${state.tags[index].namespace}:${state.tags[index].key}'
                              : '${state.tags[index].translatedNamespace}:${state.tags[index].tagName}',
                          state.keyword ?? '',
                          false,
                        ),
                      ),
                      subtitle: state.tags[index].translatedNamespace == null
                          ? null
                          : RichText(
                              text: highlightKeyword(
                                context,
                                '${state.tags[index].namespace}:${state.tags[index].key}',
                                state.keyword ?? '',
                                true,
                              ),
                            ),
                      trailing: MyTagsSetting.containLocalTag(state.tags[index]) ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.add, color: Colors.grey),
                      dense: true,
                      minLeadingWidth: 20,
                      onTap: () => logic.toggleLocalTag(state.tags[index]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan highlightKeyword(BuildContext context, String rawText, String currentKeyword, bool isSubTitle) {
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = currentKeyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(
              fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
              color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
            ),
          ),
        );
      }

      children.add(
        TextSpan(
          text: currentKeyword,
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
            color: UIConfig.searchPageSuggestionHighlightColor,
          ),
        ),
      );

      indexHandling = index + currentKeyword.length;
    }

    if (rawText.length > indexHandling) {
      children.add(
        TextSpan(
          text: rawText.substring(indexHandling, rawText.length),
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchPageSuggestionSubTitleTextSize : UIConfig.searchPageSuggestionTitleTextSize,
            color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
          ),
        ),
      );
    }

    return TextSpan(children: children);
  }
}
