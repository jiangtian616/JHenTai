import 'package:jhentai/src/pages/base/base_page_state.dart';

import '../../../model/gallery.dart';
import '../../../model/search_config.dart';
import '../../../routes/routes.dart';
import '../../../widget/loading_state_indicator.dart';

class DashboardPageState extends BasePageState {
  @override
  SearchConfig searchConfig = SearchConfig.nonHOnly();

  @override
  String get route => Routes.dashboard;

  LoadingState ranklistLoadingState = LoadingState.idle;
  LoadingState popularLoadingState = LoadingState.idle;

  List<Gallery> ranklistGallerys = List.empty(growable: true);
  List<Gallery> popularGallerys = List.empty(growable: true);
}
