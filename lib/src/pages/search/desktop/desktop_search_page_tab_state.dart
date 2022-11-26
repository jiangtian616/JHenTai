import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/search/base/base_search_page_state.dart';

import '../../../routes/routes.dart';
import '../../base/base_page_state.dart';
import '../../layout/desktop/desktop_layout_page_logic.dart';

class DesktopSearchPageTabState extends BasePageState with BaseSearchPageStateMixin {
  @override
  String get route => Routes.desktopSearch;
}
