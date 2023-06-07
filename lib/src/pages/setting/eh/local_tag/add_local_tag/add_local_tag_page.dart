import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../config/ui_config.dart';
import '../../../../../setting/my_tags_setting.dart';
import '../../../../../widget/loading_state_indicator.dart';
import 'add_local_tag_page_logic.dart';
import 'add_local_tag_page_state.dart';

class AddLocalTagPage extends StatelessWidget {
  final AddLocalTagPageLogic logic = Get.put<AddLocalTagPageLogic>(AddLocalTagPageLogic());
  final AddLocalTagPageState state = Get.find<AddLocalTagPageLogic>().state;

  AddLocalTagPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('addLocalTags'.tr)),
      body: Column(
        children: [
          _buildSearchField(),
          _buildNoDataIndicator(),
          Expanded(child: _buildSuggestions(context)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return GetBuilder<AddLocalTagPageLogic>(
      id: logic.searchFieldId,
      builder: (_) => TextField(
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
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
          suffixIcon: GetBuilder<AddLocalTagPageLogic>(
            id: logic.searchLoadingStateId,
            builder: (_) => state.searchLoadingState == LoadingState.loading ? const CupertinoActivityIndicator() : const SizedBox(),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataIndicator() {
    return GetBuilder<AddLocalTagPageLogic>(
      id: logic.searchLoadingStateId,
      builder: (_) => state.searchLoadingState == LoadingState.noData ? Text('noData'.tr).marginOnly(top: 24) : const SizedBox(),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return GetBuilder<AddLocalTagPageLogic>(
      id: logic.tagsId,
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: state.tags.length,
        itemBuilder: (_, int index) => GetBuilder<AddLocalTagPageLogic>(
          id: '${logic.tagsId}::${state.tags[index].namespace}::${state.tags[index].key}',
          builder: (_) => ListTile(
            dense: true,
            onTap: () => logic.toggleLocalTag(state.tags[index]),
            title: highlightKeyword(
              context,
              state.tags[index].translatedNamespace == null ? '${state.tags[index].namespace}:${state.tags[index].key}' : '${state.tags[index].translatedNamespace}:${state.tags[index].tagName}',
              state.keyword ?? '',
              false,
            ),
            subtitle: state.tags[index].translatedNamespace == null
                ? null
                : highlightKeyword(
                    context,
                    '${state.tags[index].namespace}:${state.tags[index].key}',
                    state.keyword ?? '',
                    true,
                  ),
            trailing: MyTagsSetting.containLocalTag(state.tags[index]) ? Icon(Icons.check, color: UIConfig.primaryColor(context)) : const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  RichText highlightKeyword(BuildContext context, String rawText, String currentKeyword, bool isSubTitle) {
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = currentKeyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(
              fontSize: isSubTitle ? UIConfig.addLocalTagPageSuggestionSubTitleTextSize : UIConfig.addLocalTagPageSuggestionTitleTextSize,
              color: isSubTitle ? UIConfig.addLocalTagPageSuggestionSubTitleColor(context) : UIConfig.addLocalTagPageSuggestionTitleColor(context),
            ),
          ),
        );
      }

      children.add(
        TextSpan(
          text: currentKeyword,
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.addLocalTagPageSuggestionSubTitleTextSize : UIConfig.addLocalTagPageSuggestionTitleTextSize,
            color: UIConfig.addLocalTagPageSuggestionHighlightColor,
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
            fontSize: isSubTitle ? UIConfig.addLocalTagPageSuggestionSubTitleTextSize : UIConfig.addLocalTagPageSuggestionTitleTextSize,
            color: isSubTitle ? UIConfig.addLocalTagPageSuggestionSubTitleColor(context) : UIConfig.addLocalTagPageSuggestionTitleColor(context),
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: children));
  }
}
