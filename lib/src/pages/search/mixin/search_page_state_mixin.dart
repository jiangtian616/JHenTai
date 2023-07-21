import 'package:flutter/widgets.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../../database/database.dart';

enum SearchPageBodyType { gallerys, suggestionAndHistory }

mixin SearchPageStateMixin on BasePageState {
  /// used to init body
  bool hasSearched = false;

  bool enableSearchHistoryTranslation = true;

  /// used for file search
  String? redirectUrl;

  SearchPageBodyType bodyType = SearchPageBodyType.suggestionAndHistory;

  bool hideSearchHistory = false;

  List<TagData> suggestions = <TagData>[];

  ScrollController suggestionBodyController = ScrollController();

  FocusNode searchFieldFocusNode = FocusNode();
}
