import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jhentai/src/model/gallery_image_page_url.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../../service/tag_translation_service.dart';

enum SearchPageBodyType { gallerys, suggestionAndHistory }

mixin SearchPageStateMixin on BasePageState {
  /// used to init body
  bool hasSearched = false;

  bool enableSearchHistoryTranslation = true;
  Completer<void> enableSearchHistoryTranslationCompleter = Completer();

  /// used for file search
  String? redirectUrl;

  SearchPageBodyType bodyType = SearchPageBodyType.suggestionAndHistory;

  bool hideSearchHistory = false;

  bool inDeleteSearchHistoryMode = false;

  GalleryUrl? inputGalleryUrl;

  GalleryImagePageUrl? inputGalleryImagePageUrl;

  List<TagAutoCompletionMatch> suggestions = [];

  ScrollController suggestionBodyController = ScrollController();

  FocusNode searchFieldFocusNode = FocusNode();
}
