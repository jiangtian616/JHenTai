import '../../model/search_config.dart';
import '../base/base_page_state.dart';

class PopularPageState extends BasePageState {
  @override
  SearchConfig searchConfig = SearchConfig(searchType: SearchType.popular);
}
