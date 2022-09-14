import 'package:flutter/widgets.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../../database/database.dart';

enum SearchPageBodyType { gallerys, suggestionAndHistory }

mixin BaseSearchPageStateMixin on BasePageState {
  /// used to init body
  bool hasSearched = false;

  /// used for file search
  String? redirectUrl;

  SearchPageBodyType bodyType = SearchPageBodyType.suggestionAndHistory;

  List<TagData> suggestions = <TagData>[];

  ScrollController suggestionBodyController = ScrollController();

  FocusNode searchFieldFocusNode = FocusNode();
}
