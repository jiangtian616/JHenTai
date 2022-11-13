import 'package:jhentai/src/routes/routes.dart';

import '../../model/search_config.dart';
import '../base/base_page_state.dart';

class FavoritePageState extends BasePageState {
  @override
  String get route => Routes.favorite;

  @override
  SearchConfig searchConfig = SearchConfig(searchType: SearchType.favorite);
}
