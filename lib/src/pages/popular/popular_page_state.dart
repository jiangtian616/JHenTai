import '../../model/search_config.dart';
import '../../routes/routes.dart';
import '../base/base_page_state.dart';

class PopularPageState extends BasePageState {
  @override
  String get route => Routes.popular;

  @override
  SearchConfig searchConfig = SearchConfig(searchType: SearchType.popular);
}
