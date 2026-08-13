import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../../model/gallery.dart';
import '../../../model/search_config.dart';
import '../../../routes/routes.dart';
import '../../../widget/loading_state_indicator.dart';

class DashboardPageState extends BasePageState {
  /// Apple slide-down quick-search overlay state.
  ///
  /// This lives on the state object (owned by the permanent [DashboardPageLogic]
  /// controller) rather than on the page widget: [DashboardPage] is a
  /// StatelessWidget that is recreated whenever the parent layout rebuilds —
  /// e.g. the moment the system keyboard pops up, the change in viewInsets
  /// rebuilds the mobile layout, which rebuilds the page with fresh widget-local
  /// fields and would tear the search bar and keyboard right back down.
  final ValueNotifier<bool> searchVisible = ValueNotifier(false);
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  @override
  SearchConfig searchConfig = SearchConfig.nonHOnly();

  @override
  String get route => Routes.dashboard;

  LoadingState ranklistLoadingState = LoadingState.idle;
  LoadingState popularLoadingState = LoadingState.idle;

  List<Gallery> ranklistGalleries = List.empty(growable: true);
  List<Gallery> popularGalleries = List.empty(growable: true);
}
