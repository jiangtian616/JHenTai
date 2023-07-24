import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:throttling/throttling.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../database/database.dart';
import '../network/eh_request.dart';
import '../service/tag_translation_service.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';
import '../utils/string_uril.dart';
import 'loading_state_indicator.dart';

class EHAddTagDialog extends StatelessWidget {
  final EHAddTagDialogLogic logic = Get.put(EHAddTagDialogLogic());
  final EHAddTagDialogState state = Get.find<EHAddTagDialogLogic>().state;

  EHAddTagDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('addTag'.tr),
          const Expanded(child: SizedBox()),
          if (logic.tagTranslationService.isReady) Text('useTranslation'.tr, style: const TextStyle(fontSize: 14)),
          if (logic.tagTranslationService.isReady)
            GetBuilder<EHAddTagDialogLogic>(
              id: EHAddTagDialogLogic.checkBoxId,
              builder: (_) => Checkbox(
                value: state.useTranslation,
                onChanged: (value) {
                  state.useTranslation = value!;
                  logic.updateSafely([EHAddTagDialogLogic.checkBoxId]);
                },
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: UIConfig.addTagDialogWidth,
        height: UIConfig.addTagDialogHeight,
        child: Column(
          children: [
            _buildSearchField(),
            _buildNoDataIndicator(),
            Expanded(child: _buildSuggestions(context)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.help, color: UIConfig.primaryColor(context)),
          onPressed: () => launchUrlString('https://ehwiki.org/wiki/Gallery_Tagging', mode: LaunchMode.externalApplication),
        ),
        TextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: state.keyword)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }

  Widget _buildSearchField() {
    return GetBuilder<EHAddTagDialogLogic>(
      id: EHAddTagDialogLogic.searchFieldId,
      builder: (_) {
        return TextField(
          focusNode: state.focusNode,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: state.keyword ?? '',

              /// make cursor stay at last letter
              selection: TextSelection.fromPosition(TextPosition(offset: state.keyword.length ?? 0)),
            ),
          ),
          onChanged: (text) {
            state.keyword = text;
            logic.waitAndSearchTags();
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: 'addTagHint'.tr,
            hintStyle: const TextStyle(fontSize: 14),
            contentPadding: EdgeInsets.zero,
            prefixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.search), onTap: logic.waitAndSearchTags),
            ),
            suffixIcon: _buildLoadingIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return GetBuilder<EHAddTagDialogLogic>(
      id: EHAddTagDialogLogic.loadingIndicatorId,
      builder: (_) => state.searchLoadingState == LoadingState.loading ? const CupertinoActivityIndicator() : const SizedBox(),
    );
  }

  Widget _buildNoDataIndicator() {
    return GetBuilder<EHAddTagDialogLogic>(
      id: EHAddTagDialogLogic.loadingIndicatorId,
      builder: (_) => state.searchLoadingState == LoadingState.noData ? Text('noData'.tr).marginOnly(top: 24) : const SizedBox(),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return GetBuilder<EHAddTagDialogLogic>(
      id: EHAddTagDialogLogic.tagsId,
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.only(top: 12),
        itemCount: state.tags.length,
        itemBuilder: (_, int index) => ListTile(
          dense: true,
          onTap: () {
            logic.defaultOnTap(state.tags[index]);
          },
          title: highlightKeyword(
            context,
            state.tags[index].translatedNamespace == null
                ? '${state.tags[index].namespace}:${state.tags[index].key}'
                : '${state.tags[index].translatedNamespace}:${state.tags[index].tagName}',
            logic.lastKeyWord ?? '',
            false,
          ),
          subtitle: state.tags[index].translatedNamespace == null
              ? null
              : highlightKeyword(
                  context,
                  '${state.tags[index].namespace}:${state.tags[index].key}',
                  logic.lastKeyWord ?? '',
                  true,
                ),
          trailing: const Icon(Icons.add),
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

    return RichText(text: TextSpan(children: children));
  }
}

class EHAddTagDialogLogic extends GetxController {
  static const String checkBoxId = 'checkBoxId';
  static const String searchFieldId = 'searchFieldId';
  static const String loadingIndicatorId = 'loadingIndicatorId';
  static const String tagsId = 'tagsId';

  EHAddTagDialogState state = EHAddTagDialogState();

  final TagTranslationService tagTranslationService = Get.find();

  String get lastKeyWord => state.keyword.split(',').last.trim();

  @override
  void onClose() {
    super.onClose();
    state.focusNode.dispose();
  }

  void waitAndSearchTags() {
    if (isEmptyOrNull(state.keyword)) {
      return;
    }
    state.searchDebouncing.debounce(searchTags);
  }

  Future<void> searchTags() async {
    if (state.searchLoadingState == LoadingState.loading) {
      return;
    }
    if (isEmptyOrNull(state.keyword)) {
      return;
    }

    Log.info('search for ${state.keyword}');

    state.searchLoadingState = LoadingState.loading;
    updateSafely([loadingIndicatorId]);

    if (state.useTranslation && tagTranslationService.isReady) {
      state.tags = await tagTranslationService.searchTags(lastKeyWord);
    } else {
      try {
        state.tags = await EHRequest.requestTagSuggestion(lastKeyWord, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
        state.searchLoadingState = LoadingState.error;
        updateSafely([loadingIndicatorId]);
        return;
      }
    }

    if (state.tags.isEmpty) {
      state.searchLoadingState = LoadingState.noData;
    } else {
      state.searchLoadingState = LoadingState.success;
    }
    updateSafely([loadingIndicatorId, tagsId]);
  }

  void defaultOnTap(TagData tag) {
    List<String> segments = state.keyword.split(',');
    segments.removeLast();
    segments.add('${tag.namespace}:${tag.key}');
    state.keyword = segments.joinNewElement(',', joinAtLast: true).join('');
    updateSafely([searchFieldId]);
    state.focusNode.requestFocus();
  }
}

class EHAddTagDialogState {
  String keyword = '';
  List<TagData> tags = [];

  bool useTranslation = true;

  final Debouncing searchDebouncing = Debouncing(duration: const Duration(milliseconds: 300));
  LoadingState searchLoadingState = LoadingState.idle;
  FocusNode focusNode = FocusNode();
}
