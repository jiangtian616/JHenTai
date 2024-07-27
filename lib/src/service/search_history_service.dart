import 'dart:convert';

import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/search_history.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';

import '../database/database.dart';
import 'jh_service.dart';

SearchHistoryService searchHistoryService = SearchHistoryService();

class SearchHistoryService with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  List<SearchHistory> histories = [];

  static const _maxLength = 50;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..add(tagTranslationService);

  @override
  ConfigEnum get configEnum => ConfigEnum.searchHistory;

  @override
  Future<void> applyBeanConfig(String configString) async {
    List searchHistories = jsonDecode(configString);

    for (String searchHistory in searchHistories) {
      histories.add(
        SearchHistory(
          rawKeyword: searchHistory,
          translatedKeyword: tagTranslationService.isReady ? await translateSearchHistory(searchHistory) : null,
        ),
      );
    }
  }

  @override
  String toConfigString() {
    return jsonEncode(histories.map((history) => history.rawKeyword).toList());
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> writeHistory(String searchHistory) async {
    histories.removeWhere((history) => history.rawKeyword == searchHistory);
    histories.insert(
      0,
      SearchHistory(
        rawKeyword: searchHistory,
        translatedKeyword: tagTranslationService.isReady ? await translateSearchHistory(searchHistory) : null,
      ),
    );

    if (histories.length > _maxLength) {
      histories = histories.sublist(0, _maxLength);
    }

    await saveBeanConfig();
  }

  Future<void> deleteHistory(SearchHistory searchHistory) async {
    if (histories.remove(searchHistory)) {
      await saveBeanConfig();
    }
  }

  Future<void> clearHistory() async {
    histories.clear();
    await clearBeanConfig();
  }

  /// find each pair and then translate, remains the parts which can't be translated
  Future<String> translateSearchHistory(String searchHistory) async {
    List<RegExpMatch> matches = RegExp(r'(\w+):"([^"]+)\$"').allMatches(searchHistory).toList();
    if (matches.isEmpty) {
      return searchHistory;
    }

    String result = '';
    int index = 0;
    int matchIndex = 0;
    while (index < searchHistory.length) {
      if (matchIndex >= matches.length) {
        result += searchHistory.substring(index);
        break;
      }

      if (index < matches[matchIndex].start) {
        result += searchHistory.substring(index, matches[matchIndex].start);
        index = matches[matchIndex].start;
        continue;
      }

      if (index == matches[matchIndex].start) {
        String namespace = matches[matchIndex].group(1)!;
        String key = matches[matchIndex].group(2)!;
        TagData? tagData = await tagTranslationService.getTagTranslation(namespace, key);

        if (tagData == null) {
          result += searchHistory.substring(matches[matchIndex].start, matches[matchIndex].end);
        } else {
          result += '｢${tagData.translatedNamespace}:${tagData.tagName}｣';
        }

        index = matches[matchIndex].end;
        matchIndex++;
        continue;
      }
    }

    return result;
  }
}
