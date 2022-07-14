import 'package:flutter/material.dart';
import 'package:jhentai/src/database/database.dart';

import '../../base/base_page_state.dart';

enum SearchPageBodyType { gallerys, suggestionAndHistory }

class SimpleSearchPageState extends BasePageState {
  /// used to init body
  bool hasSearched = false;

  /// used for file search
  String? redirectUrl;

  SearchPageBodyType bodyType = SearchPageBodyType.suggestionAndHistory;

  List<TagData> suggestions = <TagData>[];

  ScrollController suggestionBodyController = ScrollController();
}
